import pytest
from pydantic import ValidationError

from app.schemas.account import AccountDeletionIn, PasswordChangeIn
from app.services.notifications import event_category, render_email


def test_notification_categories_keep_transactional_updates_separate() -> None:
    assert event_category("booking_confirmed") == "booking_updates"
    assert event_category("host_booking_received") == "host_updates"
    assert event_category("verification_approved") == "trust_updates"
    assert event_category("password_changed") == "security_updates"


def test_password_change_rejects_reusing_current_password() -> None:
    with pytest.raises(ValidationError):
        PasswordChangeIn(
            current_password="same-password",
            new_password="same-password",
        )


def test_account_deletion_requires_explicit_confirmation() -> None:
    value = AccountDeletionIn(password="password123", confirmation="DELETE")
    assert value.confirmation == "DELETE"
    with pytest.raises(ValidationError):
        AccountDeletionIn(password="password123", confirmation="delete")


def test_password_reset_email_contains_secure_link() -> None:
    subject, body = render_email(
        "password_reset_requested",
        {"reset_url": "https://parkplatz.smarbiz.sbs/reset-password/?token=test"},
    )
    assert "Passwort" in subject
    assert "token=test" in body
