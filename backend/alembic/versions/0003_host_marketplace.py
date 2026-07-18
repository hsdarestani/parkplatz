"""Add parking-space ownership for the host marketplace."""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy.engine.reflection import Inspector

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def _inspector() -> Inspector:
    return sa.inspect(op.get_bind())


def upgrade() -> None:
    columns = {column["name"] for column in _inspector().get_columns("parking_spaces")}
    if "owner_id" not in columns:
        op.add_column(
            "parking_spaces",
            sa.Column(
                "owner_id",
                postgresql.UUID(as_uuid=True),
                nullable=True,
            ),
        )

    foreign_keys = _inspector().get_foreign_keys("parking_spaces")
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

    indexes = _inspector().get_indexes("parking_spaces")
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
    for index in _inspector().get_indexes("parking_spaces"):
        if index.get("column_names") == ["owner_id"] and index.get("name"):
            op.drop_index(index["name"], table_name="parking_spaces")

    for foreign_key in _inspector().get_foreign_keys("parking_spaces"):
        if (
            foreign_key.get("constrained_columns") == ["owner_id"]
            and foreign_key.get("name")
        ):
            op.drop_constraint(
                foreign_key["name"],
                "parking_spaces",
                type_="foreignkey",
            )

    columns = {column["name"] for column in _inspector().get_columns("parking_spaces")}
    if "owner_id" in columns:
        op.drop_column("parking_spaces", "owner_id")
