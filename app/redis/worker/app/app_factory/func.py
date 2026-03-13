# app_factory/func.py
from __future__ import annotations

import json
import logging
from typing import Sequence, Iterable

from sqlalchemy import select, update, func
from sqlalchemy.ext.asyncio import AsyncSession

from ..models import TelemetryLatest, TelemetryEvent
from ..db.redis import redis_client

logger = logging.getLogger(__name__)

BATCH_SIZE = 1000
TELEMETRY_COUNT_KEY = "telemetry:count"
TELEMETRY_LATEST = "telemetry:latest"
LUA_SET_IF_NEWER = """
local data_key = KEYS[1]
local ver_key  = KEYS[2]
local incoming = tonumber(ARGV[1])
local current  = tonumber(redis.call('GET', ver_key) or '0')

if incoming > current then
  redis.call('SET', data_key, ARGV[2])
  redis.call('SET', ver_key, ARGV[1])
  return 1
end
return 0
"""

_lua_sha: str | None = None


async def _get_lua_sha() -> str:
    global _lua_sha
    if _lua_sha is None:
        _lua_sha = await redis_client.script_load(LUA_SET_IF_NEWER)
    return _lua_sha


def _redis_keys(device_uuid: str) -> tuple[str, str]:
    data_key = f"{TELEMETRY_LATEST}:{device_uuid}"
    ver_key = f"{data_key}:ver"
    return data_key, ver_key


async def fetch_all_latest(session: AsyncSession) -> Sequence[TelemetryLatest]:
    stmt = select(TelemetryLatest)
    result = await session.execute(stmt)
    return result.scalars().all()


def _row_to_payload(row: TelemetryLatest) -> dict:
    return {
        "device_uuid": str(row.device_uuid),
        "alias": row.alias,
        "x_coord": row.x_coord,
        "y_coord": row.y_coord,
        "device_time": row.device_time.isoformat(),
        "system_time_utc": row.system_time_utc.isoformat(),
    }


async def sync_latest_rows_to_redis(session: AsyncSession, rows: Iterable[TelemetryLatest]) -> int:
    """
    Full refresh: writes every device latest row to Redis.
    Version guard ensures Redis never regresses.

    Returns:
        Number of rows that actually updated Redis (Lua returned 1).
    """
    sha = await _get_lua_sha()
    pipe = redis_client.pipeline(transaction=False)

    # Queue all Lua calls in a pipeline
    for r in rows:
        device_uuid_str = str(r.device_uuid)
        data_key, ver_key = _redis_keys(device_uuid_str)
        version = int(r.system_time_utc.timestamp() * 1000)
        payload_json = json.dumps(_row_to_payload(
            r), separators=(",", ":"), default=str)

        logger.debug(f"{payload_json}")

        pipe.evalsha(sha, 2, data_key, ver_key, str(version), payload_json)

    results = await pipe.execute()

    updated_count = sum(1 for x in results if int(x) == 1)
    logger.debug("Redis sync completed. updated=%d total=%d",
                 updated_count, len(results))
    return updated_count


async def sync_telemetry_count(session: AsyncSession) -> int:
    """
    Read total telemetry event count from Postgres and write it to Redis.

    Returns:
        The telemetry_count written to Redis.
    """
    stmt = select(func.count()).select_from(TelemetryEvent)
    result = await session.execute(stmt)
    telemetry_count = int(result.scalar_one())

    # Store as string (Redis stores strings); easy to INCR/GET later too
    await redis_client.set(TELEMETRY_COUNT_KEY, str(telemetry_count))

    logger.debug("Synced telemetry count to Redis: %s=%d",
                 TELEMETRY_COUNT_KEY, telemetry_count)
    return telemetry_count
