import asyncio

from sqlalchemy import update

from app.db.session import Session
from app.models import ParkingSpace

DEMO_SLUGS = {
    "europagarten",
    "messeost",
    "hbf-sued",
    "bockenheim",
    "westend-hotel",
    "uniklinik",
    "gallus-office",
    "alteoper-hof",
    "hauptwache",
    "nordend",
    "roemer",
    "osthafen",
}


async def archive_legacy_demo_spaces() -> int:
    """Archive only unmistakable legacy seed rows; never touch user inventory."""
    async with Session() as db:
        result = await db.execute(
            update(ParkingSpace)
            .where(
                ParkingSpace.slug.in_(DEMO_SLUGS),
                ParkingSpace.owner_id.is_(None),
                ParkingSpace.exact_address.like("Geschützte fiktive Adresse %"),
            )
            .values(
                status="archived",
                is_verified=False,
                is_instant_bookable=False,
                rating=0,
                review_count=0,
                exact_address="Nicht verfügbar",
                entrance_instructions="Nicht verfügbar",
            )
        )
        await db.commit()
        count = int(result.rowcount or 0)
        print(f"Archived {count} legacy fictional demo parking spaces.")
        return count


if __name__ == "__main__":
    asyncio.run(archive_legacy_demo_spaces())
