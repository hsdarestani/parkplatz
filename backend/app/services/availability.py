from dataclasses import dataclass
from datetime import datetime, timezone
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


def matching_rule(
    rules: list[AvailabilityRule],
    start_at: datetime,
    end_at: datetime,
) -> AvailabilityRule | None:
    local_start = start_at.astimezone(FRANKFURT_TIMEZONE)
    local_end = end_at.astimezone(FRANKFURT_TIMEZONE)
    if local_start.date() != local_end.date():
        return None

    for rule in rules:
        if (
            rule.active
            and rule.weekday == local_start.weekday()
            and rule.start_time <= local_start.time().replace(tzinfo=None)
            and rule.end_time >= local_end.time().replace(tzinfo=None)
        ):
            return rule
    return None


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
    rule = matching_rule(rules, start_at, end_at) if rules else None
    if rules and rule is None:
        return AvailabilityDecision(
            available=False,
            code="outside_schedule",
            message="Der Stellplatz ist zu diesem Zeitpunkt nicht freigegeben.",
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

    effective_price = (
        rule.price_override_cents
        if rule is not None and rule.price_override_cents is not None
        else parking_space.hourly_price_cents
    )
    return AvailabilityDecision(
        available=True,
        code=None,
        message=None,
        hourly_price_cents=effective_price,
    )
