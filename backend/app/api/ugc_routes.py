import uuid
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, Field
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_user
from app.db.session import get_session
from app.models import Review, SafetyReport, User, UserBlock

router = APIRouter(prefix="/api/ugc", tags=["ugc-safety"])


class ReviewReportIn(BaseModel):
    reason: Literal["harassment", "inappropriate", "spam", "other"] = "other"
    note: str = Field(default="", max_length=1000)


@router.get("/blocked-users")
async def blocked_users(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> list[str]:
    values = (
        await db.scalars(
            select(UserBlock.blocked_user_id)
            .where(UserBlock.blocker_user_id == user_id)
            .order_by(UserBlock.created_at.desc())
        )
    ).all()
    return [str(value) for value in values]


@router.post("/blocked-users/{blocked_user_id}", status_code=status.HTTP_201_CREATED)
async def block_user(
    blocked_user_id: uuid.UUID,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, str]:
    if blocked_user_id == user_id:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "code": "cannot_block_self",
                "message": "Du kannst dein eigenes Konto nicht blockieren.",
            },
        )
    target = await db.get(User, blocked_user_id)
    if target is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    existing = await db.scalar(
        select(UserBlock).where(
            UserBlock.blocker_user_id == user_id,
            UserBlock.blocked_user_id == blocked_user_id,
        )
    )
    if existing is None:
        db.add(
            UserBlock(
                blocker_user_id=user_id,
                blocked_user_id=blocked_user_id,
            )
        )
        await db.commit()
    return {"blocked_user_id": str(blocked_user_id)}


@router.delete(
    "/blocked-users/{blocked_user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def unblock_user(
    blocked_user_id: uuid.UUID,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> Response:
    await db.execute(
        delete(UserBlock).where(
            UserBlock.blocker_user_id == user_id,
            UserBlock.blocked_user_id == blocked_user_id,
        )
    )
    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/reviews/{review_id}/report",
    status_code=status.HTTP_201_CREATED,
)
async def report_review(
    review_id: uuid.UUID,
    data: ReviewReportIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, str]:
    review = await db.get(Review, review_id)
    if review is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    description = (
        f"UGC review report. review_id={review.id}; author_id={review.author_id}; "
        f"reason={data.reason}."
    )
    note = data.note.strip()
    if note:
        description = f"{description} Nutzerhinweis: {note}"

    report = SafetyReport(
        reporter_user_id=user_id,
        parking_space_id=review.parking_space_id,
        booking_id=None,
        category="harassment" if data.reason == "harassment" else "other",
        description=description,
        status="open",
    )
    db.add(report)
    await db.commit()
    await db.refresh(report)
    return {"report_id": str(report.id), "status": report.status}
