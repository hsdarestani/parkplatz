import uuid

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.security import decode

bearer = HTTPBearer(auto_error=False)


async def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> uuid.UUID:
    try:
        if credentials is None:
            raise ValueError
        return decode(credentials.credentials)
    except Exception as exc:
        raise HTTPException(
            status_code=401,
            detail={
                "code": "invalid_session",
                "message": "Sitzung ungültig oder abgelaufen.",
            },
        ) from exc
