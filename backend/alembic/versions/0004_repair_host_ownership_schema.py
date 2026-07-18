"""Repair host ownership schema on databases upgraded through mutable revision 0001.

Revision ID: 0004
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy.engine.reflection import Inspector

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def _inspector() -> Inspector:
    return sa.inspect(op.get_bind())


def upgrade() -> None:
    inspector = _inspector()
    columns = {column["name"] for column in inspector.get_columns("parking_spaces")}
    if "owner_id" not in columns:
        op.add_column(
            "parking_spaces",
            sa.Column(
                "owner_id",
                postgresql.UUID(as_uuid=True),
                nullable=True,
            ),
        )

    inspector = _inspector()
    foreign_keys = inspector.get_foreign_keys("parking_spaces")
    has_owner_foreign_key = any(
        foreign_key.get("constrained_columns") == ["owner_id"]
        and foreign_key.get("referred_table") == "users"
        for foreign_key in foreign_keys
    )
    if not has_owner_foreign_key:
        op.create_foreign_key(
            "fk_parking_spaces_owner_id_users",
            "parking_spaces",
            "users",
            ["owner_id"],
            ["id"],
            ondelete="SET NULL",
        )

    inspector = _inspector()
    indexes = inspector.get_indexes("parking_spaces")
    has_owner_index = any(
        index.get("column_names") == ["owner_id"] for index in indexes
    )
    if not has_owner_index:
        op.create_index(
            "ix_parking_spaces_owner_id",
            "parking_spaces",
            ["owner_id"],
            unique=False,
        )


def downgrade() -> None:
    # This is a repair migration. Dropping a valid production ownership column
    # would be destructive, so downgrade intentionally leaves the schema intact.
    pass
