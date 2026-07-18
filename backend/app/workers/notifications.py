import asyncio
import os

from app.db.session import Session
from app.services.notifications import deliver_queued


async def run() -> None:
    poll_seconds = max(int(os.getenv("NOTIFICATION_POLL_SECONDS", "15")), 5)
    while True:
        async with Session() as db:
            await deliver_queued(db)
        await asyncio.sleep(poll_seconds)


if __name__ == "__main__":
    asyncio.run(run())
