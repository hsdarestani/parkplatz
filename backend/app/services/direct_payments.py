import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models import (
    Booking,
    BookingEvent,
    BookingStatus,
    HostDirectPaymentSettings,
    ParkingSpace,
    Payment,
    User,
    Vehicle,
)
from app.schemas.api import BookingIn
from app.schemas.direct_payment import (
    DirectPaymentDecisionIn,
    DirectPaymentReferenceIn,
    DirectPaymentSettingsIn,
)
from app.services.booking import BookingService
from app.services.notifications import queue_email
from app.services.payments import payment_out
from app.services.subscriptions import confirmation_hours


def direct_settings_out(value: HostDirectPaymentSettings | None) -> dict[str, Any]:
    return {
        "method": value.method if value else "paypal",
        "payment_url": value.payment_url if value else None,
        "iban": value.iban if value else None,
        "account_holder": value.account_holder if value else None,
        "instructions": value.instructions if value else None,
        "enabled": value.enabled if value else False,
        "configured": value is not None and value.enabled,
    }


def direct_instructions(
    value: HostDirectPaymentSettings,
    booking: Booking,
) -> dict[str, Any]:
    return {
        **direct_settings_out(value),
        "payment_reference": booking.public_reference,
        "amount_cents": booking.total_price_cents,
        "currency": booking.currency,
    }


class DirectPaymentService:
    @staticmethod
    async def settings(
        db: AsyncSession,
        user_id: uuid.UUID,
    ) -> dict[str, Any]:
        value = await db.get(HostDirectPaymentSettings, user_id)
        return direct_settings_out(value)

    @staticmethod
    async def save_settings(
        db: AsyncSession,
        user_id: uuid.UUID,
        data: DirectPaymentSettingsIn,
    ) -> dict[str, Any]:
        value = await db.get(HostDirectPaymentSettings, user_id)
        if value is None:
            value = HostDirectPaymentSettings(user_id=user_id)
            db.add(value)

        value.method = data.method
        value.payment_url = data.payment_url.strip() if data.payment_url else None
        value.iban = (
            data.iban.replace(" ", "").upper().strip() if data.iban else None
        )
        value.account_holder = (
            data.account_holder.strip() if data.account_holder else None
        )
        value.instructions = data.instructions.strip() if data.instructions else None
        value.enabled = data.enabled
        await db.commit()
        await db.refresh(value)
        return direct_settings_out(value)

    @staticmethod
    async def create_checkout(
        db: AsyncSession,
        user_id: uuid.UUID,
        data: BookingIn,
    ) -> dict[str, Any]:
        booking = await BookingService.create(
            db,
            user_id,
            data,
            confirm_immediately=False,
        )
        parking_space = await db.get(ParkingSpace, booking.parking_space_id)
        if parking_space is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        if parking_space.owner_id is None:
            await BookingService.expire_pending(
                db,
                booking,
                reason="demo_space_not_bookable",
            )
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "demo_space_not_bookable",
                    "message": (
                        "Dieser Demo-Stellplatz ist noch nicht buchbar. "
                        "Bitte wähle ein Angebot eines registrierten Anbieters."
                    ),
                },
            )

        free_booking = booking.total_price_cents == 0
        destination = None
        if not free_booking:
            destination = await db.get(
                HostDirectPaymentSettings,
                parking_space.owner_id,
            )
            if destination is None or not destination.enabled:
                await BookingService.expire_pending(
                    db,
                    booking,
                    reason="host_payment_not_ready",
                )
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail={
                        "code": "host_payment_not_ready",
                        "message": (
                            "Dieser Anbieter hat noch keine direkte Zahlungsmethode "
                            "hinterlegt."
                        ),
                    },
                )

        existing = await db.scalar(
            select(Payment).where(Payment.booking_id == booking.id)
        )
        if existing is not None and existing.provider == "direct":
            result = {
                "requires_redirect": False,
                "booking_id": str(booking.id),
                "payment": payment_out(existing),
            }
            if destination is not None:
                result["direct_payment"] = direct_instructions(destination, booking)
            return result

        now = datetime.now(timezone.utc)
        expires_at = now + timedelta(
            hours=max(settings.direct_payment_hold_hours, 1)
        )
        initial_status = (
            "awaiting_host_confirmation" if free_booking else "awaiting_payment"
        )
        payment = existing or Payment(
            booking_id=booking.id,
            payer_user_id=user_id,
            host_user_id=parking_space.owner_id,
            provider="direct",
            status=initial_status,
            amount_cents=booking.total_price_cents,
            platform_fee_cents=0,
            host_net_cents=booking.total_price_cents,
            currency=booking.currency,
        )
        payment.provider = "direct"
        payment.status = initial_status
        payment.amount_cents = booking.total_price_cents
        payment.platform_fee_cents = 0
        payment.host_net_cents = booking.total_price_cents
        payment.currency = booking.currency
        payment.payment_method = "free" if free_booking else destination.method
        payment.checkout_url = None if free_booking else destination.payment_url
        payment.expires_at = expires_at
        payment.payer_reference = booking.public_reference if free_booking else None
        payment.submitted_at = now if free_booking else None
        payment.host_confirmed_at = None
        payment.rejected_at = None
        payment.failure_message = None
        db.add(payment)

        if free_booking:
            response_hours = await confirmation_hours(db, parking_space.owner_id)
            payment.host_response_due_at = now + timedelta(hours=response_hours)
            db.add(
                BookingEvent(
                    booking_id=booking.id,
                    event_type="free_booking_submitted",
                    event_metadata={"reference": booking.public_reference},
                )
            )
            await db.flush()
            renter = await db.get(User, user_id)
            host = await db.get(User, parking_space.owner_id)
            payload = {
                "reference": booking.public_reference,
                "parking_title": parking_space.title,
                "amount": f"0.00 {booking.currency}",
                "payer_reference": booking.public_reference,
                "due_at": payment.host_response_due_at.isoformat(),
            }
            if host is not None:
                await queue_email(
                    db,
                    user_id=host.id,
                    recipient=host.email,
                    event_type="direct_payment_submitted_host",
                    deduplication_key=f"free-booking-host:{payment.id}",
                    payload=payload,
                )
            if renter is not None:
                await queue_email(
                    db,
                    user_id=renter.id,
                    recipient=renter.email,
                    event_type="direct_payment_submitted_renter",
                    deduplication_key=f"free-booking-renter:{payment.id}",
                    payload=payload,
                )

        await db.commit()
        await db.refresh(payment)
        result = {
            "requires_redirect": False,
            "booking_id": str(booking.id),
            "payment": payment_out(payment),
        }
        if destination is not None:
            result["direct_payment"] = direct_instructions(destination, booking)
        return result

    @staticmethod
    async def submit_reference(
        db: AsyncSession,
        user_id: uuid.UUID,
        booking_id: uuid.UUID,
        data: DirectPaymentReferenceIn,
    ) -> dict[str, Any]:
        booking = await db.scalar(
            select(Booking)
            .where(Booking.id == booking_id, Booking.user_id == user_id)
            .with_for_update()
        )
        if booking is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        payment = await db.scalar(
            select(Payment).where(
                Payment.booking_id == booking.id,
                Payment.provider == "direct",
            )
        )
        if payment is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        if booking.status != BookingStatus.pending or payment.status not in {
            "awaiting_payment",
            "awaiting_host_confirmation",
        }:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "payment_not_submittable",
                    "message": "Diese Zahlung kann nicht mehr eingereicht werden.",
                },
            )
        now = datetime.now(timezone.utc)
        if payment.expires_at is not None and payment.expires_at <= now:
            payment.status = "expired"
            await BookingService.expire_pending(
                db,
                booking,
                reason="direct_payment_expired",
            )
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "payment_expired",
                    "message": "Die Zahlungsfrist ist abgelaufen.",
                },
            )

        payment.payer_reference = data.reference.strip()
        payment.submitted_at = now
        payment.status = "awaiting_host_confirmation"
        db.add(
            BookingEvent(
                booking_id=booking.id,
                event_type="direct_payment_submitted",
                event_metadata={"reference": payment.payer_reference},
            )
        )
        await db.commit()
        await db.refresh(payment)
        return {
            "booking_id": str(booking.id),
            "payment": payment_out(payment),
        }

    @staticmethod
    async def pending_for_host(
        db: AsyncSession,
        user_id: uuid.UUID,
    ) -> list[dict[str, Any]]:
        rows = (
            await db.execute(
                select(Payment, Booking, ParkingSpace, User, Vehicle)
                .join(Booking, Booking.id == Payment.booking_id)
                .join(ParkingSpace, ParkingSpace.id == Booking.parking_space_id)
                .join(User, User.id == Payment.payer_user_id)
                .join(Vehicle, Vehicle.id == Booking.vehicle_id)
                .where(
                    Payment.host_user_id == user_id,
                    Payment.provider == "direct",
                    Payment.status == "awaiting_host_confirmation",
                )
                .order_by(Payment.submitted_at.asc())
            )
        ).all()
        return [
            {
                "payment_id": str(payment.id),
                "booking_id": str(booking.id),
                "booking_reference": booking.public_reference,
                "parking_title": parking_space.title,
                "renter_name": renter.display_name,
                "renter_email": renter.email,
                "vehicle_plate": vehicle.plate,
                "start_at": booking.start_at,
                "end_at": booking.end_at,
                "amount_cents": payment.amount_cents,
                "currency": payment.currency,
                "payment_method": payment.payment_method,
                "payer_reference": payment.payer_reference,
                "submitted_at": payment.submitted_at,
                "host_response_due_at": payment.host_response_due_at,
            }
            for payment, booking, parking_space, renter, vehicle in rows
        ]

    @staticmethod
    async def decide(
        db: AsyncSession,
        user_id: uuid.UUID,
        payment_id: uuid.UUID,
        data: DirectPaymentDecisionIn,
    ) -> dict[str, Any]:
        row = (
            await db.execute(
                select(Payment, Booking, ParkingSpace)
                .join(Booking, Booking.id == Payment.booking_id)
                .join(ParkingSpace, ParkingSpace.id == Booking.parking_space_id)
                .where(
                    Payment.id == payment_id,
                    Payment.host_user_id == user_id,
                    ParkingSpace.owner_id == user_id,
                    Payment.provider == "direct",
                )
                .with_for_update()
            )
        ).one_or_none()
        if row is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        payment, booking, _parking_space = row
        if payment.status != "awaiting_host_confirmation":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "payment_already_decided",
                    "message": "Diese Anfrage wurde bereits bearbeitet.",
                },
            )

        now = datetime.now(timezone.utc)
        if data.decision == "confirm":
            payment.status = "paid"
            payment.paid_at = now
            payment.host_confirmed_at = now
            payment.failure_message = None
            await BookingService.confirm_paid(
                db,
                booking,
                payment_reference=(payment.payer_reference or str(payment.id)),
            )
        else:
            payment.status = "rejected"
            payment.rejected_at = now
            payment.failure_message = (
                data.reason.strip()
                if data.reason
                else "Anfrage vom Anbieter nicht bestätigt."
            )
            db.add(
                BookingEvent(
                    booking_id=booking.id,
                    event_type="direct_payment_rejected",
                    event_metadata={"reason": payment.failure_message},
                )
            )
            await BookingService.expire_pending(
                db,
                booking,
                reason="direct_payment_rejected",
            )

        await db.refresh(payment)
        return {
            "booking_id": str(booking.id),
            "payment": payment_out(payment),
            "booking_status": booking.status,
        }
