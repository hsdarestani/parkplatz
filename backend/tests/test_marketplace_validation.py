import pytest
from pydantic import ValidationError

from app.api.marketplace_routes import ReviewIn
from app.schemas.api import HostAvailabilityRuleIn, HostParkingSpaceIn


def parking_payload() -> dict:
    return {
        "title": "Kostenloser Innenhof",
        "district": "Gallus",
        "landmark": "Messe Frankfurt",
        "latitude": 50.1109,
        "longitude": 8.6821,
        "exact_address": "Mainzer Landstraße 100, Frankfurt",
        "entrance_instructions": "Einfahrt links neben dem Tor.",
        "hourly_price_cents": 0,
        "currency": "EUR",
        "max_height_m": 2.1,
        "max_width_m": 2.5,
        "max_length_m": 5.2,
        "access_type": "gate",
        "is_covered": False,
        "has_ev_charging": False,
        "is_accessible": True,
        "is_instant_bookable": True,
    }


def test_free_parking_listing_is_valid() -> None:
    listing = HostParkingSpaceIn.model_validate(parking_payload())
    assert listing.hourly_price_cents == 0
    assert listing.is_instant_bookable is True


def test_free_schedule_override_is_valid() -> None:
    rule = HostAvailabilityRuleIn(
        weekday=0,
        active=True,
        start_time="08:00",
        end_time="20:00",
        price_override_cents=0,
    )
    assert rule.price_override_cents == 0


def test_review_rating_must_be_between_one_and_five() -> None:
    assert ReviewIn(rating=5, comment="Sehr gut erreichbar.").rating == 5
    with pytest.raises(ValidationError):
        ReviewIn(rating=0, comment="Ungültig")
    with pytest.raises(ValidationError):
        ReviewIn(rating=6, comment="Ungültig")
