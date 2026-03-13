# main.py
from __future__ import annotations

import asyncio
import logging

from .config import get_settings, setup_logging
from .db import async_session_maker
from .models import TelemetryLatestOutbox
from .app_factory import fetch_all_latest, sync_latest_rows_to_redis, sync_telemetry_count

POLL_INTERVAL_SEC = 0.5

setup_logging()
settings = get_settings()
logger = logging.getLogger(__name__)


async def main() -> None:

    while True:
        try:
            async with async_session_maker() as session:
                telemetry_count = await sync_telemetry_count(session)
                logger.debug(f"Sync telemetry count {telemetry_count}.")

                rows = await fetch_all_latest(session)
                await sync_latest_rows_to_redis(session, rows)

        except Exception:
            logger.exception("Worker error")

        await asyncio.sleep(settings.poll_interval)


if __name__ == "__main__":
    print("Starting outbox worker.")
    asyncio.run(main())
