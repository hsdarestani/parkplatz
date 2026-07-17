import math
import secrets
import uuid
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    AvailabilityBlock,
    Booking,
    BookingEvent,
    BookingStatus,
    ParkingSpace,
    Vehicle,
)
from app.schemas.api import BookingIn


class BookingService:
    @staticmethod
    async def create(
        db: AsyncSession,
        user_id: uuid.UUID,
        data: BookingIn,
    ) -> Booking:
        previous_booking = await db.scalar(
            select(Booking).where(
                Booking.user_id == user_id,
                Booking.idempotency_key == data.idempotency_key,
            )
        )
        if previous_booking is not None:
            return previous_booking

        now = datetime.now(timezone.utc)
        timestamps_have_timezone = (
            data.start_at.utcoffset() is not None and data.end_at.utcoffset() is not None
        )
        if (
            not timestamps_have_timezone
            or data.end_at <= data.start_at
            or data.start_at <= now
        ):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail={
                    "code": "invalid_time",
                    "message": "Bitte wähle einen gültigen zukünftigen Zeitraum.",
                },
            )

        duration_hours = (data.end_at - data.start_at).total_seconds() / 3600
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

        overlapping_booking = await db.scalar(
            select(Booking.id).where(
                Booking.parking_space_id == parking_space.id,
                Booking.status.in_([BookingStatus.pending, BookingStatus.confirmed]),
                Booking.start_at < data.end_at,
                Booking.end_at > data.start_at,
            )
        )
        availability_block = await db.scalar(
            select(AvailabilityBlock.id).where(
                AvailabilityBlock.parking_space_id == parking_space.id,
                AvailabilityBlock.start_at < data.end_at,
                AvailabilityBlock.end_at > data.start_at,
            )
        )
        if overlapping_booking is not None or availability_block is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "booking_conflict",
                    "message": (
                        "Dieser Zeitraum wurde gerade gebucht. "
                        "Bitte wähle eine andere Zeit."
                    ),
                },
            )

        booking = Booking(
            public_reference=f"FR-{secrets.token_hex(3).upper()}",
            user_id=user_id,
            parking_space_id=parking_space.id,
            vehicle_id=vehicle.id,
            start_at=data.start_at,
            end_at=data.end_at,
            status=BookingStatus.confirmed,
            hourly_price_cents_snapshot=parking_space.hourly_price_cents,
            total_price_cents=(
                math.ceil(duration_hours) * parking_space.hourly_price_cents
            ),
            currency=parking_space.currency,
            access_code=f"{secrets.randbelow(1_000_000):06d}",
            parking_pass_token=secrets.token_urlsafe(32),
            idempotency_key=data.idempotency_key,
            confirmed_at=now,
        )
        db.add(booking)
        await db.flush()
        db.add(
            BookingEvent(
                booking_id=booking.id,
                event_type="confirmed",
                event_metadata={"payment": "beta_no_payment"},
            )
        )
        await db.commit()
        return booking
