import pytest
from pydantic import ValidationError

from app.schemas.direct_payment import (
    DirectPaymentDecisionIn,
    DirectPaymentReferenceIn,
    DirectPaymentSettingsIn,
)


def test_paypal_requires_secure_payment_url() -> None:
    with pytest.raises(ValidationError):
        DirectPaymentSettingsIn(
            method="paypal",
            payment_url="http://paypal.me/example",
        )

    value = DirectPaymentSettingsIn(
        method="paypal",
        payment_url="https://paypal.me/example",
    )

    assert value.payment_url == "https://paypal.me/example"


def test_sepa_requires_iban_and_account_holder() -> None:
    with pytest.raises(ValidationError):
        DirectPaymentSettingsIn(method="sepa", iban="DE12345678901234567890")

    value = DirectPaymentSettingsIn(
        method="sepa",
        iban="DE12 3456 7890 1234 5678 90",
        account_holder="Max Mustermann",
    )

    assert value.method == "sepa"
    assert value.account_holder == "Max Mustermann"


def test_reference_and_host_decision_are_validated() -> None:
    with pytest.raises(ValidationError):
        DirectPaymentReferenceIn(reference="x")

    reference = DirectPaymentReferenceIn(reference="PP-123456")
    decision = DirectPaymentDecisionIn(decision="confirm")

    assert reference.reference == "PP-123456"
    assert decision.decision == "confirm"
