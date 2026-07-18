import secrets
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from fastapi import HTTPException, UploadFile, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models import Booking, BookingEvent, ParkingSpace, Payment, User, Vehicle
from app.schemas.direct_payment import DirectPaymentDecisionIn, DirectPaymentReferenceIn
from app.schemas.launch_operations import ManualRefundIn
from app.services.booking import BookingService
from app.services.direct_payments import DirectPaymentService
from app.services.notifications import queue_email
from app.services.subscriptions import confirmation_hours

_ALLOWED_RECEIPTS = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".pdf": "application/pdf",
}


def receipt_url(payment: Payment) -> str | None:
    if not payment.receipt_access_token:
        return None
    base = settings.public_app_url.rstrip("/")
    return f"{base}/api/payments/receipts/{payment.receipt_access_token}"


async def submit_reference_with_deadline(
    db: AsyncSession,
    user_id: uuid.UUID,
    booking_id: uuid.UUID,
    data: DirectPaymentReferenceIn,
) -> dict[str, Any]:
    result = await DirectPaymentService.submit_reference(db, user_id, booking_id, data)
    payment = await db.scalar(
        select(Payment).where(
            Payment.booking_id == booking_id,
            Payment.payer_user_id == user_id,
            Payment.provider == "direct",
        )
    )
    booking = await db.get(Booking, booking_id)
    if payment is None or booking is None or payment.host_user_id is None:
        return result

    hours = await confirmation_hours(db, payment.host_user_id)
    payment.host_response_due_at = datetime.now(timezone.utc) + timedelta(hours=hours)
    parking_space = await db.get(ParkingSpace, booking.parking_space_id)
    renter = await db.get(User, booking.user_id)
    host = await db.get(User, payment.host_user_id)
    payload = {
        "reference": booking.public_reference,
        "parking_title": parking_space.title if parking_space else "Stellplatz",
        "amount": f"{payment.amount_cents / 100:.2f} {payment.currency}",
        "payer_reference": payment.payer_reference or "",
        "due_at": payment.host_response_due_at.isoformat(),
    }
    if host is not None:
        await queue_email(
            db,
            user_id=host.id,
            recipient=host.email,
            event_type="direct_payment_submitted_host",
            deduplication_key=f"direct-payment-host:{payment.id}",
            payload=payload,
        )
    if renter is not None:
        await queue_email(
            db,
            user_id=renter.id,
            recipient=renter.email,
            event_type="direct_payment_submitted_renter",
            deduplication_key=f"direct-payment-renter:{payment.id}",
            payload=payload,
        )
    await db.commit()
    await db.refresh(payment)
    result["payment"]["host_response_due_at"] = payment.host_response_due_at
    result["payment"]["receipt_url"] = receipt_url(payment)
    return result


async def upload_receipt(
    db: AsyncSession,
    user_id: uuid.UUID,
    booking_id: uuid.UUID,
    upload: UploadFile,
) -> dict[str, Any]:
    booking = await db.scalar(
        select(Booking).where(Booking.id == booking_id, Booking.user_id == user_id)
    )
    if booking is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    payment = await db.scalar(
        select(Payment).where(
            Payment.booking_id == booking.id,
            Payment.payer_user_id == user_id,
            Payment.provider == "direct",
        )
    )
    if payment is None or payment.status not in {
        "awaiting_payment",
        "awaiting_host_confirmation",
    }:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "receipt_not_allowed",
                "message": "Für diese Zahlung kann kein Beleg mehr hochgeladen werden.",
            },
        )

    original_name = Path(upload.filename or "receipt").name[:255]
    suffix = Path(original_name).suffix.lower()
    mime_type = _ALLOWED_RECEIPTS.get(suffix)
    if mime_type is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "code": "invalid_receipt_type",
                "message": "Erlaubt sind JPG, PNG, WEBP oder PDF.",
            },
        )
    content = await upload.read(settings.receipt_max_bytes + 1)
    if not content or len(content) > settings.receipt_max_bytes:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "code": "receipt_too_large",
                "message": "Der Zahlungsbeleg darf höchstens 5 MB groß sein.",
            },
        )

    root = Path(settings.receipt_upload_dir).resolve()
    directory = root / "receipts"
    directory.mkdir(parents=True, exist_ok=True)
    storage_name = f"{uuid.uuid4().hex}{suffix}"
    target = (directory / storage_name).resolve()
    if root not in target.parents:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST)
    target.write_bytes(content)

    if payment.receipt_storage_key:
        previous = (root / payment.receipt_storage_key).resolve()
        if root in previous.parents and previous.exists():
            previous.unlink(missing_ok=True)

    payment.receipt_storage_key = str(target.relative_to(root))
    payment.receipt_original_name = original_name
    payment.receipt_mime_type = mime_type
    payment.receipt_size_bytes = len(content)
    payment.receipt_access_token = secrets.token_urlsafe(32)
    await db.commit()
    await db.refresh(payment)
    return {
        "booking_id": booking.id,
        "receipt_url": receipt_url(payment),
        "original_name": original_name,
        "mime_type": mime_type,
        "size_bytes": len(content),
    }


async def payment_for_receipt_token(
    db: AsyncSession,
    token: str,
) -> tuple[Payment, Path]:
    payment = await db.scalar(
        select(Payment).where(Payment.receipt_access_token == token)
    )
    if payment is None or not payment.receipt_storage_key:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    root = Path(settings.receipt_upload_dir).resolve()
    path = (root / payment.receipt_storage_key).resolve()
    if root not in path.parents or not path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    return payment, path


async def pending_confirmations(
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
            .order_by(Payment.host_response_due_at, Payment.submitted_at)
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
            "receipt_url": receipt_url(payment),
            "receipt_original_name": payment.receipt_original_name,
        }
        for payment, booking, parking_space, renter, vehicle in rows
    ]


async def decide_with_notifications(
    db: AsyncSession,
    user_id: uuid.UUID,
    payment_id: uuid.UUID,
    data: DirectPaymentDecisionIn,
) -> dict[str, Any]:
    result = await DirectPaymentService.decide(db, user_id, payment_id, data)
    payment = await db.get(Payment, payment_id)
    if payment is None:
        return result
    booking = await db.get(Booking, payment.booking_id)
    renter = await db.get(User, payment.payer_user_id)
    parking_space = await db.get(ParkingSpace, booking.parking_space_id) if booking else None
    if booking is not None and renter is not None:
        event_type = (
            "direct_payment_confirmed"
            if data.decision == "confirm"
            else "direct_payment_rejected"
        )
        await queue_email(
            db,
            user_id=renter.id,
            recipient=renter.email,
            event_type=event_type,
            deduplication_key=f"{event_type}:{payment.id}",
            payload={
                "reference": booking.public_reference,
                "parking_title": parking_space.title if parking_space else "Stellplatz",
                "note": data.reason or "",
            },
        )
        await db.commit()
    return result


async def pending_refunds(
    db: AsyncSession,
    user_id: uuid.UUID,
) -> list[dict[str, Any]]:
    rows = (
        await db.execute(
            select(Payment, Booking, ParkingSpace, User)
            .join(Booking, Booking.id == Payment.booking_id)
            .join(ParkingSpace, ParkingSpace.id == Booking.parking_space_id)
            .join(User, User.id == Payment.payer_user_id)
            .where(
                Payment.host_user_id == user_id,
                Payment.provider == "direct",
                Payment.status == "refund_required",
            )
            .order_by(Booking.cancelled_at.asc())
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
            "amount_cents": payment.amount_cents,
            "currency": payment.currency,
            "cancelled_at": booking.cancelled_at,
            "payment_method": payment.payment_method,
        }
        for payment, booking, parking_space, renter in rows
    ]


async def complete_refund(
    db: AsyncSession,
    user_id: uuid.UUID,
    payment_id: uuid.UUID,
    data: ManualRefundIn,
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
    payment, booking, parking_space = row
    if payment.status != "refund_required":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "refund_not_required",
                "message": "Diese Zahlung wartet nicht auf eine Rückerstattung.",
            },
        )

    payment.status = "refunded"
    payment.refund_reference = data.reference.strip()
    payment.refunded_at = datetime.now(timezone.utc)
    payment.failure_message = data.note.strip() if data.note else None
    db.add(
        BookingEvent(
            booking_id=booking.id,
            event_type="manual_refund_completed",
            event_metadata={
                "reference": payment.refund_reference,
                "note": data.note or "",
            },
        )
    )
    renter = await db.get(User, payment.payer_user_id)
    if renter is not None:
        await queue_email(
            db,
            user_id=renter.id,
            recipient=renter.email,
            event_type="manual_refund_completed",
            deduplication_key=f"manual-refund:{payment.id}",
            payload={
                "reference": booking.public_reference,
                "parking_title": parking_space.title,
                "refund_reference": payment.refund_reference,
                "amount": f"{payment.amount_cents / 100:.2f} {payment.currency}",
            },
        )
    await db.commit()
    await db.refresh(payment)
    return {
        "payment_id": str(payment.id),
        "booking_id": str(booking.id),
        "status": payment.status,
        "refund_reference": payment.refund_reference,
        "refunded_at": payment.refunded_at,
    }


async def queue_refund_required(
    db: AsyncSession,
    booking: Booking,
    payment: Payment,
) -> None:
    host = await db.get(User, payment.host_user_id) if payment.host_user_id else None
    renter = await db.get(User, payment.payer_user_id)
    parking_space = await db.get(ParkingSpace, booking.parking_space_id)
    payload = {
        "reference": booking.public_reference,
        "parking_title": parking_space.title if parking_space else "Stellplatz",
        "amount": f"{payment.amount_cents / 100:.2f} {payment.currency}",
    }
    if host is not None:
        await queue_email(
            db,
            user_id=host.id,
            recipient=host.email,
            event_type="manual_refund_required",
            deduplication_key=f"manual-refund-required-host:{payment.id}",
            payload=payload,
        )
    if renter is not None:
        await queue_email(
            db,
            user_id=renter.id,
            recipient=renter.email,
            event_type="manual_refund_pending",
            deduplication_key=f"manual-refund-pending-renter:{payment.id}",
            payload=payload,
        )


async def expire_direct_payment_deadlines(db: AsyncSession) -> int:
    now = datetime.now(timezone.utc)
    rows = (
        await db.execute(
            select(Payment, Booking)
            .join(Booking, Booking.id == Payment.booking_id)
            .where(
                Payment.provider == "direct",
                Payment.status == "awaiting_host_confirmation",
                Payment.host_response_due_at.is_not(None),
                Payment.host_response_due_at <= now,
            )
            .with_for_update(skip_locked=True)
        )
    ).all()
    expired = 0
    for payment, booking in rows:
        payment.status = "host_timeout"
        payment.failure_message = "Der Anbieter hat nicht rechtzeitig reagiert."
        await BookingService.expire_pending(
            db,
            booking,
            reason="host_confirmation_timeout",
        )
        renter = await db.get(User, payment.payer_user_id)
        host = await db.get(User, payment.host_user_id) if payment.host_user_id else None
        parking_space = await db.get(ParkingSpace, booking.parking_space_id)
        payload = {
            "reference": booking.public_reference,
            "parking_title": parking_space.title if parking_space else "Stellplatz",
        }
        if renter is not None:
            await queue_email(
                db,
                user_id=renter.id,
                recipient=renter.email,
                event_type="host_confirmation_timeout_renter",
                deduplication_key=f"host-timeout-renter:{payment.id}",
                payload=payload,
            )
        if host is not None:
            await queue_email(
                db,
                user_id=host.id,
                recipient=host.email,
                event_type="host_confirmation_timeout_host",
                deduplication_key=f"host-timeout-host:{payment.id}",
                payload=payload,
            )
        await db.commit()
        expired += 1
    return expired
