"""Add host plans, receipt uploads, manual refunds, and response deadlines.

Revision ID: 0010
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0010"
down_revision = "0009"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "host_subscriptions",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("plan", sa.String(length=16), nullable=False, server_default="free"),
        sa.Column("status", sa.String(length=24), nullable=False, server_default="active"),
        sa.Column("requested_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("active_until", sa.DateTime(timezone=True), nullable=True),
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
        sa.PrimaryKeyConstraint("user_id"),
    )
    op.create_index("ix_host_subscriptions_plan_status", "host_subscriptions", ["plan", "status"])

    op.add_column("payments", sa.Column("receipt_storage_key", sa.String(length=255), nullable=True))
    op.add_column("payments", sa.Column("receipt_original_name", sa.String(length=255), nullable=True))
    op.add_column("payments", sa.Column("receipt_mime_type", sa.String(length=120), nullable=True))
    op.add_column("payments", sa.Column("receipt_size_bytes", sa.Integer(), nullable=True))
    op.add_column("payments", sa.Column("receipt_access_token", sa.String(length=128), nullable=True))
    op.create_index(
        "ix_payments_receipt_access_token",
        "payments",
        ["receipt_access_token"],
        unique=True,
    )
    op.add_column(
        "payments",
        sa.Column("host_response_due_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_payments_host_response_due",
        "payments",
        ["status", "host_response_due_at"],
    )
    op.add_column("payments", sa.Column("refund_reference", sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column("payments", "refund_reference")
    op.drop_index("ix_payments_host_response_due", table_name="payments")
    op.drop_column("payments", "host_response_due_at")
    op.drop_index("ix_payments_receipt_access_token", table_name="payments")
    op.drop_column("payments", "receipt_access_token")
    op.drop_column("payments", "receipt_size_bytes")
    op.drop_column("payments", "receipt_mime_type")
    op.drop_column("payments", "receipt_original_name")
    op.drop_column("payments", "receipt_storage_key")
    op.drop_index("ix_host_subscriptions_plan_status", table_name="host_subscriptions")
    op.drop_table("host_subscriptions")
