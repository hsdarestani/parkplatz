from dataclasses import dataclass
from datetime import datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    AvailabilityBlock,
    AvailabilityRule,
    Booking,
    BookingStatus,
    ParkingSpace,
    Payment,
)

FRANKFURT_TIMEZONE = ZoneInfo("Europe/Berlin")


@dataclass(frozen=True)
class AvailabilityDecision:
    available: bool
    code: str | None
    message: str | None
    hourly_price_cents: int


def _rule_for_segment(
    rules: list[AvailabilityRule],
    segment_start: datetime,
    segment_end: datetime,
) -> AvailabilityRule | None:
    start_time = segment_start.time().replace(tzinfo=None)
    reaches_midnight = segment_end.date() > segment_start.date()
    end_time = (
        time(23, 59)
        if reaches_midnight
        else segment_end.time().replace(tzinfo=None)
    )

    for rule in rules:
        if (
            rule.active
            and rule.weekday == segment_start.weekday()
            and rule.start_time <= start_time
            and rule.end_time >= end_time
        ):
            return rule
    return None


def matching_rules(
    rules: list[AvailabilityRule],
    start_at: datetime,
    end_at: datetime,
) -> list[AvailabilityRule] | None:
    """Return one covering rule for every local calendar-day segment."""
    local_start = start_at.astimezone(FRANKFURT_TIMEZONE)
    local_end = end_at.astimezone(FRANKFURT_TIMEZONE)
    matched: list[AvailabilityRule] = []
    cursor = local_start

    while cursor < local_end:
        next_midnight = datetime.combine(
            cursor.date() + timedelta(days=1),
            time.min,
            tzinfo=FRANKFURT_TIMEZONE,
        )
        segment_end = min(local_end, next_midnight)
        rule = _rule_for_segment(rules, cursor, segment_end)
        if rule is None:
            return None
        matched.append(rule)
        cursor = segment_end

    return matched


def matching_rule(
    rules: list[AvailabilityRule],
    start_at: datetime,
    end_at: datetime,
) -> AvailabilityRule | None:
    """Backward-compatible helper for callers and tests using a single day."""
    values = matching_rules(rules, start_at, end_at)
    return values[0] if values and len(values) == 1 else None


async def evaluate_availability(
    db: AsyncSession,
    parking_space: ParkingSpace,
    start_at: datetime,
    end_at: datetime,
) -> AvailabilityDecision:
    if start_at.tzinfo is None:
        start_at = start_at.replace(tzinfo=FRANKFURT_TIMEZONE)
    if end_at.tzinfo is None:
        end_at = end_at.replace(tzinfo=FRANKFURT_TIMEZONE)
    start_at = start_at.astimezone(timezone.utc)
    end_at = end_at.astimezone(timezone.utc)

    rules = list(
        (
            await db.scalars(
                select(AvailabilityRule)
                .where(AvailabilityRule.parking_space_id == parking_space.id)
                .order_by(AvailabilityRule.weekday, AvailabilityRule.start_time)
            )
        ).all()
    )
    matched = matching_rules(rules, start_at, end_at) if rules else []
    if rules and matched is None:
        return AvailabilityDecision(
            available=False,
            code="outside_schedule",
            message=(
                "Der Stellplatz ist nicht für den gesamten gewählten Zeitraum "
                "freigegeben."
            ),
            hourly_price_cents=parking_space.hourly_price_cents,
        )

    block = await db.scalar(
        select(AvailabilityBlock.id).where(
            AvailabilityBlock.parking_space_id == parking_space.id,
            AvailabilityBlock.start_at < end_at,
            AvailabilityBlock.end_at > start_at,
        )
    )
    if block is not None:
        return AvailabilityDecision(
            available=False,
            code="availability_block",
            message="Der Stellplatz ist in diesem Zeitraum vom Anbieter gesperrt.",
            hourly_price_cents=parking_space.hourly_price_cents,
        )

    now = datetime.now(timezone.utc)
    overlapping_booking = await db.scalar(
        select(Booking.id)
        .outerjoin(Payment, Payment.booking_id == Booking.id)
        .where(
            Booking.parking_space_id == parking_space.id,
            Booking.start_at < end_at,
            Booking.end_at > start_at,
            or_(
                Booking.status == BookingStatus.confirmed,
                and_(
                    Booking.status == BookingStatus.pending,
                    Payment.status.in_(
                        [
                            "pending",
                            "checkout_created",
                            "awaiting_payment",
                            "awaiting_host_confirmation",
                            "paid",
                        ]
                    ),
                    Payment.expires_at > now,
                ),
            ),
        )
    )
    if overlapping_booking is not None:
        return AvailabilityDecision(
            available=False,
            code="booking_conflict",
            message="Dieser Zeitraum wurde bereits gebucht.",
            hourly_price_cents=parking_space.hourly_price_cents,
        )

    overrides = {
        rule.price_override_cents
        for rule in (matched or [])
        if rule.price_override_cents is not None
    }
    effective_price = (
        overrides.pop()
        if len(overrides) == 1
        else parking_space.hourly_price_cents
    )
    return AvailabilityDecision(
        available=True,
        code=None,
        message=None,
        hourly_price_cents=effective_price,
    )
