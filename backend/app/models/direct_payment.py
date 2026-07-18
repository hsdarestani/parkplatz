import uuid

from sqlalchemy import ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from .base import Base, Timestamp


class HostDirectPaymentSettings(Timestamp, Base):
    __tablename__ = "host_direct_payment_settings"

    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        primary_key=True,
    )
    method: Mapped[str] = mapped_column(String(16), default="paypal")
    payment_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)
    iban: Mapped[str | None] = mapped_column(String(34), nullable=True)
    account_holder: Mapped[str | None] = mapped_column(String(120), nullable=True)
    instructions: Mapped[str | None] = mapped_column(Text, nullable=True)
    enabled: Mapped[bool] = mapped_column(default=True)
