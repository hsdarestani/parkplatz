import uuid

import pytest
from pydantic import ValidationError

from app.api.routes import _slugify, host_space, public_space
from app.models import ParkingSpace
from app.schemas.api import HostParkingSpaceIn


def _listing_data() -> dict:
    return {
        "title": "Innenhof Sachsenhausen",
        "district": "Sachsenhausen",
        "landmark": "Schweizer Platz",
        "latitude": 50.104,
        "longitude": 8.689,
        "exact_address": "Musterstraße 12, 60594 Frankfurt",
        "entrance_instructions": "Durch das grüne Tor in den Innenhof fahren.",
        "hourly_price_cents": 350,
        "max_height_m": 2.1,
        "max_width_m": 2.5,
        "max_length_m": 5.2,
    }


def _parking_space() -> ParkingSpace:
    data = HostParkingSpaceIn(**_listing_data())
    return ParkingSpace(
        id=uuid.uuid4(),
        owner_id=uuid.uuid4(),
        slug="innenhof-sachsenhausen-demo",
        is_verified=False,
        rating=0,
        review_count=0,
        status="active",
        **data.model_dump(),
    )


def test_host_listing_schema_rejects_invalid_price() -> None:
    data = _listing_data()
    data["hourly_price_cents"] = 0

    with pytest.raises(ValidationError):
        HostParkingSpaceIn(**data)


def test_public_listing_hides_exact_address() -> None:
    parking_space = _parking_space()

    assert "exact_address" not in public_space(parking_space)
    assert host_space(parking_space)["exact_address"] == parking_space.exact_address


def test_host_listing_slug_is_url_safe() -> None:
    assert _slugify("Tiefgarage am Römer!") == "tiefgarage-am-r-mer"
