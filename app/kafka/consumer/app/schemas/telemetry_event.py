# app/schemas/telemetry_event.py
from uuid import UUID
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field
from .base import ORMModel


class TelemetryCreate(BaseModel):
    """
    Request body schema for creating a telemetry record from a device.
    """

    x_coord: float = Field(
        description="X coordinate value.",
        examples=[1.2345],
    )
    y_coord: float = Field(
        description="Y coordinate value.",
        examples=[6.789],
    )
    device_time: Optional[datetime] = Field(
        default=None,
        description=(
            "Timestamp reported by the device clock (optional). "
            "If provided, it SHOULD be a timezone-aware datetime in UTC. "
            "If omitted, the service will usually set it to the server-side "
            "ingestion time (system_time_utc)."
        ),
        examples=["2025-11-17T12:34:56Z"],
    )


class TelemetryItem(ORMModel):
    """
    A single telemetry event returned by the service.
    """

    device_uuid: UUID = Field(
        description="UUID.",
    )
    x_coord: float = Field(
        description="X coordinate value.",
        examples=[1.2345],
    )
    y_coord: float = Field(
        description="Y coordinate value.",
        examples=[6.789],
    )
    system_time_utc: datetime = Field(
        description=(
            "Server-side timestamp (UTC) when the telemetry record was stored. "
            "This is the authoritative time used for ordering and querying."
        ),
        examples=["2025-11-17T12:35:00Z"],
    )
    device_time: datetime = Field(
        description=(
            "Timestamp reported by the device. May differ from system_time_utc "
            "due to network delay or device clock skew. "
            "In this system it is always present in stored events."
        ),
        examples=["2025-11-17T12:34:56Z"],
    )


class TelemetryCountItem(BaseModel):
    device_uuid: UUID
    total_events: int
