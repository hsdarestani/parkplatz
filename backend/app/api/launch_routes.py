import uuid

from fastapi import APIRouter, Depends, File, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import current_user
from app.api.trust_routes import current_admin
from app.db.session import get_session
from app.schemas.launch_operations import ManualRefundIn, SubscriptionAdminIn
from app.services.launch_operations import (
    complete_refund,
    payment_for_receipt_token,
    pending_refunds,
    upload_receipt,
)
from app.services.notifications import queue_email
from app.services.subscriptions import (
    request_pro,
    set_plan,
    subscription_for,
    subscription_out,
)
from app.models import User

router = APIRouter(prefix="/api")


@router.get("/host/subscription")
async def host_subscription(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    subscription = await subscription_for(db, user_id)
    assert subscription is not None
    await db.commit()
    return subscription_out(subscription)


@router.post("/host/subscription/request-pro")
async def request_host_pro(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    subscription = await request_pro(db, user_id)
    user = await db.get(User, user_id)
    if user is not None:
        await queue_email(
            db,
            user_id=user.id,
            recipient=user.email,
            event_type="pro_plan_requested",
            deduplication_key=f"pro-plan-requested:{user.id}:{subscription.requested_at}",
            payload={},
        )
        await db.commit()
    return subscription_out(subscription)


@router.post("/admin/subscriptions/{user_id}")
async def admin_set_subscription(
    user_id: uuid.UUID,
    data: SubscriptionAdminIn,
    _admin_id: uuid.UUID = Depends(current_admin),
    db: AsyncSession = Depends(get_session),
) -> dict:
    subscription = await set_plan(db, user_id, data.plan, data.status)
    user = await db.get(User, user_id)
    if user is not None:
        await queue_email(
            db,
            user_id=user.id,
            recipient=user.email,
            event_type="pro_plan_activated" if data.plan == "pro" else "plan_changed",
            deduplication_key=f"plan-change:{user.id}:{data.plan}:{subscription.updated_at}",
            payload={"plan": data.plan, "status": data.status},
        )
        await db.commit()
    return subscription_out(subscription)


@router.post(
    "/payments/bookings/{booking_id}/receipt",
    status_code=status.HTTP_201_CREATED,
)
async def upload_payment_receipt(
    booking_id: uuid.UUID,
    file: UploadFile = File(...),
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    return await upload_receipt(db, user_id, booking_id, file)


@router.get("/payments/receipts/{token}")
async def read_payment_receipt(
    token: str,
    db: AsyncSession = Depends(get_session),
) -> FileResponse:
    payment, path = await payment_for_receipt_token(db, token)
    return FileResponse(
        path,
        media_type=payment.receipt_mime_type or "application/octet-stream",
        filename=payment.receipt_original_name or path.name,
        content_disposition_type="inline",
    )


@router.get("/host/payments/direct/refunds")
async def host_pending_refunds(
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> list[dict]:
    return await pending_refunds(db, user_id)


@router.post("/host/payments/direct/{payment_id}/refund")
async def host_complete_refund(
    payment_id: uuid.UUID,
    data: ManualRefundIn,
    user_id: uuid.UUID = Depends(current_user),
    db: AsyncSession = Depends(get_session),
) -> dict:
    return await complete_refund(db, user_id, payment_id, data)
