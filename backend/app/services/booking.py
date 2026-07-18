import math
import secrets
import uuid
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Booking, BookingEvent, BookingStatus, ParkingSpace, Vehicle
from app.schemas.api import BookingIn
from app.services.availability import evaluate_availability

FRANKFURT_TIMEZONE = ZoneInfo("Europe/Berlin")


def normalize_booking_time(value: datetime) -> datetime:
    """Return a timezone-aware UTC timestamp for booking storage and comparison."""
    if value.utcoffset() is None:
        value = value.replace(tzinfo=FRANKFURT_TIMEZONE)
    return value.astimezone(timezone.utc)


def is_self_booking(parking_space: ParkingSpace, user_id: uuid.UUID) -> bool:
    return parking_space.owner_id == user_id


def ensure_not_self_booking(parking_space: ParkingSpace, user_id: uuid.UUID) -> None:
    if is_self_booking(parking_space, user_id):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "self_booking_not_allowed",
                "message": "Du kannst deinen eigenen Stellplatz nicht buchen.",
            },
        )


class BookingService:
    @staticmethod
    async def create(
        db: AsyncSession,
        user_id: uuid.UUID,
        data: BookingIn,
        *,
        confirm_immediately: bool = True,
    ) -> Booking:
        previous_booking = await db.scalar(
            select(Booking).where(
                Booking.user_id == user_id,
                Booking.idempotency_key == data.idempotency_key,
            )
        )
        if previous_booking is not None:
            return previous_booking

        start_at = normalize_booking_time(data.start_at)
        end_at = normalize_booking_time(data.end_at)
        now = datetime.now(timezone.utc)
        if end_at <= start_at or start_at <= now:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail={
                    "code": "invalid_time",
                    "message": "Bitte wähle einen gültigen zukünftigen Zeitraum.",
                },
            )

        duration_hours = (end_at - start_at).total_seconds() / 3600
        if duration_hours < 1 or duration_hours > 24:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail={
                    "code": "invalid_duration",
                    "message": "Buchungen sind zwischen 1 und 24 Stunden möglich.",
                },
            )

        parking_space = await db.scalar(
            select(ParkingSpace)
            .where(ParkingSpace.id == data.parking_space_id)
            .with_for_update()
        )
        vehicle = await db.scalar(
            select(Vehicle).where(
                Vehicle.id == data.vehicle_id,
                Vehicle.user_id == user_id,
            )
        )
        if (
            parking_space is None
            or parking_space.status != "active"
            or vehicle is None
        ):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "code": "not_found",
                    "message": "Stellplatz oder Fahrzeug nicht gefunden.",
                },
            )

        ensure_not_self_booking(parking_space, user_id)

        vehicle_does_not_fit = any(
            (
                float(vehicle.height_m) > float(parking_space.max_height_m),
                float(vehicle.width_m) > float(parking_space.max_width_m),
                float(vehicle.length_m) > float(parking_space.max_length_m),
            )
        )
        if vehicle_does_not_fit:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail={
                    "code": "vehicle_too_large",
                    "message": "Das ausgewählte Fahrzeug passt nicht.",
                },
            )

        decision = await evaluate_availability(
            db,
            parking_space,
            start_at,
            end_at,
        )
        if not decision.available:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": decision.code or "booking_conflict",
                    "message": decision.message or "Der Zeitraum ist nicht verfügbar.",
                },
            )

        booking = Booking(
            public_reference=f"FR-{secrets.token_hex(3).upper()}",
            user_id=user_id,
            parking_space_id=parking_space.id,
            vehicle_id=vehicle.id,
            start_at=start_at,
            end_at=end_at,
            status=(
                BookingStatus.confirmed
                if confirm_immediately
                else BookingStatus.pending
            ),
            hourly_price_cents_snapshot=decision.hourly_price_cents,
            total_price_cents=(
                math.ceil(duration_hours) * decision.hourly_price_cents
            ),
            currency=parking_space.currency,
            access_code=(
                f"{secrets.randbelow(1_000_000):06d}" if confirm_immediately else ""
            ),
            parking_pass_token=(secrets.token_urlsafe(32) if confirm_immediately else ""),
            idempotency_key=data.idempotency_key,
            confirmed_at=now if confirm_immediately else None,
        )
        db.add(booking)
        await db.flush()
        db.add(
            BookingEvent(
                booking_id=booking.id,
                event_type="confirmed" if confirm_immediately else "payment_pending",
                event_metadata={
                    "payment": "beta_no_payment" if confirm_immediately else "required",
                    "schedule_price_cents": decision.hourly_price_cents,
                },
            )
        )
        await db.commit()
        return booking

    @staticmethod
    async def confirm_paid(
        db: AsyncSession,
        booking: Booking,
        *,
        payment_reference: str,
    ) -> Booking:
        if booking.status == BookingStatus.confirmed:
            return booking
        if booking.status != BookingStatus.pending:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "booking_not_pending",
                    "message": "Diese Reservierung kann nicht mehr bestätigt werden.",
                },
            )

        booking.status = BookingStatus.confirmed
        booking.confirmed_at = datetime.now(timezone.utc)
        booking.access_code = f"{secrets.randbelow(1_000_000):06d}"
        booking.parking_pass_token = secrets.token_urlsafe(32)
        db.add(
            BookingEvent(
                booking_id=booking.id,
                event_type="payment_confirmed",
                event_metadata={"payment_reference": payment_reference},
            )
        )
        await db.commit()
        await db.refresh(booking)
        return booking

    @staticmethod
    async def expire_pending(
        db: AsyncSession,
        booking: Booking,
        *,
        reason: str,
    ) -> Booking:
        if booking.status != BookingStatus.pending:
            return booking
        booking.status = BookingStatus.expired
        booking.access_code = ""
        booking.parking_pass_token = ""
        db.add(
            BookingEvent(
                booking_id=booking.id,
                event_type="payment_expired",
                event_metadata={"reason": reason},
            )
        )
        await db.commit()
        await db.refresh(booking)
        return booking
