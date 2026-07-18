"""Add optional schedule-specific pricing for host availability.

Revision ID: 0005
"""

from alembic import op
import sqlalchemy as sa

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    columns = {
        column["name"]
        for column in inspector.get_columns("availability_rules")
    }
    if "price_override_cents" not in columns:
        op.add_column(
            "availability_rules",
            sa.Column("price_override_cents", sa.Integer(), nullable=True),
        )


def downgrade() -> None:
    inspector = sa.inspect(op.get_bind())
    columns = {
        column["name"]
        for column in inspector.get_columns("availability_rules")
    }
    if "price_override_cents" in columns:
        op.drop_column("availability_rules", "price_override_cents")
