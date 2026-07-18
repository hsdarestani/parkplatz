import asyncio

import stripe
from fastapi import HTTPException, status

from app.models import Payment
from app.services.payments import StripeGateway


async def cancel_unpaid_checkout(payment: Payment) -> None:
    if payment.status not in {"pending", "checkout_created", "failed", "expired"}:
        return

    if (
        payment.provider == "stripe"
        and payment.checkout_session_id
        and payment.status == "checkout_created"
    ):
        StripeGateway.configure()
        session = await asyncio.to_thread(
            stripe.checkout.Session.retrieve,
            payment.checkout_session_id,
        )
        if getattr(session, "payment_status", None) == "paid":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "payment_processing",
                    "message": (
                        "Die Zahlung wird gerade bestätigt. "
                        "Bitte versuche die Stornierung gleich erneut."
                    ),
                },
            )
        if getattr(session, "status", None) == "open":
            await asyncio.to_thread(
                stripe.checkout.Session.expire,
                payment.checkout_session_id,
            )

    payment.status = "cancelled"
    payment.checkout_url = None
    payment.failure_message = "Vom Nutzer vor Zahlungsabschluss storniert."
