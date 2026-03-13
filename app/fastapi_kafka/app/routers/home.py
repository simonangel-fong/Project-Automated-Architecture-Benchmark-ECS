# router/home.py
import os
from fastapi import APIRouter, Depends

from ..config.setting import get_settings

# ====================
# Root endpoint
# ====================

router = APIRouter(prefix="", tags=["home"])
settings = get_settings()

HOSTNAME = os.getenv("HOSTNAME", "my_host")


@router.get(
    "/",
    tags=["root"],
    summary="Service status",
    description=(
        "Return basic information about the Device Management API service. "
    ),
)
async def home() -> dict:
    """
    Return basic service metadata and status.
    """
    response: dict = {
        "project": settings.project,
        "status": "ok",
        "environment": settings.env,
        "debug": settings.debug,
        "docs": {
            "openapi": "/openapi.json",
            "swagger_ui": "/docs",
            "redoc": "/redoc",
        },
        "stats": {
            "device_count": "/devices/count",
            "telemetry_count": "/telemetry/count",
        }
    }

    if settings.debug:
        response["fastapi"] = {
            "fastapi_host": HOSTNAME,
        }

        response["cors"] = settings.cors_list

        response["tune"] = {
            "pool_size": settings.pool_size,
            "max_overflow": settings.max_overflow,
        }

        response["postgres"] = {
            "host": settings.postgres.host,
            "port": settings.postgres.port,
            "db_name": settings.postgres.db,
            "user": settings.postgres.user,
        }

        response["redis"] = {
            "host": settings.redis.host,
            "port": settings.redis.port,
            "db_name": settings.redis.db,
        }

        response["mq"] = {
            "bootstrap_servers": settings.kafka.bootstrap_servers,
            "client_id": settings.kafka.client_id
        }

    return response
