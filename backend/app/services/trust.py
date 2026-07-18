import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import NotificationOutbox, SafetyReport, VerificationRequest
from app.services.notifications import queue_email


VERIFICATION_FINAL_STATUSES = {"approved", "rejected"}
REPORT_FINAL_STATUSES = {"resolved", "dismissed"}


def verification_out(request: VerificationRequest) -> dict[str, Any]:
    return {
        "id": str(request.id),
        "user_id": str(request.user_id),
        "parking_space_id": str(request.parking_space_id),
        "statement": request.statement,
        "status": request.status,
        "review_note": request.review_note,
        "reviewed_at": request.reviewed_at,
        "created_at": request.created_at,
        "updated_at": request.updated_at,
    }


def report_out(report: SafetyReport) -> dict[str, Any]:
    return {
        "id": str(report.id),
        "reporter_user_id": str(report.reporter_user_id),
        "parking_space_id": (
            str(report.parking_space_id) if report.parking_space_id else None
        ),
        "booking_id": str(report.booking_id) if report.booking_id else None,
        "category": report.category,
        "description": report.description,
        "status": report.status,
        "resolution_note": report.resolution_note,
        "reviewed_at": report.reviewed_at,
        "created_at": report.created_at,
        "updated_at": report.updated_at,
    }


def can_transition_verification(current: str, target: str) -> bool:
    return current == "pending" and target in VERIFICATION_FINAL_STATUSES


def can_transition_report(current: str, target: str) -> bool:
    if current in REPORT_FINAL_STATUSES:
        return False
    return target in {"triaged", "resolved", "dismissed"}


async def queue_notification(
    db: AsyncSession,
    *,
    user_id: uuid.UUID | None,
    recipient: str,
    event_type: str,
    deduplication_key: str,
    payload: dict[str, Any],
) -> NotificationOutbox | None:
    return await queue_email(
        db,
        user_id=user_id,
        recipient=recipient,
        event_type=event_type,
        deduplication_key=deduplication_key,
        payload=payload,
    )


def mark_reviewed(record: VerificationRequest | SafetyReport, reviewer_id: uuid.UUID) -> None:
    record.reviewed_by = reviewer_id
    record.reviewed_at = datetime.now(timezone.utc)
