import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_user
from app.core.config import settings
from app.db.session import get_session
from app.models import (
    Booking,
    BookingEvent,
    BookingStatus,
    HostPaymentAccount,
    ParkingSpace,
    Payment,
    Vehicle,
)
from app.schemas.api import BookingIn, CancelIn
from app.schemas.direct_payment import (
    DirectPaymentDecisionIn,
    DirectPaymentReferenceIn,
    DirectPaymentSettingsIn,
)
from app.services.direct_payments import DirectPaymentService
from app.services.launch_operations import (
    decide_with_notifications,
    pending_confirmations,
    queue_refund_required,
    receipt_url,
    submit_reference_with_deadline,
)
from app.services.payment_lifecycle import cancel_unpaid_checkout
from app.services.payments import PaymentService, payment_out

router = APIRouter(prefix="/api")


def _payment_out(payment: Payment) -> dict[str, Any]:
    result = payment_out(payment)
    result.update(
        payment_method=payment.payment_method,
        payer_reference=payment.payer_reference,
        submitted_at=payment.submitted_at,
        host_confirmed_at=payment.host_confirmed_at,
        host_response_due_at=payment.host_response_due_at,
        rejected_at=payment.rejected_at,
        receipt_url=receipt_url(payment),
        receipt_original_name=payment.receipt_original_name,
        refund_reference=payment.refund_reference,
    )
    return result


def _booking_out(
    booking: Booking,
    parking_space: ParkingSpace | None,
    vehicle: Vehicle | None,
    payment: Payment | None,
) -> dict[str, Any]:
    result: dict[str, Any] = {
        "id": str(booking.id),
        "public_reference": booking.public_reference,
        "parking_space_id": str(booking.parking_space_id),
        "vehicle_id": str(booking.vehicle_id),
        "start_at": booking.start_at,
        "end_at": booking.end_at,
        "status": booking.status,
        "hourly_price_cents_snapshot": booking.hourly_price_cents_snapshot,
        "total_price_cents": booking.total_price_cents,
        "currency": booking.currency,
        "cancelled_at": booking.cancelled_at,
        "parking_title": parking_space.title if parking_space else "Stellplatz",
        "vehicle_plate": vehicle.plate if vehicle else "",
    }
    if payment is not None:
        result["payment"] = _payment_out(payment)
    if booking.status == BookingStatus.confirmed and parking_space is not None:
        result.update(
            exact_address=parking_space.exact_address,
            entrance_instructions=parking_space.entrance_instructions,
            access_code=booking.access_code,
            parking_pass_token=booking.parking_pass_token,
        )
    return result


@router.post("/payments/checkout", status_code=status.HTTP_201_CREATED)
async def create_payment_checkout(
    data: BookingIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    parking_space = await db.get(ParkingSpace, data.parking_space_id)
    if parking_space is None or parking_space.status != "active":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    if settings.payment_mode == "direct":
        return await DirectPaymentService.create_checkout(db, user_id, data)

    if settings.payment_mode == "stripe" and parking_space.owner_id is not None:
        account = await db.get(HostPaymentAccount, parking_space.owner_id)
        if account is None or not account.charges_enabled or not account.payouts_enabled:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "host_payout_not_ready",
                    "message": (
                        "Dieser Anbieter hat sein Auszahlungskonto noch nicht "
                        "vollständig aktiviert."
                    ),
                },
            )

    return await PaymentService.create_checkout(db, user_id, data)


@router.get("/payments/checkout/{session_id}")
async def payment_checkout_status(
    session_id: str,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    return await PaymentService.checkout_status(db, user_id, session_id)


@router.post("/payments/bookings/{booking_id}/reference")
async def submit_direct_payment_reference(
    booking_id: uuid.UUID,
    data: DirectPaymentReferenceIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    return await submit_reference_with_deadline(db, user_id, booking_id, data)


@router.get("/payments/bookings/{booking_id}")
async def payment_booking(
    booking_id: uuid.UUID,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    booking = await db.scalar(
        select(Booking).where(
            Booking.id == booking_id,
            Booking.user_id == user_id,
        )
    )
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    parking_space = await db.get(ParkingSpace, booking.parking_space_id)
    vehicle = await db.get(Vehicle, booking.vehicle_id)
    payment = await db.scalar(select(Payment).where(Payment.booking_id == booking.id))
    return _booking_out(booking, parking_space, vehicle, payment)


@router.post("/payments/bookings/{booking_id}/cancel")
async def cancel_paid_booking(
    booking_id: uuid.UUID,
    data: CancelIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    booking = await db.scalar(
        select(Booking)
        .where(Booking.id == booking_id, Booking.user_id == user_id)
        .with_for_update()
    )
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    if booking.status in {BookingStatus.cancelled, BookingStatus.completed}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "not_cancellable",
                "message": "Diese Buchung kann nicht storniert werden.",
            },
        )

    payment = await db.scalar(select(Payment).where(Payment.booking_id == booking.id))
    if payment is not None and payment.provider == "direct":
        if payment.status == "paid":
            payment.status = "refund_required"
            payment.failure_message = (
                "Der Anbieter muss die direkte Zahlung manuell erstatten."
            )
        else:
            await cancel_unpaid_checkout(payment)
    elif payment is not None and payment.status != "paid":
        await cancel_unpaid_checkout(payment)
    else:
        payment = await PaymentService.refund_booking(db, booking)

    booking.status = BookingStatus.cancelled
    booking.cancelled_at = datetime.now(timezone.utc)
    booking.cancellation_reason = data.reason
    booking.access_code = ""
    booking.parking_pass_token = ""
    db.add(
        BookingEvent(
            booking_id=booking.id,
            event_type="cancelled",
            event_metadata={
                "reason": data.reason,
                "payment_status": payment.status if payment else "not_found",
            },
        )
    )
    if payment is not None and payment.status == "refund_required":
        await queue_refund_required(db, booking, payment)
    await db.commit()
    parking_space = await db.get(ParkingSpace, booking.parking_space_id)
    vehicle = await db.get(Vehicle, booking.vehicle_id)
    if payment is not None:
        await db.refresh(payment)
    return _booking_out(booking, parking_space, vehicle, payment)


@router.post("/payments/webhook", status_code=status.HTTP_204_NO_CONTENT)
async def stripe_webhook(
    request: Request,
    stripe_signature: str = Header(default="", alias="Stripe-Signature"),
    db: AsyncSession = Depends(get_session),
) -> None:
    payload = await request.body()
    await PaymentService.process_webhook(db, payload, stripe_signature)


@router.get("/host/finance")
async def host_finance(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    return await PaymentService.finance(db, user_id)


@router.get("/host/payments/direct/settings")
async def host_direct_payment_settings(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    return await DirectPaymentService.settings(db, user_id)


@router.post("/host/payments/direct/settings")
async def save_host_direct_payment_settings(
    data: DirectPaymentSettingsIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    return await DirectPaymentService.save_settings(db, user_id, data)


@router.get("/host/payments/direct/pending")
async def host_pending_direct_payments(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    return await pending_confirmations(db, user_id)


@router.post("/host/payments/direct/{payment_id}/decision")
async def decide_direct_payment(
    payment_id: uuid.UUID,
    data: DirectPaymentDecisionIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    return await decide_with_notifications(db, user_id, payment_id, data)


@router.get("/host/payments/connect/status")
async def host_connect_status(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    return await PaymentService.connect_status(db, user_id)


@router.post("/host/payments/connect/onboarding")
async def host_connect_onboarding(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, str]:
    return await PaymentService.onboarding_link(db, user_id)


@router.post("/host/payments/connect/dashboard")
async def host_connect_dashboard(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, str]:
    return await PaymentService.dashboard_link(db, user_id)
