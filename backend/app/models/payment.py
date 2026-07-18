import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy.sql import func

from .base import Base, Timestamp


class HostPaymentAccount(Timestamp, Base):
    __tablename__ = "host_payment_accounts"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    provider: Mapped[str] = mapped_column(String(24), default="stripe")
    provider_account_id: Mapped[str] = mapped_column(String(128), unique=True)
    details_submitted: Mapped[bool] = mapped_column(default=False)
    charges_enabled: Mapped[bool] = mapped_column(default=False)
    payouts_enabled: Mapped[bool] = mapped_column(default=False)
    country: Mapped[str] = mapped_column(String(2), default="DE")


class Payment(Timestamp, Base):
    __tablename__ = "payments"
    __table_args__ = (
        UniqueConstraint("booking_id"),
        Index("ix_payments_host_status", "host_user_id", "status"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    booking_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"),
        unique=True,
        index=True,
    )
    payer_user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    host_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    provider: Mapped[str] = mapped_column(String(24), default="beta")
    status: Mapped[str] = mapped_column(String(32), default="pending", index=True)
    amount_cents: Mapped[int]
    platform_fee_cents: Mapped[int]
    host_net_cents: Mapped[int]
    currency: Mapped[str] = mapped_column(String(3), default="EUR")
    checkout_session_id: Mapped[str | None] = mapped_column(
        String(255),
        unique=True,
        nullable=True,
    )
    checkout_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    payment_intent_id: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
        index=True,
    )
    charge_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    refund_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    destination_account_id: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )
    payment_method: Mapped[str | None] = mapped_column(String(16), nullable=True)
    payer_reference: Mapped[str | None] = mapped_column(String(255), nullable=True)
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    host_confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    rejected_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    paid_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    refunded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    failure_message: Mapped[str | None] = mapped_column(String(500), nullable=True)


class PaymentWebhookEvent(Base):
    __tablename__ = "payment_webhook_events"

    event_id: Mapped[str] = mapped_column(String(255), primary_key=True)
    event_type: Mapped[str] = mapped_column(String(120), index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
