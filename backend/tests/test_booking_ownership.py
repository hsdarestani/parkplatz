import uuid
from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.services.booking import ensure_not_self_booking, is_self_booking


def test_owner_cannot_book_own_parking_space() -> None:
    owner_id = uuid.uuid4()
    parking_space = SimpleNamespace(owner_id=owner_id)

    assert is_self_booking(parking_space, owner_id)  # type: ignore[arg-type]

    with pytest.raises(HTTPException) as error:
        ensure_not_self_booking(parking_space, owner_id)  # type: ignore[arg-type]

    assert error.value.status_code == 409
    assert error.value.detail == {
        "code": "self_booking_not_allowed",
        "message": "Du kannst deinen eigenen Stellplatz nicht buchen.",
    }


def test_other_user_can_book_host_parking_space() -> None:
    parking_space = SimpleNamespace(owner_id=uuid.uuid4())
    user_id = uuid.uuid4()

    assert not is_self_booking(parking_space, user_id)  # type: ignore[arg-type]
    ensure_not_self_booking(parking_space, user_id)  # type: ignore[arg-type]


def test_seeded_space_without_owner_remains_bookable() -> None:
    parking_space = SimpleNamespace(owner_id=None)
    user_id = uuid.uuid4()

    assert not is_self_booking(parking_space, user_id)  # type: ignore[arg-type]
    ensure_not_self_booking(parking_space, user_id)  # type: ignore[arg-type]
