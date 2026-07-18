from sqlalchemy import event, inspect, select
from sqlalchemy.dialects.postgresql import insert

from .account import NotificationPreference
from .base import Booking, BookingStatus, ParkingSpace, User
from .payment import Payment
from .trust import NotificationOutbox


def _enabled(connection, user_id, field: str) -> bool:
    value = connection.execute(
        select(getattr(NotificationPreference.__table__.c, field)).where(
            NotificationPreference.__table__.c.user_id == user_id
        )
    ).scalar_one_or_none()
    return True if value is None else bool(value)


def _queue(connection, *, user_id, recipient: str, event_type: str, key: str, payload: dict) -> None:
    connection.execute(
        insert(NotificationOutbox.__table__)
        .values(
            user_id=user_id,
            event_type=event_type,
            channel="email",
            recipient=recipient,
            payload=payload,
            status="queued",
            deduplication_key=key,
        )
        .on_conflict_do_nothing(index_elements=["deduplication_key"])
    )


def _booking_context(connection, target: Booking):
    space = connection.execute(
        select(
            ParkingSpace.__table__.c.title,
            ParkingSpace.__table__.c.owner_id,
        ).where(ParkingSpace.__table__.c.id == target.parking_space_id)
    ).one_or_none()
    renter = connection.execute(
        select(User.__table__.c.email).where(User.__table__.c.id == target.user_id)
    ).scalar_one_or_none()
    if space is None or renter is None:
        return None
    host_email = None
    if space.owner_id is not None:
        host_email = connection.execute(
            select(User.__table__.c.email).where(User.__table__.c.id == space.owner_id)
        ).scalar_one_or_none()
    payment = connection.execute(
        select(
            Payment.__table__.c.host_net_cents,
            Payment.__table__.c.status,
        ).where(Payment.__table__.c.booking_id == target.id)
    ).one_or_none()
    return space, renter, host_email, payment


def _queue_confirmed(connection, target: Booking) -> None:
    context = _booking_context(connection, target)
    if context is None:
        return
    space, renter, host_email, payment = context
    payload = {
        "reference": target.public_reference,
        "parking_title": space.title,
        "start_at": target.start_at.isoformat(),
        "end_at": target.end_at.isoformat(),
        "amount": f"{target.total_price_cents / 100:.2f} {target.currency}",
    }
    if _enabled(connection, target.user_id, "booking_updates"):
        _queue(
            connection,
            user_id=target.user_id,
            recipient=renter,
            event_type="booking_confirmed",
            key=f"booking-confirmed:{target.id}",
            payload=payload,
        )
    if space.owner_id is not None and host_email and _enabled(
        connection, space.owner_id, "host_updates"
    ):
        host_payload = dict(payload)
        if payment is not None:
            host_payload["amount"] = (
                f"{payment.host_net_cents / 100:.2f} {target.currency}"
            )
        _queue(
            connection,
            user_id=space.owner_id,
            recipient=host_email,
            event_type="host_booking_received",
            key=f"host-booking-received:{target.id}",
            payload=host_payload,
        )


def _queue_cancelled(connection, target: Booking) -> None:
    context = _booking_context(connection, target)
    if context is None:
        return
    space, renter, host_email, payment = context
    payload = {
        "reference": target.public_reference,
        "parking_title": space.title,
        "refund_status": payment.status if payment is not None else "not_applicable",
    }
    if _enabled(connection, target.user_id, "booking_updates"):
        _queue(
            connection,
            user_id=target.user_id,
            recipient=renter,
            event_type="booking_cancelled",
            key=f"booking-cancelled:{target.id}",
            payload=payload,
        )
    if space.owner_id is not None and host_email and _enabled(
        connection, space.owner_id, "host_updates"
    ):
        _queue(
            connection,
            user_id=space.owner_id,
            recipient=host_email,
            event_type="host_booking_cancelled",
            key=f"host-booking-cancelled:{target.id}",
            payload=payload,
        )


@event.listens_for(Booking, "after_insert")
def booking_inserted(_mapper, connection, target: Booking) -> None:
    if target.status == BookingStatus.confirmed:
        _queue_confirmed(connection, target)


@event.listens_for(Booking, "after_update")
def booking_updated(_mapper, connection, target: Booking) -> None:
    history = inspect(target).attrs.status.history
    if not history.has_changes():
        return
    if target.status == BookingStatus.confirmed:
        _queue_confirmed(connection, target)
    elif target.status == BookingStatus.cancelled:
        _queue_cancelled(connection, target)
