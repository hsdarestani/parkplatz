from app.schemas.launch_operations import ManualRefundIn
from app.services.notifications import render_email
from app.services.subscriptions import plan_limits


def test_free_and_pro_plan_limits_are_distinct() -> None:
    free = plan_limits("free")
    pro = plan_limits("pro")

    assert free["listing_limit"] == 1
    assert pro["listing_limit"] >= free["listing_limit"]
    assert pro["response_hours"] <= free["response_hours"]


def test_manual_refund_reference_is_required() -> None:
    value = ManualRefundIn(reference="RF-123", note="Sent through PayPal")

    assert value.reference == "RF-123"
    assert value.note == "Sent through PayPal"


def test_launch_email_templates_are_user_facing() -> None:
    subject, body = render_email(
        "manual_refund_completed",
        {
            "reference": "FR-ABC123",
            "parking_title": "Messe Parkplatz",
            "amount": "12.00 EUR",
            "refund_reference": "RF-123",
        },
    )

    assert "FR-ABC123" in subject
    assert "RF-123" in body
