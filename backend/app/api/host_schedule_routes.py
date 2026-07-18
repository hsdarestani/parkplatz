import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_user
from app.db.session import get_session
from app.models import AvailabilityRule, ParkingSpace
from app.schemas.api import HostAvailabilityScheduleIn

router = APIRouter(prefix="/api")


@router.post("/host/parking-spaces/{space_id}/availability")
async def replace_host_availability(
    space_id: uuid.UUID,
    data: HostAvailabilityScheduleIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    parking_space = await db.scalar(
        select(ParkingSpace).where(
            ParkingSpace.id == space_id,
            ParkingSpace.owner_id == user_id,
            ParkingSpace.status != "archived",
        )
    )
    if parking_space is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

    await db.execute(
        delete(AvailabilityRule).where(
            AvailabilityRule.parking_space_id == parking_space.id
        )
    )
    for rule in data.rules:
        db.add(
            AvailabilityRule(
                parking_space_id=parking_space.id,
                **rule.model_dump(),
            )
        )
    await db.commit()

    saved_rules = list(
        (
            await db.scalars(
                select(AvailabilityRule)
                .where(AvailabilityRule.parking_space_id == parking_space.id)
                .order_by(AvailabilityRule.weekday)
            )
        ).all()
    )
    return {
        "rules": [
            {
                "id": rule.id,
                "weekday": rule.weekday,
                "active": rule.active,
                "start_time": rule.start_time,
                "end_time": rule.end_time,
                "price_override_cents": rule.price_override_cents,
            }
            for rule in saved_rules
        ]
    }
