"""Add direct owner payment settings and manual confirmation fields.

Revision ID: 0009
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "host_direct_payment_settings",
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("method", sa.String(length=16), nullable=False),
        sa.Column("payment_url", sa.String(length=2048), nullable=True),
        sa.Column("iban", sa.String(length=34), nullable=True),
        sa.Column("account_holder", sa.String(length=120), nullable=True),
        sa.Column("instructions", sa.Text(), nullable=True),
        sa.Column("enabled", sa.Boolean(), nullable=False),
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

    op.add_column(
        "payments",
        sa.Column("payment_method", sa.String(length=16), nullable=True),
    )
    op.add_column(
        "payments",
        sa.Column("payer_reference", sa.String(length=255), nullable=True),
    )
    op.add_column(
        "payments",
        sa.Column("submitted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "payments",
        sa.Column("host_confirmed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "payments",
        sa.Column("rejected_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("payments", "rejected_at")
    op.drop_column("payments", "host_confirmed_at")
    op.drop_column("payments", "submitted_at")
    op.drop_column("payments", "payer_reference")
    op.drop_column("payments", "payment_method")
    op.drop_table("host_direct_payment_settings")
