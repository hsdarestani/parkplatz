# FREIRAUM Payments

FREIRAUM supports two payment modes:

- `beta`: creates the complete payment ledger and confirms the booking without charging a card.
- `stripe`: opens Stripe Checkout, confirms the booking only after a verified webhook, routes the owner share through Stripe Connect, and refunds paid bookings when they are cancelled.

Production is intentionally provisioned in `beta` mode until Stripe credentials are added manually.

## Stripe production configuration

Add these values to `/srv/parkplatz/.env.production` on the server:

```env
PAYMENT_MODE=stripe
PUBLIC_APP_URL=https://parkplatz.smarbiz.sbs
PLATFORM_FEE_BASIS_POINTS=1500
PAYMENT_HOLD_MINUTES=31
STRIPE_COUNTRY=DE
STRIPE_SECRET_KEY=sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

The default platform fee is 15%. Change `PLATFORM_FEE_BASIS_POINTS` deliberately if the commercial model changes.

## Stripe webhook

Create a Stripe webhook endpoint for:

```text
https://parkplatz.smarbiz.sbs/api/payments/webhook
```

Subscribe at least to:

- `checkout.session.completed`
- `checkout.session.expired`
- `payment_intent.payment_failed`
- `charge.succeeded`
- `charge.refunded`
- `account.updated`

Copy the endpoint signing secret into `STRIPE_WEBHOOK_SECRET`.

## Connect onboarding

Owners open **Finanzen & Auszahlungen** from the host dashboard and complete Stripe Express onboarding. Live Stripe checkout is blocked for an owner-managed space until both `charges_enabled` and `payouts_enabled` are true. This prevents accepting customer money without a payout-ready destination.

## Booking lifecycle

1. Checkout creates a `pending` booking and a payment hold.
2. Stripe Checkout receives the server-calculated amount.
3. The verified webhook marks the payment `paid` and changes the booking to `confirmed`.
4. Only confirmed bookings receive an address, access code, and Parking Pass.
5. Failed or expired payments release the booking hold.
6. Cancelling a paid booking requests a refund; cancelling an unpaid checkout closes the Stripe session first.

## Deployment

After changing production secrets:

```bash
cd /srv/parkplatz
docker compose -f docker-compose.prod.yml up -d --build
```

Verify the public health endpoint and make a Stripe test-mode booking before switching to live keys.
