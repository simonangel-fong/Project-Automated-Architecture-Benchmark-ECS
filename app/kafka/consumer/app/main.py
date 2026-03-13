from __future__ import annotations

import asyncio
import logging
import signal
from typing import Dict, List

from aiokafka.structs import TopicPartition
from sqlalchemy import insert
from sqlalchemy.exc import SQLAlchemyError

from .mq.kafka_consumer import init_consumer, close_consumer, get_consumer
from .db import async_session_maker
from .models import TelemetryEvent
from .schemas import TelemetryItem
from .config import get_settings


BATCH_SIZE = 1000
FLUSH_INTERVAL_SEC = 1.0
RETRY_BACKOFF_SEC = 1.0

settings = get_settings()
logger = logging.getLogger(__name__)


def to_db_row(item: TelemetryItem) -> dict:
    """Map TelemetryItem -> TelemetryEvent row dict."""
    return {
        "device_uuid": item.device_uuid,
        "x_coord": item.x_coord,
        "y_coord": item.y_coord,
        "device_time": item.device_time,
        "system_time_utc": item.system_time_utc,
    }


async def flush_batch(
    *,
    consumer,
    rows: List[dict],
    first_offsets: Dict[TopicPartition, int],
    last_offsets: Dict[TopicPartition, int],
) -> None:
    """
    1) Insert rows into DB (single transaction)
    2) Commit Kafka offsets only after DB commit
    If DB fails, seek back to first_offsets to retry the same batch.
    """
    if not rows:
        return

    async with async_session_maker() as db:
        try:
            await db.execute(insert(TelemetryEvent).values(rows))
            await db.commit()

            # Commit offsets explicitly (next offset = last_offset + 1)
            commit_map = {tp: last_off + 1 for tp,
                          last_off in last_offsets.items()}
            await consumer.commit(commit_map)

            logger.info(
                "Flushed %d rows, committed offsets: %s",
                len(rows),
                {f"{tp.topic}:{tp.partition}": off for tp,
                    off in commit_map.items()},
            )

        except SQLAlchemyError:
            await db.rollback()
            logger.exception(
                "DB flush failed; offsets not committed. Seeking back to retry batch.")

            # Retry by rewinding consumer position to the start of the batch per partition
            for tp, off in first_offsets.items():
                consumer.seek(tp, off)

            await asyncio.sleep(RETRY_BACKOFF_SEC)


async def main() -> None:
    stop_event = asyncio.Event()

    def request_shutdown() -> None:
        logger.info("Shutdown requested")
        stop_event.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        try:
            loop.add_signal_handler(sig, request_shutdown)
        except NotImplementedError:
            signal.signal(sig, lambda *_: request_shutdown())

    await init_consumer()
    consumer = get_consumer()

    rows: List[dict] = []
    first_offsets: Dict[TopicPartition, int] = {}
    last_offsets: Dict[TopicPartition, int] = {}

    next_flush_at = loop.time() + FLUSH_INTERVAL_SEC

    try:
        while not stop_event.is_set():
            # getmany returns: {TopicPartition: [ConsumerRecord, ...], ...}
            records_map = await consumer.getmany(timeout_ms=200, max_records=200)

            if records_map:
                for tp, records in records_map.items():
                    for msg in records:
                        payload = msg.value  # already dict via value_deserializer

                        try:
                            item = TelemetryItem.model_validate(payload)
                        except Exception:
                            logger.exception(
                                "Invalid TelemetryItem payload; skipping",
                                extra={
                                    "topic": msg.topic, "partition": msg.partition, "offset": msg.offset},
                            )
                            # Commit past this bad message so you don't get stuck.
                            # Note: commit expects next offset.
                            await consumer.commit({TopicPartition(msg.topic, msg.partition): msg.offset + 1})
                            continue

                        rows.append(to_db_row(item))

                        msg_tp = TopicPartition(msg.topic, msg.partition)
                        first_offsets.setdefault(msg_tp, msg.offset)
                        last_offsets[msg_tp] = msg.offset

            now = loop.time()
            should_flush = (len(rows) >= settings.batch_size) or (
                rows and now >= next_flush_at)

            if should_flush:
                await flush_batch(
                    consumer=consumer,
                    rows=rows,
                    first_offsets=first_offsets,
                    last_offsets=last_offsets,
                )
                rows.clear()
                first_offsets.clear()
                last_offsets.clear()
                next_flush_at = now + FLUSH_INTERVAL_SEC
        # Final flush on shutdown
        if rows:
            await flush_batch(
                consumer=consumer,
                rows=rows,
                first_offsets=first_offsets,
                last_offsets=last_offsets,
            )

    finally:
        await close_consumer()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(main())
