import asyncio
import math
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

import stripe
from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models import (
    Booking,
    BookingEvent,
    BookingStatus,
    HostPaymentAccount,
    ParkingSpace,
    Payment,
    PaymentWebhookEvent,
    User,
)
from app.schemas.api import BookingIn
from app.services.booking import BookingService

ACTIVE_PAYMENT_STATUSES = {"pending", "checkout_created", "paid", "refund_pending"}


def platform_fee(amount_cents: int) -> int:
    basis_points = min(max(settings.platform_fee_basis_points, 0), 10_000)
    return min(amount_cents, math.ceil(amount_cents * basis_points / 10_000))


def payment_out(payment: Payment) -> dict[str, Any]:
    return {
        "id": str(payment.id),
        "booking_id": str(payment.booking_id),
        "provider": payment.provider,
        "status": payment.status,
        "amount_cents": payment.amount_cents,
        "platform_fee_cents": payment.platform_fee_cents,
        "host_net_cents": payment.host_net_cents,
        "currency": payment.currency,
        "checkout_session_id": payment.checkout_session_id,
        "checkout_url": payment.checkout_url,
        "expires_at": payment.expires_at,
        "paid_at": payment.paid_at,
        "refunded_at": payment.refunded_at,
        "failure_message": payment.failure_message,
    }


class StripeGateway:
    @staticmethod
    def configure() -> None:
        if not settings.stripe_secret_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail={
                    "code": "payments_not_configured",
                    "message": "Online-Zahlungen sind noch nicht konfiguriert.",
                },
            )
        stripe.api_key = settings.stripe_secret_key

    @classmethod
    async def create_checkout_session(
        cls,
        *,
        booking: Booking,
        parking_space: ParkingSpace,
        customer_email: str,
        application_fee_cents: int,
        destination_account_id: str | None,
        expires_at: datetime,
    ) -> Any:
        cls.configure()
        base_url = settings.public_app_url.rstrip("/")
        metadata = {
            "booking_id": str(booking.id),
            "parking_space_id": str(parking_space.id),
            "payer_user_id": str(booking.user_id),
        }
        payment_intent_data: dict[str, Any] = {
            "metadata": metadata,
            "description": f"FREIRAUM {booking.public_reference}",
        }
        if destination_account_id:
            payment_intent_data.update(
                application_fee_amount=application_fee_cents,
                transfer_data={"destination": destination_account_id},
            )

        return await asyncio.to_thread(
            stripe.checkout.Session.create,
            mode="payment",
            client_reference_id=str(booking.id),
            customer_email=customer_email,
            success_url=(
                f"{base_url}/payment-return/?session_id={{CHECKOUT_SESSION_ID}}"
                f"&booking_id={booking.id}"
            ),
            cancel_url=(
                f"{base_url}/checkout/{parking_space.id}?payment=cancelled"
            ),
            expires_at=int(expires_at.timestamp()),
            locale="de",
            metadata=metadata,
            payment_intent_data=payment_intent_data,
            line_items=[
                {
                    "quantity": 1,
                    "price_data": {
                        "currency": booking.currency.lower(),
                        "unit_amount": booking.total_price_cents,
                        "product_data": {
                            "name": parking_space.title,
                            "description": (
                                f"{booking.start_at.isoformat()} – "
                                f"{booking.end_at.isoformat()}"
                            ),
                        },
                    },
                }
            ],
        )

    @classmethod
    async def create_account(cls, email: str) -> Any:
        cls.configure()
        return await asyncio.to_thread(
            stripe.Account.create,
            type="express",
            country=settings.stripe_country,
            email=email,
            capabilities={
                "card_payments": {"requested": True},
                "transfers": {"requested": True},
            },
            business_profile={
                "product_description": "Vermietung privater Stellplätze über FREIRAUM"
            },
        )

    @classmethod
    async def retrieve_account(cls, account_id: str) -> Any:
        cls.configure()
        return await asyncio.to_thread(stripe.Account.retrieve, account_id)

    @classmethod
    async def onboarding_link(cls, account_id: str) -> Any:
        cls.configure()
        base_url = settings.public_app_url.rstrip("/")
        return await asyncio.to_thread(
            stripe.AccountLink.create,
            account=account_id,
            refresh_url=f"{base_url}/host/finance/?stripe=refresh",
            return_url=f"{base_url}/host/finance/?stripe=return",
            type="account_onboarding",
        )

    @classmethod
    async def dashboard_link(cls, account_id: str) -> Any:
        cls.configure()
        return await asyncio.to_thread(
            stripe.Account.create_login_link,
            account_id,
        )

    @classmethod
    async def refund(cls, payment: Payment) -> Any:
        cls.configure()
        if not payment.payment_intent_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "payment_reference_missing",
                    "message": "Die Zahlung kann gerade nicht erstattet werden.",
                },
            )
        options: dict[str, Any] = {"payment_intent": payment.payment_intent_id}
        if payment.destination_account_id:
            options.update(reverse_transfer=True, refund_application_fee=True)
        return await asyncio.to_thread(stripe.Refund.create, **options)

    @classmethod
    def construct_event(cls, payload: bytes, signature: str) -> Any:
        cls.configure()
        if not settings.stripe_webhook_secret:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail={
                    "code": "webhook_not_configured",
                    "message": "Der Zahlungs-Webhook ist nicht konfiguriert.",
                },
            )
        try:
            return stripe.Webhook.construct_event(
                payload,
                signature,
                settings.stripe_webhook_secret,
            )
        except (ValueError, stripe.error.SignatureVerificationError) as error:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"code": "invalid_webhook", "message": "Ungültiger Webhook."},
            ) from error


class PaymentService:
    @staticmethod
    async def create_checkout(
        db: AsyncSession,
        user_id: uuid.UUID,
        data: BookingIn,
    ) -> dict[str, Any]:
        booking = await BookingService.create(
            db,
            user_id,
            data,
            confirm_immediately=False,
        )
        parking_space = await db.get(ParkingSpace, booking.parking_space_id)
        user = await db.get(User, user_id)
        if parking_space is None or user is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)

        existing = await db.scalar(select(Payment).where(Payment.booking_id == booking.id))
        if existing is not None:
            if existing.status == "paid":
                return {
                    "requires_redirect": False,
                    "booking_id": str(booking.id),
                    "payment": payment_out(existing),
                }
            if (
                existing.status == "checkout_created"
                and existing.checkout_url
                and existing.expires_at
                and existing.expires_at > datetime.now(timezone.utc)
            ):
                return {
                    "requires_redirect": True,
                    "booking_id": str(booking.id),
                    "payment": payment_out(existing),
                }

        fee_cents = platform_fee(booking.total_price_cents)
        host_net_cents = booking.total_price_cents - fee_cents
        hold_minutes = max(settings.payment_hold_minutes, 30)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=hold_minutes)

        host_account = None
        if parking_space.owner_id is not None:
            host_account = await db.get(HostPaymentAccount, parking_space.owner_id)
        destination_account_id = (
            host_account.provider_account_id
            if host_account is not None
            and host_account.charges_enabled
            and host_account.payouts_enabled
            else None
        )

        payment = existing or Payment(
            booking_id=booking.id,
            payer_user_id=user_id,
            host_user_id=parking_space.owner_id,
            provider=settings.payment_mode,
            status="pending",
            amount_cents=booking.total_price_cents,
            platform_fee_cents=fee_cents,
            host_net_cents=host_net_cents,
            currency=booking.currency,
            destination_account_id=destination_account_id,
            expires_at=expires_at,
        )
        payment.provider = settings.payment_mode
        payment.status = "pending"
        payment.amount_cents = booking.total_price_cents
        payment.platform_fee_cents = fee_cents
        payment.host_net_cents = host_net_cents
        payment.destination_account_id = destination_account_id
        payment.expires_at = expires_at
        payment.failure_message = None
        db.add(payment)
        await db.commit()
        await db.refresh(payment)

        if settings.payment_mode == "beta":
            payment.status = "paid"
            payment.paid_at = datetime.now(timezone.utc)
            await BookingService.confirm_paid(
                db,
                booking,
                payment_reference=f"beta:{payment.id}",
            )
            await db.refresh(payment)
            return {
                "requires_redirect": False,
                "booking_id": str(booking.id),
                "payment": payment_out(payment),
            }

        if not settings.stripe_enabled:
            payment.status = "failed"
            payment.failure_message = "Stripe ist nicht konfiguriert."
            await BookingService.expire_pending(
                db,
                booking,
                reason="payments_not_configured",
            )
            await db.refresh(payment)
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail={
                    "code": "payments_not_configured",
                    "message": "Online-Zahlungen sind noch nicht konfiguriert.",
                },
            )

        try:
            session = await StripeGateway.create_checkout_session(
                booking=booking,
                parking_space=parking_space,
                customer_email=user.email,
                application_fee_cents=fee_cents,
                destination_account_id=destination_account_id,
                expires_at=expires_at,
            )
        except Exception as error:
            payment.status = "failed"
            payment.failure_message = str(error)[:500]
            await BookingService.expire_pending(db, booking, reason="checkout_failed")
            await db.refresh(payment)
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail={
                    "code": "checkout_failed",
                    "message": "Die Zahlungsseite konnte nicht geöffnet werden.",
                },
            ) from error

        payment.status = "checkout_created"
        payment.checkout_session_id = session.id
        payment.checkout_url = session.url
        await db.commit()
        await db.refresh(payment)
        return {
            "requires_redirect": True,
            "booking_id": str(booking.id),
            "payment": payment_out(payment),
        }

    @staticmethod
    async def checkout_status(
        db: AsyncSession,
        user_id: uuid.UUID,
        session_id: str,
    ) -> dict[str, Any]:
        payment = await db.scalar(
            select(Payment).where(
                Payment.checkout_session_id == session_id,
                Payment.payer_user_id == user_id,
            )
        )
        if payment is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        return {
            "booking_id": str(payment.booking_id),
            "payment": payment_out(payment),
        }

    @staticmethod
    async def refund_booking(
        db: AsyncSession,
        booking: Booking,
    ) -> Payment | None:
        payment = await db.scalar(select(Payment).where(Payment.booking_id == booking.id))
        if payment is None or payment.status in {"refunded", "refund_pending"}:
            return payment
        if payment.status != "paid":
            return payment

        if payment.provider == "beta":
            payment.status = "refunded"
            payment.refunded_at = datetime.now(timezone.utc)
            payment.refund_id = f"beta-refund:{payment.id}"
            await db.commit()
            return payment

        refund = await StripeGateway.refund(payment)
        payment.refund_id = refund.id
        payment.status = (
            "refunded" if getattr(refund, "status", None) == "succeeded" else "refund_pending"
        )
        if payment.status == "refunded":
            payment.refunded_at = datetime.now(timezone.utc)
        await db.commit()
        return payment

    @staticmethod
    async def connect_status(
        db: AsyncSession,
        user_id: uuid.UUID,
        *,
        refresh: bool = True,
    ) -> dict[str, Any]:
        account = await db.get(HostPaymentAccount, user_id)
        if account is not None and refresh and settings.stripe_enabled:
            remote = await StripeGateway.retrieve_account(account.provider_account_id)
            account.details_submitted = bool(remote.details_submitted)
            account.charges_enabled = bool(remote.charges_enabled)
            account.payouts_enabled = bool(remote.payouts_enabled)
            await db.commit()
            await db.refresh(account)
        return {
            "mode": settings.payment_mode,
            "configured": settings.stripe_enabled,
            "connected": account is not None,
            "details_submitted": account.details_submitted if account else False,
            "charges_enabled": account.charges_enabled if account else False,
            "payouts_enabled": account.payouts_enabled if account else False,
        }

    @staticmethod
    async def onboarding_link(
        db: AsyncSession,
        user_id: uuid.UUID,
    ) -> dict[str, str]:
        user = await db.get(User, user_id)
        if user is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
        account = await db.get(HostPaymentAccount, user_id)
        if account is None:
            remote = await StripeGateway.create_account(user.email)
            account = HostPaymentAccount(
                user_id=user_id,
                provider="stripe",
                provider_account_id=remote.id,
                details_submitted=bool(remote.details_submitted),
                charges_enabled=bool(remote.charges_enabled),
                payouts_enabled=bool(remote.payouts_enabled),
                country=settings.stripe_country,
            )
            db.add(account)
            await db.commit()
        link = await StripeGateway.onboarding_link(account.provider_account_id)
        return {"url": link.url}

    @staticmethod
    async def dashboard_link(
        db: AsyncSession,
        user_id: uuid.UUID,
    ) -> dict[str, str]:
        account = await db.get(HostPaymentAccount, user_id)
        if account is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "stripe_not_connected",
                    "message": "Verbinde zuerst dein Auszahlungskonto.",
                },
            )
        link = await StripeGateway.dashboard_link(account.provider_account_id)
        return {"url": link.url}

    @staticmethod
    async def finance(db: AsyncSession, user_id: uuid.UUID) -> dict[str, Any]:
        payments = list(
            (
                await db.scalars(
                    select(Payment)
                    .where(Payment.host_user_id == user_id)
                    .order_by(Payment.created_at.desc())
                )
            ).all()
        )
        paid = [payment for payment in payments if payment.status == "paid"]
        refunded = [payment for payment in payments if payment.status == "refunded"]
        pending = [
            payment
            for payment in payments
            if payment.status in {"pending", "checkout_created", "refund_pending"}
        ]
        return {
            "currency": "EUR",
            "gross_paid_cents": sum(payment.amount_cents for payment in paid),
            "platform_fee_cents": sum(payment.platform_fee_cents for payment in paid),
            "host_net_cents": sum(payment.host_net_cents for payment in paid),
            "pending_cents": sum(payment.host_net_cents for payment in pending),
            "refunded_cents": sum(payment.amount_cents for payment in refunded),
            "transactions": [payment_out(payment) for payment in payments[:100]],
            "connect": await PaymentService.connect_status(
                db,
                user_id,
                refresh=False,
            ),
        }

    @staticmethod
    async def process_webhook(
        db: AsyncSession,
        payload: bytes,
        signature: str,
    ) -> None:
        event = StripeGateway.construct_event(payload, signature)
        event_id = event["id"]
        if await db.get(PaymentWebhookEvent, event_id) is not None:
            return

        event_type = event["type"]
        obj = event["data"]["object"]
        db.add(PaymentWebhookEvent(event_id=event_id, event_type=event_type))

        if event_type == "account.updated":
            account = await db.scalar(
                select(HostPaymentAccount).where(
                    HostPaymentAccount.provider_account_id == obj["id"]
                )
            )
            if account is not None:
                account.details_submitted = bool(obj.get("details_submitted"))
                account.charges_enabled = bool(obj.get("charges_enabled"))
                account.payouts_enabled = bool(obj.get("payouts_enabled"))
                await db.commit()
            return

        payment = None
        if event_type.startswith("checkout.session"):
            payment = await db.scalar(
                select(Payment).where(Payment.checkout_session_id == obj["id"])
            )
        elif event_type.startswith("payment_intent"):
            payment = await db.scalar(
                select(Payment).where(Payment.payment_intent_id == obj["id"])
            )
        elif event_type.startswith("charge") and obj.get("payment_intent"):
            payment = await db.scalar(
                select(Payment).where(
                    Payment.payment_intent_id == obj["payment_intent"]
                )
            )

        if payment is None:
            await db.commit()
            return
        booking = await db.get(Booking, payment.booking_id)
        if booking is None:
            await db.commit()
            return

        if event_type == "checkout.session.completed" and obj.get("payment_status") == "paid":
            payment.status = "paid"
            payment.payment_intent_id = obj.get("payment_intent")
            payment.paid_at = datetime.now(timezone.utc)
            await BookingService.confirm_paid(
                db,
                booking,
                payment_reference=payment.payment_intent_id or obj["id"],
            )
            return

        if event_type == "checkout.session.expired":
            payment.status = "expired"
            payment.failure_message = "Checkout Session abgelaufen."
            await BookingService.expire_pending(db, booking, reason="checkout_expired")
            return

        if event_type == "payment_intent.payment_failed":
            payment.status = "failed"
            last_error = obj.get("last_payment_error") or {}
            payment.failure_message = last_error.get("message", "Zahlung fehlgeschlagen.")
            await BookingService.expire_pending(db, booking, reason="payment_failed")
            return

        if event_type == "charge.succeeded":
            payment.charge_id = obj.get("id")
            await db.commit()
            return

        if event_type == "charge.refunded":
            payment.status = "refunded"
            payment.refunded_at = datetime.now(timezone.utc)
            payment.charge_id = obj.get("id")
            refunds = (obj.get("refunds") or {}).get("data") or []
            if refunds:
                payment.refund_id = refunds[0].get("id")
            booking.status = BookingStatus.cancelled
            booking.cancelled_at = datetime.now(timezone.utc)
            booking.access_code = ""
            booking.parking_pass_token = ""
            db.add(
                BookingEvent(
                    booking_id=booking.id,
                    event_type="payment_refunded",
                    event_metadata={"refund_id": payment.refund_id},
                )
            )
            await db.commit()
            return

        await db.commit()
