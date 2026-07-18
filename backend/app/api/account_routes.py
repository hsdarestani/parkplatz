import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_user
from app.api.trust_routes import current_admin
from app.core.config import settings
from app.core.security import hash_password, token_hash, verify_password
from app.db.session import get_session
from app.models import (
    AdminAuditLog,
    Booking,
    BookingEvent,
    BookingStatus,
    HostPaymentAccount,
    NotificationOutbox,
    NotificationPreference,
    ParkingSpace,
    ParkingSpaceImage,
    PasswordResetToken,
    Payment,
    RefreshToken,
    SafetyReport,
    User,
    Vehicle,
    VerificationRequest,
)
from app.schemas.account import (
    AccountDeletionIn,
    NotificationPreferencesIn,
    PasswordChangeIn,
    PasswordResetConfirm,
    PasswordResetRequest,
)
from app.services.notifications import queue_email

router = APIRouter(prefix="/api")


def preference_out(value: NotificationPreference) -> dict[str, bool]:
    return {
        "booking_updates": value.booking_updates,
        "host_updates": value.host_updates,
        "trust_updates": value.trust_updates,
        "security_updates": value.security_updates,
        "marketing": value.marketing,
    }


async def preferences_for(db: AsyncSession, user_id: uuid.UUID) -> NotificationPreference:
    value = await db.get(NotificationPreference, user_id)
    if value is None:
        value = NotificationPreference(user_id=user_id)
        db.add(value)
        await db.commit()
        await db.refresh(value)
    return value


@router.post("/auth/password/forgot", status_code=status.HTTP_204_NO_CONTENT)
async def forgot_password(
    data: PasswordResetRequest,
    db: AsyncSession = Depends(get_session),
) -> None:
    user = await db.scalar(
        select(User).where(
            User.email == str(data.email).strip().lower(),
            User.is_active.is_(True),
        )
    )
    if user is None:
        return

    now = datetime.now(timezone.utc)
    await db.execute(
        delete(PasswordResetToken).where(
            PasswordResetToken.user_id == user.id,
            PasswordResetToken.used_at.is_(None),
        )
    )
    raw_token = secrets.token_urlsafe(40)
    reset = PasswordResetToken(
        user_id=user.id,
        token_hash=token_hash(raw_token),
        expires_at=now + timedelta(minutes=max(settings.password_reset_minutes, 10)),
    )
    db.add(reset)
    await db.flush()
    reset_url = (
        f"{settings.public_app_url.rstrip('/')}/reset-password/"
        f"?token={raw_token}"
    )
    await queue_email(
        db,
        user_id=user.id,
        recipient=user.email,
        event_type="password_reset_requested",
        deduplication_key=f"password-reset:{reset.id}",
        payload={"reset_url": reset_url},
        force=True,
    )
    await db.commit()


@router.post("/auth/password/reset", status_code=status.HTTP_204_NO_CONTENT)
async def reset_password(
    data: PasswordResetConfirm,
    db: AsyncSession = Depends(get_session),
) -> None:
    now = datetime.now(timezone.utc)
    reset = await db.scalar(
        select(PasswordResetToken)
        .where(
            PasswordResetToken.token_hash == token_hash(data.token),
            PasswordResetToken.used_at.is_(None),
            PasswordResetToken.expires_at > now,
        )
        .with_for_update()
    )
    if reset is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "code": "invalid_reset_token",
                "message": "Der Link ist ungültig oder abgelaufen.",
            },
        )
    user = await db.get(User, reset.user_id)
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    user.password_hash = hash_password(data.new_password)
    reset.used_at = now
    await db.execute(delete(RefreshToken).where(RefreshToken.user_id == user.id))
    await queue_email(
        db,
        user_id=user.id,
        recipient=user.email,
        event_type="password_changed",
        deduplication_key=f"password-reset-complete:{reset.id}",
        payload={},
        force=True,
    )
    await db.commit()


@router.post("/account/password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
    data: PasswordChangeIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> None:
    user = await db.get(User, user_id)
    if user is None or not verify_password(data.current_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": "current_password_invalid",
                "message": "Das aktuelle Passwort ist nicht korrekt.",
            },
        )
    user.password_hash = hash_password(data.new_password)
    await db.execute(delete(RefreshToken).where(RefreshToken.user_id == user.id))
    await queue_email(
        db,
        user_id=user.id,
        recipient=user.email,
        event_type="password_changed",
        deduplication_key=f"password-changed:{user.id}:{datetime.now(timezone.utc).isoformat()}",
        payload={},
        force=True,
    )
    await db.commit()


@router.get("/account/notifications")
async def get_notification_preferences(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, bool]:
    return preference_out(await preferences_for(db, user_id))


@router.patch("/account/notifications")
async def update_notification_preferences(
    data: NotificationPreferencesIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, bool]:
    value = await preferences_for(db, user_id)
    for field, enabled in data.model_dump().items():
        setattr(value, field, enabled)
    await db.commit()
    await db.refresh(value)
    return preference_out(value)


@router.get("/account/export")
async def export_account_data(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    vehicles = list(
        (await db.scalars(select(Vehicle).where(Vehicle.user_id == user_id))).all()
    )
    bookings = list(
        (await db.scalars(select(Booking).where(Booking.user_id == user_id))).all()
    )
    spaces = list(
        (await db.scalars(select(ParkingSpace).where(ParkingSpace.owner_id == user_id))).all()
    )
    payments = list(
        (
            await db.scalars(
                select(Payment).where(
                    or_(Payment.payer_user_id == user_id, Payment.host_user_id == user_id)
                )
            )
        ).all()
    )
    verifications = list(
        (
            await db.scalars(
                select(VerificationRequest).where(VerificationRequest.user_id == user_id)
            )
        ).all()
    )
    reports = list(
        (
            await db.scalars(
                select(SafetyReport).where(SafetyReport.reporter_user_id == user_id)
            )
        ).all()
    )
    preferences = await preferences_for(db, user_id)

    return {
        "generated_at": datetime.now(timezone.utc),
        "profile": {
            "id": str(user.id),
            "email": user.email,
            "display_name": user.display_name,
            "created_at": user.created_at,
        },
        "notification_preferences": preference_out(preferences),
        "vehicles": [
            {
                "id": str(item.id),
                "name": item.name,
                "plate": item.plate,
                "height_m": float(item.height_m),
                "width_m": float(item.width_m),
                "length_m": float(item.length_m),
                "is_default": item.is_default,
                "created_at": item.created_at,
            }
            for item in vehicles
        ],
        "bookings": [
            {
                "id": str(item.id),
                "reference": item.public_reference,
                "parking_space_id": str(item.parking_space_id),
                "start_at": item.start_at,
                "end_at": item.end_at,
                "status": item.status,
                "total_price_cents": item.total_price_cents,
                "currency": item.currency,
                "created_at": item.created_at,
            }
            for item in bookings
        ],
        "host_spaces": [
            {
                "id": str(item.id),
                "title": item.title,
                "exact_address": item.exact_address,
                "status": item.status,
                "is_verified": item.is_verified,
                "created_at": item.created_at,
            }
            for item in spaces
        ],
        "payments": [
            {
                "id": str(item.id),
                "booking_id": str(item.booking_id),
                "status": item.status,
                "amount_cents": item.amount_cents,
                "platform_fee_cents": item.platform_fee_cents,
                "host_net_cents": item.host_net_cents,
                "currency": item.currency,
                "created_at": item.created_at,
            }
            for item in payments
        ],
        "verifications": [
            {
                "id": str(item.id),
                "parking_space_id": str(item.parking_space_id),
                "statement": item.statement,
                "status": item.status,
                "review_note": item.review_note,
                "created_at": item.created_at,
            }
            for item in verifications
        ],
        "support_reports": [
            {
                "id": str(item.id),
                "category": item.category,
                "description": item.description,
                "status": item.status,
                "resolution_note": item.resolution_note,
                "created_at": item.created_at,
            }
            for item in reports
        ],
    }


@router.post("/account/delete", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    data: AccountDeletionIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> None:
    user = await db.get(User, user_id)
    if user is None or not verify_password(data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "code": "password_invalid",
                "message": "Das Passwort ist nicht korrekt.",
            },
        )

    now = datetime.now(timezone.utc)
    renter_booking = await db.scalar(
        select(Booking.id).where(
            Booking.user_id == user_id,
            Booking.status.in_([BookingStatus.pending, BookingStatus.confirmed]),
            Booking.end_at > now,
        )
    )
    host_booking = await db.scalar(
        select(Booking.id)
        .join(ParkingSpace, ParkingSpace.id == Booking.parking_space_id)
        .where(
            ParkingSpace.owner_id == user_id,
            Booking.status.in_([BookingStatus.pending, BookingStatus.confirmed]),
            Booking.end_at > now,
        )
    )
    if renter_booking is not None or host_booking is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "active_bookings_exist",
                "message": "Beende oder storniere zuerst alle aktiven Buchungen.",
            },
        )

    original_email = user.email
    spaces = list(
        (await db.scalars(select(ParkingSpace).where(ParkingSpace.owner_id == user_id))).all()
    )
    space_ids = [space.id for space in spaces]
    if space_ids:
        await db.execute(
            delete(ParkingSpaceImage).where(
                ParkingSpaceImage.parking_space_id.in_(space_ids)
            )
        )
    for space in spaces:
        space.owner_id = None
        space.status = "archived"
        space.is_verified = False
        space.slug = f"deleted-{space.id}"
        space.title = "Gelöschter Stellplatz"
        space.district = "Gelöscht"
        space.landmark = "Gelöscht"
        space.latitude = 0
        space.longitude = 0
        space.exact_address = "Gelöscht"
        space.entrance_instructions = "Gelöscht"

    await db.execute(delete(Vehicle).where(Vehicle.user_id == user_id))
    await db.execute(delete(RefreshToken).where(RefreshToken.user_id == user_id))
    await db.execute(delete(PasswordResetToken).where(PasswordResetToken.user_id == user_id))
    await db.execute(
        delete(NotificationPreference).where(NotificationPreference.user_id == user_id)
    )
    await db.execute(delete(HostPaymentAccount).where(HostPaymentAccount.user_id == user_id))
    await db.execute(delete(NotificationOutbox).where(NotificationOutbox.user_id == user_id))

    verification_rows = list(
        (
            await db.scalars(
                select(VerificationRequest).where(VerificationRequest.user_id == user_id)
            )
        ).all()
    )
    for item in verification_rows:
        item.statement = "[vom Nutzer gelöscht]"
        item.review_note = None

    report_rows = list(
        (
            await db.scalars(
                select(SafetyReport).where(SafetyReport.reporter_user_id == user_id)
            )
        ).all()
    )
    for item in report_rows:
        item.description = "[vom Nutzer gelöscht]"
        item.resolution_note = None

    user.email = f"deleted+{user.id}@freiraum.invalid"
    user.display_name = "Gelöschtes Konto"
    user.password_hash = hash_password(secrets.token_urlsafe(48))
    user.is_active = False

    await queue_email(
        db,
        user_id=None,
        recipient=original_email,
        event_type="account_deleted",
        deduplication_key=f"account-deleted:{user.id}",
        payload={},
        force=True,
    )
    await db.commit()


@router.get("/admin/audit-log")
async def admin_audit_log(
    _admin_id: uuid.UUID = Depends(current_admin),
    db: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    rows = list(
        (
            await db.scalars(
                select(AdminAuditLog)
                .order_by(AdminAuditLog.created_at.desc())
                .limit(100)
            )
        ).all()
    )
    return [
        {
            "id": str(item.id),
            "admin_user_id": str(item.admin_user_id) if item.admin_user_id else None,
            "action": item.action,
            "target_type": item.target_type,
            "target_id": item.target_id,
            "metadata": item.event_metadata,
            "created_at": item.created_at,
        }
        for item in rows
    ]
