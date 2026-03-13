# app/routers/device_registry.py
from __future__ import annotations

import json
import logging
from uuid import UUID

from fastapi import (
    APIRouter,
    HTTPException,
    status,
    Depends,
    Path,
    Query,
)
from sqlalchemy import select, func
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_db
from ..models import DeviceRegistry
from ..schemas import DeviceRegistryItem

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/devices",
    tags=["devices"],
)


# ============================================================
# GET /devices
# ============================================================
@router.get(
    "",
    response_model=list[DeviceRegistryItem],
    summary="List registered devices",
    description=(
        "Return a paginated list of devices registered in the telemetry registry.\n\n"
        "This endpoint is intended for administrative or operational use. "
        "IoT devices themselves should use the telemetry endpoints, not this API."
    ),
)
async def list_devices(
    limit: int = Query(
        default=100,
        ge=1,
        le=1000,
        description="Maximum number of devices to return.",
    ),
    offset: int = Query(
        default=0,
        ge=0,
        description="Number of devices to skip before starting to collect the result set.",
    ),
    db: AsyncSession = Depends(get_db),
) -> list[DeviceRegistryItem]:
    """
    List registered devices with pagination.

    The result set is ordered by `created_at` in descending order so that newly
    registered devices appear first. This endpoint is typically used by
    administrative dashboards, monitoring services, or operational tooling.
    """
    logger.debug(
        "Listing devices",
        extra={
            "limit": limit,
            "offset": offset,
        },
    )

    stmt = (
        select(DeviceRegistry)
        .order_by(DeviceRegistry.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    try:
        result = await db.execute(stmt)
        devices = result.scalars().all()
    except SQLAlchemyError as exc:
        logger.exception(
            "Database error while listing devices",
            extra={
                "limit": limit,
                "offset": offset,
            },
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve device list.",
        ) from exc

    logger.debug(
        "Successfully listed devices",
        extra={
            "limit": limit,
            "offset": offset,
            "returned_count": len(devices),
        },
    )
    return devices


# ============================================================
# GET /devices/count
# ============================================================
@router.get(
    "/count",
    summary="Get device registry statistics",
    description=(
        "Return high-level statistics about the device registry. "
        "Currently includes the total number of registered devices."
    ),
)
async def get_device_registry_count(
    db: AsyncSession = Depends(get_db),
) -> dict[str, int]:
    """
    Retrieve summary statistics for the device registry.

    The endpoint used by admin dashboards or monitoring
    services to display high-level system metrics.
    """
    logger.debug("Fetching device registry count")

    stmt = select(func.count()).select_from(DeviceRegistry)

    try:
        result = await db.execute(stmt)
        device_count = result.scalar_one()
    except SQLAlchemyError as exc:
        logger.exception(
            "Database error while fetching device registry count"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve device registry count.",
        ) from exc

    logger.debug(
        "Device registry count fetched successfully",
        extra={"device_count": device_count},
    )

    return {"device_count": device_count}


# ============================================================
# GET /devices/{device_uuid}
# ============================================================
@router.get(
    "/{device_uuid}",
    response_model=DeviceRegistryItem,
    summary="Get a device by UUID",
    description=(
        "Retrieve a single device using its globally unique device UUID. "
        "This UUID is typically the identifier burned into the device firmware.\n\n"
        "This endpoint is intended for administrative or operational use. "
        "IoT devices should authenticate using their UUID and API key via the "
        "telemetry APIs, rather than calling this endpoint directly."
    ),
)
async def get_device_by_uuid(
    device_uuid: UUID = Path(
        ...,
        description="Device UUID assigned to the device and stored in the telemetry registry.",
        examples=["550e8400-e29b-41d4-a716-446655440000"],
    ),
    db: AsyncSession = Depends(get_db),
) -> DeviceRegistryItem:
    """
    Retrieve a device by its UUID.

    This endpoint is typically used by admin tools or internal services
    to inspect or troubleshoot registered devices. It does not expose
    any secret material such as API keys or hashes.
    """
    cache_key = f"device_registry:{device_uuid}"

    logger.debug(
        "Fetching device by UUID",
        extra={"device_uuid": str(device_uuid)},
    )

    # sql statement
    stmt = select(DeviceRegistry).where(
        DeviceRegistry.device_uuid == device_uuid)

    try:
        result = await db.execute(stmt)
        device = result.scalar_one_or_none()
    except SQLAlchemyError as exc:
        logger.exception(
            "Database error while fetching device by UUID",
            extra={"device_uuid": str(device_uuid)},
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve device.",
        ) from exc

    if not device:
        # log warning msg if not found
        logger.warning(
            "Device lookup failed: Not Found",
            extra={"device_uuid": str(device_uuid)}
        )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Device not found."
        )

    logger.debug(
        "Device fetched successfully",
        extra={"device_uuid": str(device_uuid)},
    )
    return device
