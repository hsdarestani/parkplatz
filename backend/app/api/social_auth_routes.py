from typing import Literal

from fastapi import APIRouter, HTTPException, status

from app.core.config import settings
from app.schemas.api import SocialAuthToken

router = APIRouter(prefix="/api/auth", tags=["authentication"])

Provider = Literal["google", "apple"]


def _provider_enabled(provider: Provider) -> bool:
    if provider == "google":
        return settings.google_auth_enabled
    return settings.apple_auth_enabled


@router.get("/providers")
async def authentication_providers() -> dict[str, dict[str, bool]]:
    """Expose only providers that are safe to use in the current release.

    Credentials alone never activate the buttons. The global exchange flag must
    also be enabled after native redirect URIs and server-side token validation
    have been reviewed and deployed.
    """

    return {
        "google": {
            "configured": settings.google_auth_configured,
            "enabled": settings.google_auth_enabled,
        },
        "apple": {
            "configured": settings.apple_auth_configured,
            "enabled": settings.apple_auth_enabled,
        },
    }


@router.post("/oauth/{provider}")
async def exchange_social_identity(
    provider: Provider,
    _payload: SocialAuthToken,
) -> dict[str, str]:
    """Reserve the stable client/API contract for social authentication.

    Token verification and identity linking will be activated in a dedicated
    release after the provider credentials, native entitlements, redirect URIs,
    nonce handling, and account-linking policy are available. Until then this
    endpoint fails closed and never accepts an unverified external identity.
    """

    if not _provider_enabled(provider):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "code": "social_auth_unavailable",
                "message": (
                    "Diese Anmeldemethode ist noch nicht aktiviert. "
                    "Bitte verwende vorerst E-Mail und Passwort."
                ),
            },
        )

    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail={
            "code": "social_auth_exchange_pending",
            "message": "Die sichere Token-Prüfung wird vor der Aktivierung ergänzt.",
        },
    )
