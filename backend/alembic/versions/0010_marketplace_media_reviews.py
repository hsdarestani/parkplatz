"""Add and reconcile profile media, photo review metadata, and reviews.

Revision ID: 0010_marketplace
Revises: 0010

This migration intentionally follows the original 0010 revision. An earlier
release accidentally shipped this file with the same revision ID as another
0010 migration. Existing databases can therefore be stamped at 0010 while
missing some or all of the schema below. Every operation is guarded so the
migration safely repairs those databases and also succeeds where the old file
was already applied.
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0010_marketplace"
down_revision = "0010"
branch_labels = None
depends_on = None


def _column_names(inspector: sa.Inspector, table_name: str) -> set[str]:
    return {column["name"] for column in inspector.get_columns(table_name)}


def _index_names(inspector: sa.Inspector, table_name: str) -> set[str]:
    return {index["name"] for index in inspector.get_indexes(table_name)}


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    table_names = set(inspector.get_table_names())

    user_columns = _column_names(inspector, "users")
    if "profile_image_url" not in user_columns:
        op.add_column(
            "users",
            sa.Column("profile_image_url", sa.String(length=2048), nullable=True),
        )

    image_columns = _column_names(inspector, "parking_space_images")
    if "approval_status" not in image_columns:
        op.add_column(
            "parking_space_images",
            sa.Column(
                "approval_status",
                sa.String(length=24),
                nullable=False,
                server_default="pending",
            ),
        )
    if "ai_reason" not in image_columns:
        op.add_column(
            "parking_space_images",
            sa.Column("ai_reason", sa.Text(), nullable=True),
        )
    if "created_at" not in image_columns:
        op.add_column(
            "parking_space_images",
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.text("now()"),
            ),
        )

    if "reviews" not in table_names:
        op.create_table(
            "reviews",
            sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("booking_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("parking_space_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("author_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("rating", sa.Integer(), nullable=False),
            sa.Column("comment", sa.Text(), nullable=False),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                nullable=False,
                server_default=sa.text("now()"),
            ),
            sa.CheckConstraint("rating >= 1 AND rating <= 5", name="ck_reviews_rating"),
            sa.ForeignKeyConstraint(["author_id"], ["users.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["booking_id"], ["bookings.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(
                ["parking_space_id"],
                ["parking_spaces.id"],
                ondelete="CASCADE",
            ),
            sa.PrimaryKeyConstraint("id"),
            sa.UniqueConstraint("booking_id", name="uq_reviews_booking_id"),
        )
        op.create_index("ix_reviews_author_id", "reviews", ["author_id"])
        op.create_index("ix_reviews_booking_id", "reviews", ["booking_id"])
        op.create_index("ix_reviews_parking_space_id", "reviews", ["parking_space_id"])
    else:
        # Some installations already executed this schema under the accidental
        # duplicate 0010 ID. Only add any indexes that are actually missing.
        inspector = sa.inspect(bind)
        review_indexes = _index_names(inspector, "reviews")
        if "ix_reviews_author_id" not in review_indexes:
            op.create_index("ix_reviews_author_id", "reviews", ["author_id"])
        if "ix_reviews_booking_id" not in review_indexes:
            op.create_index("ix_reviews_booking_id", "reviews", ["booking_id"])
        if "ix_reviews_parking_space_id" not in review_indexes:
            op.create_index("ix_reviews_parking_space_id", "reviews", ["parking_space_id"])


def downgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    table_names = set(inspector.get_table_names())

    if "reviews" in table_names:
        review_indexes = _index_names(inspector, "reviews")
        if "ix_reviews_parking_space_id" in review_indexes:
            op.drop_index("ix_reviews_parking_space_id", table_name="reviews")
        if "ix_reviews_booking_id" in review_indexes:
            op.drop_index("ix_reviews_booking_id", table_name="reviews")
        if "ix_reviews_author_id" in review_indexes:
            op.drop_index("ix_reviews_author_id", table_name="reviews")
        op.drop_table("reviews")

    image_columns = _column_names(sa.inspect(bind), "parking_space_images")
    if "created_at" in image_columns:
        op.drop_column("parking_space_images", "created_at")
    if "ai_reason" in image_columns:
        op.drop_column("parking_space_images", "ai_reason")
    if "approval_status" in image_columns:
        op.drop_column("parking_space_images", "approval_status")

    user_columns = _column_names(sa.inspect(bind), "users")
    if "profile_image_url" in user_columns:
        op.drop_column("users", "profile_image_url")
