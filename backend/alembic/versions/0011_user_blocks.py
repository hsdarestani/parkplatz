"""Add persistent user blocking for UGC moderation.

Revision ID: 0011_user_blocks
Revises: 0010_marketplace
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0011_user_blocks"
down_revision = "0010_marketplace"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_blocks",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("blocker_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("blocked_user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.ForeignKeyConstraint(
            ["blocker_user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["blocked_user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "blocker_user_id",
            "blocked_user_id",
            name="uq_user_blocks_pair",
        ),
    )
    op.create_index(
        "ix_user_blocks_blocker_user_id",
        "user_blocks",
        ["blocker_user_id"],
    )
    op.create_index(
        "ix_user_blocks_blocked_user_id",
        "user_blocks",
        ["blocked_user_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_user_blocks_blocked_user_id", table_name="user_blocks")
    op.drop_index("ix_user_blocks_blocker_user_id", table_name="user_blocks")
    op.drop_table("user_blocks")
