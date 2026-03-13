# app/models/telemetry_latest.py
from __future__ import annotations

from datetime import datetime
from typing import Optional
from uuid import UUID as UUID_Type

from sqlalchemy import DateTime, Float, ForeignKey, Index, String
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from .base import Base

# from .device_registry import DeviceRegistry


class TelemetryLatest(Base):
    """
    Latest known position per device.
    """

    __tablename__ = "telemetry_latest"
    __table_args__ = (
        Index("idx_telemetry_latest_system_time_utc", "system_time_utc"),
        {"schema": "app"},
    )

    device_uuid: Mapped[UUID_Type] = mapped_column(
        PG_UUID(as_uuid=True),
        ForeignKey(
            "app.device_registry.device_uuid",
            ondelete="CASCADE",
        ),
        primary_key=True,
        doc=(
            "Device UUID (primary key). "
            "FK to app.device_registry(device_uuid) with ON DELETE CASCADE."
        ),
    )

    alias: Mapped[Optional[str]] = mapped_column(
        String(64),
        nullable=True,
        doc="Optional debug alias for the device.",
    )

    x_coord: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        doc="Latest X coordinate.",
    )

    y_coord: Mapped[float] = mapped_column(
        Float,
        nullable=False,
        doc="Latest Y coordinate.",
    )

    device_time: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        doc="Device-reported timestamp of the latest telemetry event.",
    )

    system_time_utc: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        doc="Server-side UTC time when this snapshot was last updated.",
    )

    # # One-to-one relationship to DeviceRegistry.
    # device: Mapped[Optional["DeviceRegistry"]] = relationship(
    #     "DeviceRegistry",
    #     back_populates="latest_telemetry",
    #     lazy="joined",
    #     doc="Associated device registry entry for this latest snapshot.",
    # )

    def __repr__(self) -> str:
        return (
            f"<TelemetryLatest device_uuid={self.device_uuid} "
            f"alias={self.alias!r} x={self.x_coord} y={self.y_coord} "
            f"device_time={self.device_time} system_time_utc={self.system_time_utc}>"
        )
