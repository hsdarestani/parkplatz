import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_user
from app.core.config import settings
from app.db.session import get_session
from app.models import Booking, ParkingSpace, SafetyReport, User, VerificationRequest
from app.schemas.trust import (
    SafetyReportIn,
    SafetyReportReviewIn,
    VerificationRequestIn,
    VerificationReviewIn,
)
from app.services.trust import (
    can_transition_report,
    can_transition_verification,
    mark_reviewed,
    queue_notification,
    report_out,
    verification_out,
)

router = APIRouter(prefix="/api")


def is_admin_email(email: str) -> bool:
    return email.strip().lower() in settings.admin_email_set


async def current_admin(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> uuid.UUID:
    user = await db.get(User, user_id)
    if user is None or not is_admin_email(user.email):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "code": "admin_required",
                "message": "Für diesen Bereich ist ein Admin-Konto erforderlich.",
            },
        )
    return user_id


@router.get("/trust/overview")
async def trust_overview(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    verification_count = await db.scalar(
        select(func.count(VerificationRequest.id)).where(
            VerificationRequest.user_id == user_id,
            VerificationRequest.status == "pending",
        )
    )
    report_count = await db.scalar(
        select(func.count(SafetyReport.id)).where(
            SafetyReport.reporter_user_id == user_id,
            SafetyReport.status.in_(["open", "triaged"]),
        )
    )
    verified_spaces = await db.scalar(
        select(func.count(ParkingSpace.id)).where(
            ParkingSpace.owner_id == user_id,
            ParkingSpace.is_verified.is_(True),
            ParkingSpace.status != "archived",
        )
    )
    return {
        "pending_verifications": verification_count or 0,
        "open_reports": report_count or 0,
        "verified_spaces": verified_spaces or 0,
        "is_admin": is_admin_email(user.email),
        "support_email": settings.trust_support_email,
    }


@router.get("/trust/verifications")
async def user_verifications(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    requests = (
        await db.scalars(
            select(VerificationRequest)
            .where(VerificationRequest.user_id == user_id)
            .order_by(VerificationRequest.created_at.desc())
        )
    ).all()
    return [verification_out(request) for request in requests]


@router.post(
    "/trust/verifications",
    status_code=status.HTTP_201_CREATED,
)
async def request_verification(
    data: VerificationRequestIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    parking_space = await db.scalar(
        select(ParkingSpace).where(
            ParkingSpace.id == data.parking_space_id,
            ParkingSpace.owner_id == user_id,
            ParkingSpace.status != "archived",
        )
    )
    if parking_space is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "code": "parking_not_owned",
                "message": "Der Stellplatz wurde nicht gefunden oder gehört dir nicht.",
            },
        )
    if parking_space.is_verified:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "already_verified",
                "message": "Dieser Stellplatz ist bereits verifiziert.",
            },
        )
    existing = await db.scalar(
        select(VerificationRequest.id).where(
            VerificationRequest.parking_space_id == parking_space.id,
            VerificationRequest.status == "pending",
        )
    )
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "verification_pending",
                "message": "Für diesen Stellplatz läuft bereits eine Prüfung.",
            },
        )

    request = VerificationRequest(
        user_id=user_id,
        parking_space_id=parking_space.id,
        statement=data.statement.strip(),
        status="pending",
    )
    db.add(request)
    await db.flush()
    user = await db.get(User, user_id)
    if user is not None:
        await queue_notification(
            db,
            user_id=user_id,
            recipient=user.email,
            event_type="verification_submitted",
            deduplication_key=f"verification-submitted:{request.id}",
            payload={
                "verification_id": str(request.id),
                "parking_space_id": str(parking_space.id),
                "parking_title": parking_space.title,
            },
        )
    await db.commit()
    await db.refresh(request)
    return verification_out(request)


@router.get("/trust/reports")
async def user_reports(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    reports = (
        await db.scalars(
            select(SafetyReport)
            .where(SafetyReport.reporter_user_id == user_id)
            .order_by(SafetyReport.created_at.desc())
        )
    ).all()
    return [report_out(report) for report in reports]


@router.post("/trust/reports", status_code=status.HTTP_201_CREATED)
async def create_report(
    data: SafetyReportIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    parking_space_id = data.parking_space_id
    if data.booking_id is not None:
        row = (
            await db.execute(
                select(Booking, ParkingSpace)
                .join(ParkingSpace, ParkingSpace.id == Booking.parking_space_id)
                .where(Booking.id == data.booking_id)
            )
        ).one_or_none()
        if row is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        booking, parking_space = row
        if booking.user_id != user_id and parking_space.owner_id != user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)
        parking_space_id = parking_space.id
    elif parking_space_id is not None:
        parking_space = await db.get(ParkingSpace, parking_space_id)
        if parking_space is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    report = SafetyReport(
        reporter_user_id=user_id,
        parking_space_id=parking_space_id,
        booking_id=data.booking_id,
        category=data.category,
        description=data.description.strip(),
        status="open",
    )
    db.add(report)
    await db.flush()
    user = await db.get(User, user_id)
    if user is not None:
        await queue_notification(
            db,
            user_id=user_id,
            recipient=user.email,
            event_type="safety_report_received",
            deduplication_key=f"safety-report-received:{report.id}",
            payload={
                "report_id": str(report.id),
                "category": report.category,
            },
        )
    await db.commit()
    await db.refresh(report)
    return report_out(report)


@router.get("/admin/trust/queue")
async def admin_queue(
    _admin_id: uuid.UUID = Depends(current_admin),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    verification_rows = (
        await db.execute(
            select(VerificationRequest, User, ParkingSpace)
            .join(User, User.id == VerificationRequest.user_id)
            .join(ParkingSpace, ParkingSpace.id == VerificationRequest.parking_space_id)
            .where(VerificationRequest.status == "pending")
            .order_by(VerificationRequest.created_at)
        )
    ).all()
    report_rows = (
        await db.execute(
            select(SafetyReport, User)
            .join(User, User.id == SafetyReport.reporter_user_id)
            .where(SafetyReport.status.in_(["open", "triaged"]))
            .order_by(SafetyReport.created_at)
        )
    ).all()
    verifications = []
    for request, user, parking_space in verification_rows:
        value = verification_out(request)
        value.update(
            user_email=user.email,
            user_name=user.display_name,
            parking_title=parking_space.title,
            parking_address=parking_space.exact_address,
        )
        verifications.append(value)
    reports = []
    for report, user in report_rows:
        value = report_out(report)
        value.update(user_email=user.email, user_name=user.display_name)
        reports.append(value)
    return {"verifications": verifications, "reports": reports}


@router.patch("/admin/trust/verifications/{request_id}")
async def review_verification(
    request_id: uuid.UUID,
    data: VerificationReviewIn,
    admin_id: uuid.UUID = Depends(current_admin),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    request = await db.scalar(
        select(VerificationRequest)
        .where(VerificationRequest.id == request_id)
        .with_for_update()
    )
    if request is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    if not can_transition_verification(request.status, data.status):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "verification_already_reviewed",
                "message": "Diese Prüfung wurde bereits abgeschlossen.",
            },
        )
    request.status = data.status
    request.review_note = data.note.strip() or None
    mark_reviewed(request, admin_id)
    parking_space = await db.get(ParkingSpace, request.parking_space_id)
    if parking_space is not None:
        parking_space.is_verified = data.status == "approved"
    user = await db.get(User, request.user_id)
    if user is not None:
        await queue_notification(
            db,
            user_id=user.id,
            recipient=user.email,
            event_type=f"verification_{data.status}",
            deduplication_key=f"verification-{data.status}:{request.id}",
            payload={
                "verification_id": str(request.id),
                "parking_space_id": str(request.parking_space_id),
                "note": request.review_note,
            },
        )
    await db.commit()
    await db.refresh(request)
    return verification_out(request)


@router.patch("/admin/trust/reports/{report_id}")
async def review_report(
    report_id: uuid.UUID,
    data: SafetyReportReviewIn,
    admin_id: uuid.UUID = Depends(current_admin),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    report = await db.scalar(
        select(SafetyReport).where(SafetyReport.id == report_id).with_for_update()
    )
    if report is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    if not can_transition_report(report.status, data.status):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "report_already_closed",
                "message": "Diese Meldung wurde bereits abgeschlossen.",
            },
        )
    report.status = data.status
    report.resolution_note = data.note.strip() or None
    mark_reviewed(report, admin_id)
    user = await db.get(User, report.reporter_user_id)
    if user is not None:
        await queue_notification(
            db,
            user_id=user.id,
            recipient=user.email,
            event_type=f"safety_report_{data.status}",
            deduplication_key=f"safety-report-{data.status}:{report.id}",
            payload={
                "report_id": str(report.id),
                "note": report.resolution_note,
            },
        )
    await db.commit()
    await db.refresh(report)
    return report_out(report)
