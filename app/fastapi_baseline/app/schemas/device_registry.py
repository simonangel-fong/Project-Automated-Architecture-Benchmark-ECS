# app/schemas/device.py
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import Field

from .base import ORMModel


class DeviceRegistryItem(ORMModel):
    """
    Public representation of a tracking-enabled device in the telemetry service.
    """

    device_uuid: UUID = Field(
        description="Public-facing UUID used by the device and for authentication.",
    )

    alias: Optional[str] = Field(
        default=None,
        description="Optional debug alias for the device (not used for auth).",
    )

    created_at: datetime = Field(
        description="Timestamp when the device was added to the telemetry registry (UTC).",
    )

    updated_at: datetime = Field(
        description="Timestamp when this registry entry was last updated (UTC).",
    )
