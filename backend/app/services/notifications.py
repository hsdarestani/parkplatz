import asyncio
import os
import smtplib
import uuid
from datetime import datetime, timezone
from email.message import EmailMessage
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models import (
    Booking,
    NotificationOutbox,
    NotificationPreference,
    ParkingSpace,
    Payment,
    User,
)


EVENT_CATEGORIES = {
    "booking_confirmed": "booking_updates",
    "booking_cancelled": "booking_updates",
    "booking_refunded": "booking_updates",
    "direct_payment_submitted_renter": "booking_updates",
    "direct_payment_confirmed": "booking_updates",
    "direct_payment_rejected": "booking_updates",
    "host_confirmation_timeout_renter": "booking_updates",
    "manual_refund_pending": "booking_updates",
    "manual_refund_completed": "booking_updates",
    "host_booking_received": "host_updates",
    "host_booking_cancelled": "host_updates",
    "direct_payment_submitted_host": "host_updates",
    "host_confirmation_timeout_host": "host_updates",
    "manual_refund_required": "host_updates",
    "pro_plan_requested": "host_updates",
    "pro_plan_activated": "host_updates",
    "plan_changed": "host_updates",
    "verification_submitted": "trust_updates",
    "verification_approved": "trust_updates",
    "verification_rejected": "trust_updates",
    "safety_report_received": "trust_updates",
    "safety_report_triaged": "trust_updates",
    "safety_report_resolved": "trust_updates",
    "safety_report_dismissed": "trust_updates",
    "password_reset_requested": "security_updates",
    "password_changed": "security_updates",
    "account_deleted": "security_updates",
}


def event_category(event_type: str) -> str:
    return EVENT_CATEGORIES.get(event_type, "security_updates")


def _preference_out(preference: NotificationPreference | None) -> dict[str, bool]:
    return {
        "booking_updates": preference.booking_updates if preference else True,
        "host_updates": preference.host_updates if preference else True,
        "trust_updates": preference.trust_updates if preference else True,
        "security_updates": preference.security_updates if preference else True,
        "marketing": preference.marketing if preference else False,
    }


async def queue_email(
    db: AsyncSession,
    *,
    user_id: uuid.UUID | None,
    recipient: str,
    event_type: str,
    deduplication_key: str,
    payload: dict[str, Any],
    force: bool = False,
) -> NotificationOutbox | None:
    existing = await db.scalar(
        select(NotificationOutbox).where(
            NotificationOutbox.deduplication_key == deduplication_key
        )
    )
    if existing is not None:
        return existing

    if user_id is not None and not force:
        preference = await db.get(NotificationPreference, user_id)
        values = _preference_out(preference)
        if not values.get(event_category(event_type), True):
            return None

    record = NotificationOutbox(
        user_id=user_id,
        event_type=event_type,
        channel="email",
        recipient=recipient.strip().lower(),
        payload=payload,
        status="queued",
        deduplication_key=deduplication_key,
    )
    db.add(record)
    return record


def render_email(event_type: str, payload: dict[str, Any]) -> tuple[str, str]:
    reference = payload.get("reference", "")
    parking_title = payload.get("parking_title", "Stellplatz")
    start_at = payload.get("start_at", "")
    end_at = payload.get("end_at", "")
    amount = payload.get("amount", "")
    note = payload.get("note") or ""

    if event_type == "booking_confirmed":
        return (
            f"Buchung {reference} bestätigt",
            f"Deine Buchung für {parking_title} ist bestätigt.\n"
            f"Zeitraum: {start_at} bis {end_at}\nBetrag: {amount}\n"
            "Adresse und Parking Pass sind jetzt in FREIRAUM verfügbar.",
        )
    if event_type == "host_booking_received":
        return (
            f"Neue Buchung {reference}",
            f"Dein Stellplatz {parking_title} wurde gebucht.\n"
            f"Zeitraum: {start_at} bis {end_at}\nDein Anteil: {amount}",
        )
    if event_type in {"booking_cancelled", "booking_refunded"}:
        return (
            f"Buchung {reference} storniert",
            f"Die Buchung für {parking_title} wurde storniert.\n"
            f"Erstattungsstatus: {payload.get('refund_status', 'wird bearbeitet')}.",
        )
    if event_type == "host_booking_cancelled":
        return (
            f"Buchung {reference} storniert",
            f"Die Buchung für deinen Stellplatz {parking_title} wurde storniert.",
        )
    if event_type == "direct_payment_submitted_host":
        return (
            f"Zahlung für {reference} prüfen",
            f"Der Mieter hat eine Direktzahlung für {parking_title} eingereicht.\n"
            f"Betrag: {amount}\nReferenz: {payload.get('payer_reference', '')}\n"
            f"Bitte bestätige oder lehne die Zahlung bis {payload.get('due_at', '')} ab.",
        )
    if event_type == "direct_payment_submitted_renter":
        return (
            f"Zahlung für {reference} eingereicht",
            f"Deine Zahlung für {parking_title} wurde an den Anbieter zur Prüfung gesendet.\n"
            f"Betrag: {amount}\nDie Buchung wird nach Bestätigung freigeschaltet.",
        )
    if event_type == "direct_payment_confirmed":
        return (
            f"Zahlung für {reference} bestätigt",
            f"Der Anbieter hat deine Zahlung für {parking_title} bestätigt. "
            "Adresse und Parking Pass sind jetzt verfügbar.",
        )
    if event_type == "direct_payment_rejected":
        return (
            f"Zahlung für {reference} nicht bestätigt",
            f"Der Anbieter konnte die Zahlung für {parking_title} nicht bestätigen.\n{note}",
        )
    if event_type == "host_confirmation_timeout_renter":
        return (
            f"Buchung {reference} automatisch beendet",
            f"Der Anbieter hat die Zahlung für {parking_title} nicht rechtzeitig geprüft. "
            "Die Reservierung wurde automatisch beendet. Kontaktiere den Support, falls Geld "
            "überwiesen wurde.",
        )
    if event_type == "host_confirmation_timeout_host":
        return (
            f"Bestätigungsfrist für {reference} abgelaufen",
            f"Die Reservierung für {parking_title} wurde beendet, weil keine rechtzeitige "
            "Zahlungsentscheidung eingegangen ist.",
        )
    if event_type == "manual_refund_required":
        return (
            f"Rückerstattung für {reference} erforderlich",
            f"Die Buchung für {parking_title} wurde storniert. Bitte erstatte {amount} direkt "
            "an den Mieter und trage anschließend die Rückerstattungsreferenz in FREIRAUM ein.",
        )
    if event_type == "manual_refund_pending":
        return (
            f"Rückerstattung für {reference} angefordert",
            f"Der Anbieter wurde aufgefordert, {amount} für {parking_title} direkt zu erstatten.",
        )
    if event_type == "manual_refund_completed":
        return (
            f"Rückerstattung für {reference} bestätigt",
            f"Der Anbieter hat die Rückerstattung über {amount} als ausgeführt markiert.\n"
            f"Referenz: {payload.get('refund_reference', '')}",
        )
    if event_type == "pro_plan_requested":
        return (
            "FREIRAUM Pro angefragt",
            "Deine Pro-Anfrage wurde gespeichert. Wir melden uns zur Aktivierung und Abrechnung.",
        )
    if event_type == "pro_plan_activated":
        return (
            "FREIRAUM Pro aktiviert",
            "Dein Pro-Tarif ist aktiv. Du kannst jetzt mehr Stellplätze veröffentlichen und "
            "profitierst von einer schnelleren Zahlungsbearbeitung.",
        )
    if event_type == "plan_changed":
        return (
            "FREIRAUM Tarif aktualisiert",
            f"Dein Tarif wurde auf {payload.get('plan', 'free')} gesetzt.",
        )
    if event_type == "password_reset_requested":
        return (
            "FREIRAUM Passwort zurücksetzen",
            "Über diesen Link kannst du ein neues Passwort setzen:\n"
            f"{payload.get('reset_url', '')}\n\n"
            "Der Link ist nur kurze Zeit gültig. Falls du das nicht angefordert hast, "
            "kannst du diese Nachricht ignorieren.",
        )
    if event_type == "password_changed":
        return (
            "FREIRAUM Passwort geändert",
            "Dein Passwort wurde geändert. Falls du das nicht warst, kontaktiere "
            "sofort info@aplus-solution.de.",
        )
    if event_type == "account_deleted":
        return (
            "FREIRAUM Konto gelöscht",
            "Dein Konto wurde deaktiviert und deine personenbezogenen Profildaten "
            "wurden anonymisiert.",
        )
    if event_type.startswith("verification_"):
        labels = {
            "verification_submitted": "eingereicht",
            "verification_approved": "bestätigt",
            "verification_rejected": "abgelehnt",
        }
        return (
            f"Stellplatzprüfung {labels.get(event_type, 'aktualisiert')}",
            f"Status für {parking_title}: {labels.get(event_type, 'aktualisiert')}.\n"
            f"{note}",
        )
    if event_type.startswith("safety_report_"):
        return (
            "FREIRAUM Supportanfrage aktualisiert",
            f"Der Status deiner Anfrage wurde aktualisiert.\n{note}",
        )
    return ("FREIRAUM Benachrichtigung", str(payload))


def _send_smtp(record: NotificationOutbox) -> None:
    host = os.getenv("SMTP_HOST", "")
    port = int(os.getenv("SMTP_PORT", "587"))
    sender = os.getenv("SMTP_FROM_EMAIL", "info@aplus-solution.de")
    sender_name = os.getenv("SMTP_FROM_NAME", "FREIRAUM")
    username = os.getenv("SMTP_USERNAME", "")
    password = os.getenv("SMTP_PASSWORD", "")
    use_ssl = os.getenv("SMTP_SSL", "false").lower() in {"1", "true", "yes"}
    use_starttls = os.getenv("SMTP_STARTTLS", "true").lower() in {"1", "true", "yes"}

    subject, body = render_email(record.event_type, record.payload)
    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = f"{sender_name} <{sender}>"
    message["To"] = record.recipient
    message.set_content(body)

    client_class = smtplib.SMTP_SSL if use_ssl else smtplib.SMTP
    with client_class(host, port, timeout=20) as client:
        if use_starttls and not use_ssl:
            client.starttls()
        if username:
            client.login(username, password)
        client.send_message(message)


async def deliver_queued(db: AsyncSession, limit: int = 25) -> int:
    mode = os.getenv("EMAIL_MODE", "auto").lower()
    if mode not in {"auto", "smtp"} or not os.getenv("SMTP_HOST"):
        return 0

    records = list(
        (
            await db.scalars(
                select(NotificationOutbox)
                .where(NotificationOutbox.status == "queued")
                .order_by(NotificationOutbox.created_at)
                .limit(limit)
                .with_for_update(skip_locked=True)
            )
        ).all()
    )
    delivered = 0
    for record in records:
        try:
            await asyncio.to_thread(_send_smtp, record)
            record.status = "sent"
            record.sent_at = datetime.now(timezone.utc)
            record.failure_message = None
            if record.event_type == "password_reset_requested":
                record.payload = {"delivered": True}
            delivered += 1
        except Exception as error:
            record.status = "failed"
            record.failure_message = str(error)[:500]
    await db.commit()
    return delivered


async def queue_booking_confirmed(
    db: AsyncSession,
    booking: Booking,
    payment: Payment | None = None,
) -> None:
    renter = await db.get(User, booking.user_id)
    parking_space = await db.get(ParkingSpace, booking.parking_space_id)
    if renter is None or parking_space is None:
        return
    payload = {
        "reference": booking.public_reference,
        "parking_title": parking_space.title,
        "start_at": booking.start_at.isoformat(),
        "end_at": booking.end_at.isoformat(),
        "amount": f"{booking.total_price_cents / 100:.2f} {booking.currency}",
    }
    await queue_email(
        db,
        user_id=renter.id,
        recipient=renter.email,
        event_type="booking_confirmed",
        deduplication_key=f"booking-confirmed:{booking.id}",
        payload=payload,
    )
    if parking_space.owner_id is not None:
        host = await db.get(User, parking_space.owner_id)
        if host is not None:
            host_payload = dict(payload)
            host_payload["amount"] = (
                f"{payment.host_net_cents / 100:.2f} {payment.currency}"
                if payment is not None
                else payload["amount"]
            )
            await queue_email(
                db,
                user_id=host.id,
                recipient=host.email,
                event_type="host_booking_received",
                deduplication_key=f"host-booking-received:{booking.id}",
                payload=host_payload,
            )


async def queue_booking_cancelled(
    db: AsyncSession,
    booking: Booking,
    payment: Payment | None = None,
) -> None:
    renter = await db.get(User, booking.user_id)
    parking_space = await db.get(ParkingSpace, booking.parking_space_id)
    if renter is None or parking_space is None:
        return
    payload = {
        "reference": booking.public_reference,
        "parking_title": parking_space.title,
        "refund_status": payment.status if payment is not None else "not_applicable",
    }
    await queue_email(
        db,
        user_id=renter.id,
        recipient=renter.email,
        event_type="booking_cancelled",
        deduplication_key=f"booking-cancelled:{booking.id}",
        payload=payload,
    )
    if parking_space.owner_id is not None:
        host = await db.get(User, parking_space.owner_id)
        if host is not None:
            await queue_email(
                db,
                user_id=host.id,
                recipient=host.email,
                event_type="host_booking_cancelled",
                deduplication_key=f"host-booking-cancelled:{booking.id}",
                payload=payload,
            )
