"""Add verification, safety reports, and notification outbox.

Revision ID: 0007
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "verification_requests",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("parking_space_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("statement", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("review_note", sa.Text(), nullable=True),
        sa.Column("reviewed_by", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["parking_space_id"],
            ["parking_spaces.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_verification_requests_user_id",
        "verification_requests",
        ["user_id"],
    )
    op.create_index(
        "ix_verification_requests_parking_space_id",
        "verification_requests",
        ["parking_space_id"],
    )
    op.create_index(
        "ix_verification_requests_status",
        "verification_requests",
        ["status"],
    )
    op.create_index(
        "ix_verification_requests_status_created",
        "verification_requests",
        ["status", "created_at"],
    )

    op.create_table(
        "safety_reports",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("reporter_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("parking_space_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("booking_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("category", sa.String(length=48), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("resolution_note", sa.Text(), nullable=True),
        sa.Column("reviewed_by", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["reporter_user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["parking_space_id"],
            ["parking_spaces.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(["booking_id"], ["bookings.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        "ix_safety_reports_reporter_user_id",
        "safety_reports",
        ["reporter_user_id"],
    )
    op.create_index(
        "ix_safety_reports_parking_space_id",
        "safety_reports",
        ["parking_space_id"],
    )
    op.create_index("ix_safety_reports_booking_id", "safety_reports", ["booking_id"])
    op.create_index("ix_safety_reports_category", "safety_reports", ["category"])
    op.create_index("ix_safety_reports_status", "safety_reports", ["status"])
    op.create_index(
        "ix_safety_reports_status_created",
        "safety_reports",
        ["status", "created_at"],
    )

    op.create_table(
        "notification_outbox",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("event_type", sa.String(length=80), nullable=False),
        sa.Column("channel", sa.String(length=24), nullable=False),
        sa.Column("recipient", sa.String(length=320), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("deduplication_key", sa.String(length=255), nullable=False),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("failure_message", sa.String(length=500), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("deduplication_key"),
    )
    op.create_index(
        "ix_notification_outbox_user_id",
        "notification_outbox",
        ["user_id"],
    )
    op.create_index(
        "ix_notification_outbox_event_type",
        "notification_outbox",
        ["event_type"],
    )
    op.create_index(
        "ix_notification_outbox_status",
        "notification_outbox",
        ["status"],
    )
    op.create_index(
        "ix_notification_outbox_status_created",
        "notification_outbox",
        ["status", "created_at"],
    )


def downgrade() -> None:
    op.drop_table("notification_outbox")
    op.drop_table("safety_reports")
    op.drop_table("verification_requests")
