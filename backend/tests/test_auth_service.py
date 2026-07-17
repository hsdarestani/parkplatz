from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from fastapi import HTTPException, status

from app.services.auth import AuthService


@pytest.mark.asyncio
async def test_duplicate_registration_explains_existing_account() -> None:
    db = SimpleNamespace(scalar=AsyncMock(return_value=object()))

    with pytest.raises(HTTPException) as raised:
        await AuthService.register(
            db,
            "Existing@Example.com",
            "password123",
            "Existing User",
        )

    assert raised.value.status_code == status.HTTP_409_CONFLICT
    assert raised.value.detail == {
        "code": "email_unavailable",
        "message": (
            "Diese E-Mail-Adresse ist bereits registriert. Bitte melde dich an."
        ),
    }
