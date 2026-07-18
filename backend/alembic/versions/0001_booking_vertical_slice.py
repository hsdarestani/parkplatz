"""Create the original booking vertical-slice schema.

Revision ID: 0001
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None

booking_status = sa.Enum(
    "pending",
    "confirmed",
    "cancelled",
    "completed",
    "expired",
    name="bookingstatus",
)


def upgrade() -> None:
    # Keep this migration independent from the live ORM metadata. Importing
    # Base.metadata here made fresh databases silently include future columns
    # before the migrations that were supposed to add them.
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("email", sa.String(length=320), nullable=False),
        sa.Column("password_hash", sa.String(), nullable=False),
        sa.Column("display_name", sa.String(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "refresh_tokens",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token_hash"),
    )
    op.create_index("ix_refresh_tokens_user_id", "refresh_tokens", ["user_id"], unique=False)

    op.create_table(
        "vehicles",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("plate", sa.String(), nullable=False),
        sa.Column("height_m", sa.Numeric(4, 2), nullable=False),
        sa.Column("width_m", sa.Numeric(4, 2), nullable=False),
        sa.Column("length_m", sa.Numeric(4, 2), nullable=False),
        sa.Column("is_default", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_vehicles_user_id", "vehicles", ["user_id"], unique=False)

    op.create_table(
        "parking_spaces",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("slug", sa.String(), nullable=False),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("district", sa.String(), nullable=False),
        sa.Column("landmark", sa.String(), nullable=False),
        sa.Column("latitude", sa.Numeric(9, 6), nullable=False),
        sa.Column("longitude", sa.Numeric(9, 6), nullable=False),
        sa.Column("exact_address", sa.String(), nullable=False),
        sa.Column("entrance_instructions", sa.Text(), nullable=False),
        sa.Column("hourly_price_cents", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(), nullable=False),
        sa.Column("max_height_m", sa.Numeric(4, 2), nullable=False),
        sa.Column("max_width_m", sa.Numeric(4, 2), nullable=False),
        sa.Column("max_length_m", sa.Numeric(4, 2), nullable=False),
        sa.Column("access_type", sa.String(), nullable=False),
        sa.Column("is_covered", sa.Boolean(), nullable=False),
        sa.Column("has_ev_charging", sa.Boolean(), nullable=False),
        sa.Column("is_accessible", sa.Boolean(), nullable=False),
        sa.Column("is_instant_bookable", sa.Boolean(), nullable=False),
        sa.Column("is_verified", sa.Boolean(), nullable=False),
        sa.Column("rating", sa.Numeric(2, 1), nullable=False),
        sa.Column("review_count", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_parking_spaces_slug", "parking_spaces", ["slug"], unique=True)
    op.create_index("ix_parking_spaces_status", "parking_spaces", ["status"], unique=False)

    op.create_table(
        "parking_space_images",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("parking_space_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("image_url", sa.String(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("alt_text", sa.String(), nullable=False),
        sa.ForeignKeyConstraint(["parking_space_id"], ["parking_spaces.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_parking_space_images_parking_space_id",
        "parking_space_images",
        ["parking_space_id"],
        unique=False,
    )

    op.create_table(
        "availability_rules",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("parking_space_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("weekday", sa.Integer(), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=False),
        sa.Column("end_time", sa.Time(), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(["parking_space_id"], ["parking_spaces.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_availability_rules_parking_space_id",
        "availability_rules",
        ["parking_space_id"],
        unique=False,
    )

    op.create_table(
        "availability_blocks",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("parking_space_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("reason", sa.String(), nullable=True),
        sa.ForeignKeyConstraint(["parking_space_id"], ["parking_spaces.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_availability_blocks_parking_space_id",
        "availability_blocks",
        ["parking_space_id"],
        unique=False,
    )

    op.create_table(
        "bookings",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("public_reference", sa.String(), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("parking_space_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("vehicle_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("start_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", booking_status, nullable=False),
        sa.Column("hourly_price_cents_snapshot", sa.Integer(), nullable=False),
        sa.Column("total_price_cents", sa.Integer(), nullable=False),
        sa.Column("currency", sa.String(), nullable=False),
        sa.Column("access_code", sa.String(), nullable=False),
        sa.Column("parking_pass_token", sa.String(), nullable=False),
        sa.Column("idempotency_key", sa.String(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancellation_reason", sa.String(), nullable=True),
        sa.ForeignKeyConstraint(["parking_space_id"], ["parking_spaces.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["vehicle_id"], ["vehicles.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id", "idempotency_key"),
    )
    op.create_index("ix_bookings_parking_space_id", "bookings", ["parking_space_id"], unique=False)
    op.create_index("ix_bookings_public_reference", "bookings", ["public_reference"], unique=True)
    op.create_index("ix_bookings_status", "bookings", ["status"], unique=False)
    op.create_index("ix_bookings_user_id", "bookings", ["user_id"], unique=False)
    op.create_index(
        "ix_booking_overlap",
        "bookings",
        ["parking_space_id", "start_at", "end_at", "status"],
        unique=False,
    )

    op.create_table(
        "booking_events",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("booking_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("event_type", sa.String(), nullable=False),
        sa.Column("metadata", sa.JSON(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.ForeignKeyConstraint(["booking_id"], ["bookings.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_booking_events_booking_id", "booking_events", ["booking_id"], unique=False)


def downgrade() -> None:
    op.drop_table("booking_events")
    op.drop_table("bookings")
    op.drop_table("availability_blocks")
    op.drop_table("availability_rules")
    op.drop_table("parking_space_images")
    op.drop_table("parking_spaces")
    op.drop_table("vehicles")
    op.drop_table("refresh_tokens")
    op.drop_table("users")
    booking_status.drop(op.get_bind(), checkfirst=True)
