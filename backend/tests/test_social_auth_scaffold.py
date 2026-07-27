import pytest
from fastapi import HTTPException

from app.api.social_auth_routes import (
    authentication_providers,
    exchange_social_identity,
)
from app.core.config import Settings, settings
from app.schemas.api import SocialAuthToken


def test_provider_configuration_requires_explicit_global_activation() -> None:
    configured = Settings(
        _env_file=None,
        social_auth_exchange_enabled=False,
        google_oauth_client_id="google-client",
        google_oauth_client_secret="google-secret",
        apple_oauth_client_id="de.freiraum.parking",
        apple_oauth_team_id="TEAM123",
        apple_oauth_key_id="KEY123",
        apple_oauth_private_key="private-key",
    )

    assert configured.google_auth_configured is True
    assert configured.apple_auth_configured is True
    assert configured.google_auth_enabled is False
    assert configured.apple_auth_enabled is False


def test_incomplete_provider_credentials_never_enable_login() -> None:
    incomplete = Settings(
        _env_file=None,
        social_auth_exchange_enabled=True,
        google_oauth_client_id="google-client",
        apple_oauth_client_id="de.freiraum.parking",
    )

    assert incomplete.google_auth_configured is False
    assert incomplete.apple_auth_configured is False
    assert incomplete.google_auth_enabled is False
    assert incomplete.apple_auth_enabled is False


@pytest.mark.asyncio
async def test_provider_status_is_disabled_without_secrets(monkeypatch) -> None:
    monkeypatch.setattr(settings, "social_auth_exchange_enabled", False)
    monkeypatch.setattr(settings, "google_oauth_client_id", "")
    monkeypatch.setattr(settings, "google_oauth_client_secret", "")
    monkeypatch.setattr(settings, "apple_oauth_client_id", "")
    monkeypatch.setattr(settings, "apple_oauth_team_id", "")
    monkeypatch.setattr(settings, "apple_oauth_key_id", "")
    monkeypatch.setattr(settings, "apple_oauth_private_key", "")

    status = await authentication_providers()

    assert status == {
        "google": {"configured": False, "enabled": False},
        "apple": {"configured": False, "enabled": False},
    }


@pytest.mark.asyncio
async def test_token_exchange_fails_closed_while_provider_is_disabled(
    monkeypatch,
) -> None:
    monkeypatch.setattr(settings, "social_auth_exchange_enabled", False)
    payload = SocialAuthToken(id_token="x" * 32)

    with pytest.raises(HTTPException) as captured:
        await exchange_social_identity("google", payload)

    assert captured.value.status_code == 503
    assert captured.value.detail["code"] == "social_auth_unavailable"
