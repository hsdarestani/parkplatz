import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_user
from app.db.session import get_session
from app.models import User

router = APIRouter(prefix="/api", tags=["profile"])


@router.get("/auth/me/profile")
async def extended_profile(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, str | None]:
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    return {
        "id": str(user.id),
        "email": user.email,
        "display_name": user.display_name,
        "profile_image_url": user.profile_image_url,
    }
