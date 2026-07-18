import enum
import uuid
from datetime import datetime, time

from sqlalchemy import DateTime, Enum, ForeignKey, Index, JSON, Numeric, String, Text, Time
from sqlalchemy import UniqueConstraint
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from sqlalchemy.sql import func


class Base(DeclarativeBase):
    pass


class Timestamp:
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )


class User(Timestamp, Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    password_hash: Mapped[str]
    display_name: Mapped[str]
    is_active: Mapped[bool] = mapped_column(default=True)


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class Vehicle(Timestamp, Base):
    __tablename__ = "vehicles"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
    )
    name: Mapped[str]
    plate: Mapped[str]
    height_m: Mapped[float] = mapped_column(Numeric(4, 2))
    width_m: Mapped[float] = mapped_column(Numeric(4, 2))
    length_m: Mapped[float] = mapped_column(Numeric(4, 2))
    is_default: Mapped[bool] = mapped_column(default=False)


class ParkingSpace(Timestamp, Base):
    __tablename__ = "parking_spaces"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        index=True,
        nullable=True,
    )
    slug: Mapped[str] = mapped_column(unique=True, index=True)
    title: Mapped[str]
    district: Mapped[str]
    landmark: Mapped[str]
    latitude: Mapped[float] = mapped_column(Numeric(9, 6))
    longitude: Mapped[float] = mapped_column(Numeric(9, 6))
    exact_address: Mapped[str]
    entrance_instructions: Mapped[str] = mapped_column(Text)
    hourly_price_cents: Mapped[int]
    currency: Mapped[str] = mapped_column(default="EUR")
    max_height_m: Mapped[float] = mapped_column(Numeric(4, 2))
    max_width_m: Mapped[float] = mapped_column(Numeric(4, 2))
    max_length_m: Mapped[float] = mapped_column(Numeric(4, 2))
    access_type: Mapped[str]
    is_covered: Mapped[bool]
    has_ev_charging: Mapped[bool]
    is_accessible: Mapped[bool]
    is_instant_bookable: Mapped[bool]
    is_verified: Mapped[bool]
    rating: Mapped[float] = mapped_column(Numeric(2, 1))
    review_count: Mapped[int]
    status: Mapped[str] = mapped_column(default="active", index=True)


class ParkingSpaceImage(Base):
    __tablename__ = "parking_space_images"

    id: Mapped[int] = mapped_column(primary_key=True)
    parking_space_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("parking_spaces.id", ondelete="CASCADE"),
        index=True,
    )
    image_url: Mapped[str]
    sort_order: Mapped[int] = mapped_column(default=0)
    alt_text: Mapped[str]


class AvailabilityRule(Base):
    __tablename__ = "availability_rules"

    id: Mapped[int] = mapped_column(primary_key=True)
    parking_space_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("parking_spaces.id", ondelete="CASCADE"),
        index=True,
    )
    weekday: Mapped[int]
    start_time: Mapped[time] = mapped_column(Time)
    end_time: Mapped[time] = mapped_column(Time)
    active: Mapped[bool] = mapped_column(default=True)
    price_override_cents: Mapped[int | None] = mapped_column(nullable=True)


class AvailabilityBlock(Base):
    __tablename__ = "availability_blocks"

    id: Mapped[int] = mapped_column(primary_key=True)
    parking_space_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("parking_spaces.id", ondelete="CASCADE"),
        index=True,
    )
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    reason: Mapped[str | None]


class BookingStatus(str, enum.Enum):
    pending = "pending"
    confirmed = "confirmed"
    cancelled = "cancelled"
    completed = "completed"
    expired = "expired"


class Booking(Base):
    __tablename__ = "bookings"
    __table_args__ = (
        UniqueConstraint("user_id", "idempotency_key"),
        Index(
            "ix_booking_overlap",
            "parking_space_id",
            "start_at",
            "end_at",
            "status",
        ),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    public_reference: Mapped[str] = mapped_column(unique=True, index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.id"),
        index=True,
    )
    parking_space_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("parking_spaces.id"),
        index=True,
    )
    vehicle_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("vehicles.id"))
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    end_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    status: Mapped[BookingStatus] = mapped_column(Enum(BookingStatus), index=True)
    hourly_price_cents_snapshot: Mapped[int]
    total_price_cents: Mapped[int]
    currency: Mapped[str]
    access_code: Mapped[str]
    parking_pass_token: Mapped[str]
    idempotency_key: Mapped[str]
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    confirmed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancellation_reason: Mapped[str | None]


class BookingEvent(Base):
    __tablename__ = "booking_events"

    id: Mapped[int] = mapped_column(primary_key=True)
    booking_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"),
        index=True,
    )
    event_type: Mapped[str]
    event_metadata: Mapped[dict] = mapped_column("metadata", JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
