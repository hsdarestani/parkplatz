import uuid
from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models import HostSubscription, ParkingSpace


def plan_limits(plan: str) -> dict[str, int]:
    if plan == "pro":
        return {
            "listing_limit": max(settings.pro_listing_limit, 1),
            "response_hours": max(settings.pro_host_response_hours, 1),
        }
    return {
        "listing_limit": max(settings.free_listing_limit, 1),
        "response_hours": max(settings.free_host_response_hours, 1),
    }


async def subscription_for(
    db: AsyncSession,
    user_id: uuid.UUID,
    *,
    create: bool = True,
) -> HostSubscription | None:
    subscription = await db.get(HostSubscription, user_id)
    if subscription is None and create:
        subscription = HostSubscription(user_id=user_id, plan="free", status="active")
        db.add(subscription)
        await db.flush()
    return subscription


def subscription_out(subscription: HostSubscription) -> dict[str, Any]:
    limits = plan_limits(subscription.plan)
    return {
        "plan": subscription.plan,
        "status": subscription.status,
        "requested_at": subscription.requested_at,
        "active_until": subscription.active_until,
        "listing_limit": limits["listing_limit"],
        "response_hours": limits["response_hours"],
        "features": (
            [
                "Bis zu 10 aktive Stellplätze",
                "Schnellere Zahlungsbestätigung",
                "Priorisierte Anbieter-Unterstützung",
                "Pro-Kennzeichnung im Anbieterbereich",
            ]
            if subscription.plan == "pro"
            else [
                "Ein aktiver Stellplatz",
                "Direktzahlung per PayPal, Revolut oder SEPA",
                "Standard-Support",
            ]
        ),
    }


async def request_pro(db: AsyncSession, user_id: uuid.UUID) -> HostSubscription:
    subscription = await subscription_for(db, user_id)
    assert subscription is not None
    if subscription.plan == "pro" and subscription.status == "active":
        return subscription
    subscription.status = "pending"
    subscription.requested_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(subscription)
    return subscription


async def set_plan(
    db: AsyncSession,
    user_id: uuid.UUID,
    plan: str,
    status_value: str = "active",
) -> HostSubscription:
    if plan not in {"free", "pro"}:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY)
    subscription = await subscription_for(db, user_id)
    assert subscription is not None
    subscription.plan = plan
    subscription.status = status_value
    if status_value == "active":
        subscription.requested_at = None
    await db.commit()
    await db.refresh(subscription)
    return subscription


async def confirmation_hours(db: AsyncSession, user_id: uuid.UUID) -> int:
    subscription = await subscription_for(db, user_id)
    assert subscription is not None
    return plan_limits(subscription.plan)["response_hours"]


async def ensure_listing_capacity(db: AsyncSession, user_id: uuid.UUID) -> None:
    subscription = await subscription_for(db, user_id)
    assert subscription is not None
    limit = plan_limits(subscription.plan)["listing_limit"]
    count = await db.scalar(
        select(func.count(ParkingSpace.id)).where(
            ParkingSpace.owner_id == user_id,
            ParkingSpace.status != "archived",
        )
    )
    if (count or 0) >= limit:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "plan_listing_limit",
                "message": (
                    "Dein aktueller Tarif erlaubt keine weiteren Stellplätze. "
                    "Wechsle zu FREIRAUM Pro, um mehr Angebote zu veröffentlichen."
                ),
            },
        )
