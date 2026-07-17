"""Add parking-space ownership for the host marketplace."""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "parking_spaces",
        sa.Column(
            "owner_id",
            postgresql.UUID(as_uuid=True),
            nullable=True,
        ),
    )
    op.create_foreign_key(
        "fk_parking_spaces_owner_id_users",
        "parking_spaces",
        "users",
        ["owner_id"],
        ["id"],
        ondelete="SET NULL",
    )
    op.create_index(
        "ix_parking_spaces_owner_id",
        "parking_spaces",
        ["owner_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_parking_spaces_owner_id", table_name="parking_spaces")
    op.drop_constraint(
        "fk_parking_spaces_owner_id_users",
        "parking_spaces",
        type_="foreignkey",
    )
    op.drop_column("parking_spaces", "owner_id")
