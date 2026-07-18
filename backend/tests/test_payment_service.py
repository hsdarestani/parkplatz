import uuid
from datetime import datetime, timezone
from types import SimpleNamespace

from app.core.config import settings
from app.services.payments import payment_out, platform_fee


def test_platform_fee_uses_configured_basis_points(monkeypatch) -> None:
    monkeypatch.setattr(settings, "platform_fee_basis_points", 1500)

    assert platform_fee(1_000) == 150
    assert platform_fee(333) == 50


def test_platform_fee_is_capped_to_payment_amount(monkeypatch) -> None:
    monkeypatch.setattr(settings, "platform_fee_basis_points", 20_000)

    assert platform_fee(500) == 500


def test_payment_output_contains_host_ledger_values() -> None:
    payment = SimpleNamespace(
        id=uuid.uuid4(),
        booking_id=uuid.uuid4(),
        provider="beta",
        status="paid",
        amount_cents=1_000,
        platform_fee_cents=150,
        host_net_cents=850,
        currency="EUR",
        checkout_session_id=None,
        checkout_url=None,
        expires_at=None,
        paid_at=datetime.now(timezone.utc),
        refunded_at=None,
        failure_message=None,
    )

    result = payment_out(payment)  # type: ignore[arg-type]

    assert result["amount_cents"] == 1_000
    assert result["platform_fee_cents"] == 150
    assert result["host_net_cents"] == 850
    assert result["status"] == "paid"
