# routers/telemetry.py
from __future__ import annotations

import hashlib
import hmac
import json
import logging
from datetime import datetime, timedelta, timezone
from uuid import UUID

from fastapi import (
    APIRouter,
    Body,
    Depends,
    Header,
    HTTPException,
    Path,
    Query,
    status,
)

from sqlalchemy import select, func
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_db, redis_client
from ..models import DeviceRegistry, TelemetryEvent, TelemetryLatest
from ..schemas import (
    TelemetryCreate,
    TelemetryItem,
    TelemetryCountItem,
    TelemetryLatestItem,
)

from ..mq import get_producer
from ..config import get_settings

from aiokafka import AIOKafkaProducer
from aiokafka.errors import KafkaError

settings = get_settings()

router = APIRouter(
    prefix="/telemetry",
    tags=["telemetry"],
    # Optional: hide nulls in responses if you want a cleaner payload:
    # response_model_exclude_none=True,
)

logger = logging.getLogger(__name__)

DEFAULT_LATEST_SECONDS = 1800       # 30 minutes
MAX_LATEST_SECONDS = 24 * 3600      # 24 hours

TELEMETRY_CACHE_TTL_SECONDS = 3600    # Short TTL to limit staleness


# ============================================================
# Helper functions
# ============================================================
def verify_api_key(api_key: str, stored_hash: str | None) -> bool:
    """
    Verify a plain-text API key against a stored SHA-256 hex digest.
    """
    if not stored_hash:
        return False

    stored_hash = stored_hash.strip().lower()
    candidate_hash = hashlib.sha256(api_key.encode("utf-8")).hexdigest()
    return hmac.compare_digest(candidate_hash, stored_hash)


def normalize_time_window(
    start_time: datetime | None,
    end_time: datetime | None,
    latest_seconds: int,
) -> tuple[datetime, datetime]:
    """
    Normalize the requested time window into a concrete [start_time, end_time] in UTC.

    Rules:
    - If either start_time or end_time is provided:
        * end_time missing  -> defaults to now() in UTC.
        * start_time missing -> defaults to end_time - MAX_LATEST_SECONDS.
      In this case, latest_seconds is ignored.
    - If neither is provided:
        * Use [now() - latest_seconds, now()] in UTC.
    - All datetimes are converted to timezone-aware UTC.
    - If start_time is after end_time, an HTTP 400 is raised.
    """
    now_utc = datetime.now(timezone.utc)

    if start_time or end_time:
        # Normalize end_time
        if end_time is None:
            end_time = now_utc
        elif end_time.tzinfo is None:
            end_time = end_time.replace(tzinfo=timezone.utc)
        else:
            end_time = end_time.astimezone(timezone.utc)

        # Normalize start_time with bounded lookback
        if start_time is None:
            start_time = end_time - timedelta(seconds=MAX_LATEST_SECONDS)
        elif start_time.tzinfo is None:
            start_time = start_time.replace(tzinfo=timezone.utc)
        else:
            start_time = start_time.astimezone(timezone.utc)
    else:
        end_time = now_utc
        start_time = end_time - timedelta(seconds=latest_seconds)

    if start_time > end_time:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_time must be before end_time.",
        )

    return start_time, end_time


async def get_authenticated_device(
    device_uuid: UUID = Path(
        ...,
        description="Device UUID burned into firmware and registered in the telemetry registry.",
    ),
    api_key: str = Header(
        alias="X-API-Key",
        description="Plain-text API key issued to this device.",
    ),
    db: AsyncSession = Depends(get_db),
) -> DeviceRegistry:
    """
    Authenticate a device using its UUID and API key.

    Steps:
    1. Look up the device by device_uuid in DeviceRegistry.
    2. Verify the provided API key against the stored hash.
    3. Return the DeviceRegistry ORM instance on success.

    Errors:
    - 404 if the device is not found in the registry.
    - 401 if the API key is invalid.
    """
    logger.debug(
        "Authenticating device",
        extra={"device_uuid": str(device_uuid)},
    )

    device_uuid_str = str(device_uuid)
    cache_key = f"device:registry:{device_uuid_str}"
    device = None

    # try redis cache
    try:
        cached = await redis_client.get(cache_key)
        if cached:
            logger.debug(
                "Device registry cache hit",
                extra={"device_uuid": device_uuid_str, "cache_key": cache_key},
            )
            try:
                device_data = json.loads(cached)
                device = DeviceRegistry(
                    device_uuid=UUID(device_data["device_uuid"]),
                    api_key_hash=device_data["api_key_hash"],
                )
                logger.debug(
                    "Device registry deserialized from cache",
                    extra={"device_uuid": device_uuid_str},
                )
            except (json.JSONDecodeError, KeyError, ValueError) as exc:
                logger.warning(
                    "Failed to deserialize device registry cache, falling back to DB",
                    extra={"device_uuid": device_uuid_str,
                           "cache_key": cache_key, "error": str(exc)},
                )
                device = None
    except Exception as exc:
        logger.warning(
            "Redis cache lookup failed for device registry",
            extra={"device_uuid": device_uuid_str,
                   "cache_key": cache_key, "error": str(exc)},
        )
        device = None

    # query db
    if device is None:
        logger.debug(
            "Device registry cache miss, querying database",
            extra={"device_uuid": device_uuid_str},
        )

        stmt = select(DeviceRegistry).where(
            DeviceRegistry.device_uuid == device_uuid
        )

        try:
            result = await db.execute(stmt)
            device = result.scalar_one_or_none()
        except SQLAlchemyError as exc:
            logger.exception(
                "Database error while authenticating device",
                extra={"device_uuid": device_uuid_str},
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to authenticate device.",
            ) from exc

        if device is None:
            logger.warning(
                "Device not found in registry",
                extra={"device_uuid": device_uuid_str},
            )
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Device not found.",
            )

        # Cache in Redis
        try:
            device_data = {
                "device_uuid": str(device.device_uuid),
                "api_key_hash": device.api_key_hash,
            }
            await redis_client.set(
                cache_key,
                json.dumps(device_data),
                ex=TELEMETRY_CACHE_TTL_SECONDS,  # Cache for 1 hour; adjust as needed
            )
            logger.debug(
                "Device registry cached",
                extra={
                    "device_uuid": device_uuid_str,
                    "cache_key": cache_key,
                    "ttl": TELEMETRY_CACHE_TTL_SECONDS,
                },
            )
        except Exception as exc:
            logger.warning(
                "Failed to write device registry to Redis cache",
                extra={"device_uuid": device_uuid_str, "cache_key": cache_key},
                exc_info=exc,
            )

    # Verify API key
    if not verify_api_key(api_key=api_key, stored_hash=device.api_key_hash):
        logger.warning(
            "Invalid API key for device",
            extra={"device_uuid": device_uuid_str},
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key.",
        )

    logger.debug(
        "Device authenticated successfully",
        extra={"device_uuid": device_uuid_str},
    )

    return device


# ============================================================
# GET /telemetry/count
# ============================================================
@router.get(
    "/count",
    summary="Get telemetry registry statistics",
    description="Return high-level statistics about telemetry storage.",
)
async def get_telemetry_count() -> dict[str, int]:
    """
    Return telemetry count from Redis (read model).
    """

    logger.debug("Fetching telemetry count from Redis")

    try:
        value = await redis_client.get("telemetry:count")

        if value is None:
            # If Redis key missing: worker may not have synced yet
            logger.warning("Redis telemetry:count key not found")
            return {"telemetry_count": 0}

        telemetry_count = int(value)

    except Exception:
        logger.exception("Redis error while fetching telemetry count")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve telemetry count from cache.",
        )

    logger.debug(
        "Telemetry count fetched successfully from Redis",
        extra={"telemetry_count": telemetry_count},
    )

    return {"telemetry_count": telemetry_count}


# # ============================================================
# # GET /telemetry/{device_uuid}
# # ============================================================
# @router.get(
#     "/{device_uuid}",
#     summary="List telemetry for a device",
#     description=(
#         "Return a list of telemetry events for a specific device, identified by its UUID. "
#         "The device must authenticate using the `X-API-Key` header. The time window can "
#         "be specified using `start_time` and `end_time`, or by using `latest_seconds` "
#         "to request data from a recent lookback period.\n\n"
#         "Results are ordered by `system_time_utc` in descending order (most recent first)."
#     ),
#     response_model=list[TelemetryItem],
# )
# async def list_telemetry_for_device(
#     device: DeviceRegistry = Depends(get_authenticated_device),
#     start_time: datetime | None = Query(
#         default=None,
#         description=(
#             "Start of the time range (UTC). If provided, `latest_seconds` is ignored. "
#             "If omitted while `end_time` is provided, the server will bound the lookback "
#             f"window to at most {MAX_LATEST_SECONDS} seconds."
#         ),
#     ),
#     end_time: datetime | None = Query(
#         default=None,
#         description=(
#             "End of the time range (UTC). If omitted but `start_time` is provided, "
#             "defaults to the current server time."
#         ),
#     ),
#     latest_seconds: int = Query(
#         default=DEFAULT_LATEST_SECONDS,
#         ge=1,
#         le=MAX_LATEST_SECONDS,
#         description=(
#             "Lookback window in seconds when `start_time` and `end_time` are not provided. "
#             "The server returns telemetry in the range [now() - latest_seconds, now()]."
#         ),
#     ),
#     limit: int = Query(
#         default=100,
#         ge=1,
#         le=5000,
#         description="Maximum number of telemetry records to return.",
#     ),
#     db: AsyncSession = Depends(get_db),
# ) -> list[TelemetryItem]:
#     """
#     Device-facing telemetry listing endpoint.

#     The device is authenticated via its UUID (path) and API key (header).
#     Only telemetry for the authenticated device is returned.
#     """
#     # Normalize time window
#     start_time, end_time = normalize_time_window(
#         start_time=start_time,
#         end_time=end_time,
#         latest_seconds=latest_seconds,
#     )

#     logger.debug(
#         "Listing telemetry for device",
#         extra={
#             "device_uuid": str(device.device_uuid),
#             "start_time": start_time.isoformat(),
#             "end_time": end_time.isoformat(),
#             "limit": limit,
#         },
#     )

#     cache_key = (
#         f"telemetry:{device.device_uuid}:"
#         f"{int(start_time.timestamp())}:"
#         f"{int(end_time.timestamp())}:"
#         f"{limit}"
#     )

#     # Try Redis cache
#     try:
#         cached = await redis_client.get(cache_key)
#     except Exception:
#         cached = None

#     if cached:
#         logger.debug(
#             "Telemetry cache hit",
#             extra={"device_uuid": str(
#                 device.device_uuid), "cache_key": cache_key},
#         )
#         try:
#             payload = json.loads(cached)
#             items = [TelemetryItem.model_validate(obj) for obj in payload]
#             return items
#         except Exception:
#             # If cache is corrupted or incompatible, ignore and fall back to DB
#             logger.warning(
#                 "Failed to deserialize telemetry cache payload, falling back to DB",
#                 extra={"device_uuid": str(
#                     device.device_uuid), "cache_key": cache_key},
#             )

#     # Cache miss: query PostgreSQL
#     stmt = (
#         select(TelemetryEvent)
#         .where(
#             TelemetryEvent.device_uuid == device.device_uuid,
#             TelemetryEvent.system_time_utc >= start_time,
#             TelemetryEvent.system_time_utc <= end_time,
#         )
#         .order_by(TelemetryEvent.system_time_utc.desc())
#         .limit(limit)
#     )

#     try:
#         result = await db.execute(stmt)
#         rows = result.scalars().all()
#     except SQLAlchemyError as exc:
#         logger.exception(
#             "Database error while listing telemetry",
#             extra={"device_uuid": str(device.device_uuid)},
#         )
#         raise HTTPException(
#             status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
#             detail="Failed to retrieve telemetry.",
#         ) from exc

#     # Convert ORM rows -> DTOs
#     items: list[TelemetryItem] = [
#         TelemetryItem.model_validate(row) for row in rows
#     ]

#     logger.debug(
#         "Telemetry listing succeeded",
#         extra={
#             "device_uuid": str(device.device_uuid),
#             "returned_count": len(items),
#         },
#     )

#     # Store in Redis cache
#     try:
#         await redis_client.set(
#             cache_key,
#             json.dumps([item.model_dump(mode="json") for item in items]),
#             ex=TELEMETRY_CACHE_TTL_SECONDS,
#         )
#         logger.debug(
#             "Telemetry cached",
#             extra={
#                 "device_uuid": str(device.device_uuid),
#                 "cache_key": cache_key,
#                 "ttl": TELEMETRY_CACHE_TTL_SECONDS,
#             },
#         )
#     except Exception:
#         logger.warning(
#             "Failed to write telemetry to Redis cache",
#             extra={"device_uuid": str(
#                 device.device_uuid), "cache_key": cache_key},
#         )

#     return items


# ============================================================
# POST /telemetry/{device_uuid}
# ============================================================
@router.post(
    "/{device_uuid}",
    summary="Ingest telemetry for a device",
    response_model=TelemetryItem,
    status_code=status.HTTP_201_CREATED,
)
async def create_telemetry_for_device(
    device: DeviceRegistry = Depends(get_authenticated_device),
    payload: TelemetryCreate = Body(
        description="Telemetry payload containing coordinates and optional device timestamp.",
    ),
    producer: AIOKafkaProducer = Depends(get_producer),
) -> TelemetryItem:
    now_utc = datetime.now(timezone.utc)
    device_time = payload.device_time or now_utc

    item = TelemetryItem(
        device_uuid=device.device_uuid,
        x_coord=payload.x_coord,
        y_coord=payload.y_coord,
        device_time=device_time,
        system_time_utc=now_utc,
    )

    topic = settings.kafka.topic
    key = str(device.device_uuid).encode("utf-8")
    value = item.model_dump(mode="json")

    # ---- Kafka publish ----
    try:
        md = await producer.send_and_wait(topic, value=value, key=key)
        logger.info(
            "Telemetry enqueued",
            extra={
                "device_uuid": str(device.device_uuid),
                "topic": topic,
                "partition": md.partition,
                "offset": md.offset,
            },
        )
    except KafkaError as exc:
        logger.exception(
            "Kafka publish failed",
            extra={"device_uuid": str(device.device_uuid), "topic": topic},
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Failed to enqueue telemetry event.",
        ) from exc
    except Exception as exc:
        logger.exception(
            "Unexpected error while publishing to Kafka",
            extra={"device_uuid": str(device.device_uuid), "topic": topic},
        )
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Failed to enqueue telemetry event.",
        ) from exc

    return item


# ============================================================
# GET /telemetry/latest/{device_uuid}
# ============================================================
@router.get(
    "/latest/{device_uuid}",
    summary="Get latest telemetry snapshot for a device",
    description=(
        "Return the latest known position for a specific device, identified by its UUID. "
        "The device must authenticate using the `X-API-Key` header.\n\n"
        "This endpoint reads from Redis only (read model)."
    ),
    response_model=TelemetryLatestItem,
)
async def get_latest_telemetry_for_device(
    device: DeviceRegistry = Depends(get_authenticated_device),
) -> TelemetryLatestItem:
    """
    Return the latest telemetry snapshot for the authenticated device from Redis only.

    If the Redis key is missing (worker not synced yet), returns 404.
    """
    device_uuid_str = str(device.device_uuid)
    cache_key = f"telemetry:latest:{device_uuid_str}"

    logger.debug(
        "Fetching latest telemetry snapshot from Redis",
        extra={"device_uuid": device_uuid_str, "cache_key": cache_key},
    )

    try:
        cached = await redis_client.get(cache_key)
    except Exception as exc:
        logger.exception(
            "Redis error while fetching latest telemetry",
            extra={"device_uuid": device_uuid_str, "cache_key": cache_key},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve latest telemetry from cache.",
        ) from exc

    if not cached:
        logger.warning(
            "No latest telemetry found in Redis for device",
            extra={"device_uuid": device_uuid_str, "cache_key": cache_key},
        )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No telemetry available for this device.",
        )

    try:
        data = json.loads(cached)
        item = TelemetryLatestItem.model_validate(data)
    except Exception as exc:
        # Redis contains corrupted/unexpected payload
        logger.exception(
            "Failed to deserialize latest telemetry from Redis",
            extra={"device_uuid": device_uuid_str, "cache_key": cache_key},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Telemetry cache payload is invalid.",
        ) from exc

    logger.debug(
        "Latest telemetry snapshot fetched successfully from Redis",
        extra={
            "device_uuid": device_uuid_str,
            "system_time_utc": item.system_time_utc.isoformat(),
        },
    )

    return item


# # ============================================================
# # GET /telemetry/count/{device_uuid}
# # ============================================================
# @router.get(
#     "/count/{device_uuid}",
#     summary="Get total telemetry event count for a device (debug)",
#     description=(
#         "Return the total number of telemetry events stored for the given device UUID. "
#         "This endpoint is intended for debugging and operational verification. "
#         "The device must authenticate using the `X-API-Key` header."
#     ),
#     response_model=TelemetryCountItem,
# )
# async def get_telemetry_count_for_device(
#     device: DeviceRegistry = Depends(get_authenticated_device),
#     db: AsyncSession = Depends(get_db),
# ) -> TelemetryCountItem:
#     """
#     Return the total telemetry event count for the authenticated device.

#     This is a debug/operational endpoint and is not meant for production-facing
#     client use (e.g. mobile apps). It simply performs a COUNT(*) on telemetry_event
#     filtered by device_uuid.
#     """
#     logger.debug(
#         "Fetching telemetry event count for device",
#         extra={"device_uuid": str(device.device_uuid)},
#     )

#     stmt = (
#         select(func.count())
#         .select_from(TelemetryEvent)
#         .where(TelemetryEvent.device_uuid == device.device_uuid)
#     )

#     try:
#         result = await db.execute(stmt)
#         total_events = result.scalar_one()
#     except SQLAlchemyError as exc:
#         logger.exception(
#             "Database error while counting telemetry events",
#             extra={"device_uuid": str(device.device_uuid)},
#         )
#         raise HTTPException(
#             status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
#             detail="Failed to retrieve telemetry count.",
#         ) from exc

#     logger.debug(
#         "Telemetry event count fetched successfully",
#         extra={
#             "device_uuid": str(device.device_uuid),
#             "total_events": total_events,
#         },
#     )

#     return TelemetryCountItem(
#         device_uuid=device.device_uuid,
#         total_events=total_events,
#     )
