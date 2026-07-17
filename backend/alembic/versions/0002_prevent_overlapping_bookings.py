"""Prevent overlapping active bookings at database level."""

from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS btree_gist")
    op.execute(
        """ALTER TABLE bookings ADD CONSTRAINT bookings_no_active_overlap
        EXCLUDE USING gist (
          parking_space_id WITH =,
          tstzrange(start_at, end_at, '[)') WITH &&
        ) WHERE (status IN ('pending', 'confirmed'))
        """
    )


def downgrade() -> None:
    op.execute("ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_no_active_overlap")
