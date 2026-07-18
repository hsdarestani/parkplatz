from sqlalchemy import event

from .account import AdminAuditLog
from .trust import SafetyReport, VerificationRequest


@event.listens_for(VerificationRequest, "after_update")
def audit_verification_review(_mapper, connection, target: VerificationRequest) -> None:
    if target.reviewed_by is None or target.reviewed_at is None:
        return
    connection.execute(
        AdminAuditLog.__table__.insert().values(
            admin_user_id=target.reviewed_by,
            action=f"verification_{target.status}",
            target_type="verification_request",
            target_id=str(target.id),
            metadata={
                "parking_space_id": str(target.parking_space_id),
                "note": target.review_note,
            },
        )
    )


@event.listens_for(SafetyReport, "after_update")
def audit_report_review(_mapper, connection, target: SafetyReport) -> None:
    if target.reviewed_by is None or target.reviewed_at is None:
        return
    connection.execute(
        AdminAuditLog.__table__.insert().values(
            admin_user_id=target.reviewed_by,
            action=f"safety_report_{target.status}",
            target_type="safety_report",
            target_id=str(target.id),
            metadata={
                "category": target.category,
                "note": target.resolution_note,
            },
        )
    )
