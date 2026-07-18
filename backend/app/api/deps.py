import uuid

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode
from app.db.session import get_session
from app.models import User

bearer = HTTPBearer(auto_error=False)


async def current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: AsyncSession = Depends(get_session),
) -> uuid.UUID:
    try:
        if credentials is None:
            raise ValueError
        user_id = decode(credentials.credentials)
        user = await db.get(User, user_id)
        if user is None or not user.is_active:
            raise ValueError
        return user_id
    except Exception as exc:
        raise HTTPException(
            status_code=401,
            detail={
                "code": "invalid_session",
                "message": "Sitzung ungültig oder abgelaufen.",
            },
        ) from exc
