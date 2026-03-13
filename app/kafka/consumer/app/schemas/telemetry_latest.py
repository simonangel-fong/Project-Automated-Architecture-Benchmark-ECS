# app/schemas/telemetry_latest.py
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import Field

from .base import ORMModel


class TelemetryLatestItem(ORMModel):
    """
    Public representation of the latest known position for a device.

    Typical usage:
      - Response model for GET /telemetry/latest/{device_uuid}
      - Response model for internal services querying the latest snapshot
    """

    device_uuid: UUID = Field(
        description="UUID of the device for which this is the latest snapshot.",
        examples=["11111111-1111-1111-1111-111111111111"],
    )

    alias: Optional[str] = Field(
        default=None,
        description="Optional debug alias for the device.",
        examples=["device-001"],
    )

    x_coord: float = Field(
        description="Latest X coordinate value.",
        examples=[1.2345],
    )

    y_coord: float = Field(
        description="Latest Y coordinate value.",
        examples=[6.789],
    )

    system_time_utc: datetime = Field(
        description=(
            "Server-side timestamp (UTC) when this snapshot was last updated. "
            "This is the authoritative time used for ordering and freshness checks."
        ),
        examples=["2025-11-17T12:35:00Z"],
    )

    device_time: datetime = Field(
        description=(
            "Timestamp reported by the device for this latest position. "
            "May differ from system_time_utc due to clock skew or network delay."
        ),
        examples=["2025-11-17T12:34:56Z"],
    )
