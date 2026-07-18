import uuid

import pytest
from pydantic import ValidationError

from app.core.config import settings
from app.schemas.trust import SafetyReportIn
from app.services.trust import can_transition_report, can_transition_verification


def test_admin_email_configuration_is_normalized(monkeypatch) -> None:
    monkeypatch.setattr(
        settings,
        "admin_emails",
        " Admin@FREIRAUM.app, operations@freiraum.app ",
    )

    assert settings.admin_email_set == {
        "admin@freiraum.app",
        "operations@freiraum.app",
    }


def test_verification_can_only_be_reviewed_once() -> None:
    assert can_transition_verification("pending", "approved") is True
    assert can_transition_verification("pending", "rejected") is True
    assert can_transition_verification("approved", "rejected") is False


def test_report_workflow_closes_final_states() -> None:
    assert can_transition_report("open", "triaged") is True
    assert can_transition_report("triaged", "resolved") is True
    assert can_transition_report("resolved", "triaged") is False
    assert can_transition_report("dismissed", "resolved") is False


def test_safety_report_requires_a_target() -> None:
    with pytest.raises(ValidationError):
        SafetyReportIn(
            category="safety_concern",
            description="A sufficiently detailed safety report for the moderation team.",
        )


def test_safety_report_accepts_booking_target() -> None:
    booking_id = uuid.uuid4()
    report = SafetyReportIn(
        booking_id=booking_id,
        category="access_problem",
        description="The access instructions did not match the actual entrance location.",
    )

    assert report.booking_id == booking_id
