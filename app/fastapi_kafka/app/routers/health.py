# app/routers/health.py
import logging

from aiokafka import AIOKafkaProducer
from fastapi import APIRouter, Depends
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_db, redis_client
from ..mq import get_producer

router = APIRouter(prefix="/health", tags=["health"])
logger = logging.getLogger(__name__)
settings = get_settings()


def _maybe_detail(exc: Exception) -> str | None:
    return str(exc) if getattr(settings, "debug", False) else None


@router.get("/", summary="App health check")
async def health() -> dict:
    return {
        "status": "ok",
        "app": getattr(settings, "app_name", "app"),
        "environment": getattr(settings, "env", "unknown"),
    }


# @router.get("/db", summary="Database health check")
# async def health_db(db: AsyncSession = Depends(get_db)) -> JSONResponse:
#     try:
#         await db.execute(text("SELECT 1"))
#         return JSONResponse({"database": "reachable"})
#     except Exception as exc:
#         logger.exception("Database health check failed")
#         return JSONResponse(
#             status_code=503,
#             content={"database": "unreachable", "detail": _maybe_detail(exc)},
#         )


@router.get("/redis", summary="Redis health check")
async def health_redis() -> JSONResponse:
    try:
        pong = await redis_client.ping()
        return JSONResponse({"redis": "reachable", "pong": pong})
    except Exception as exc:
        logger.exception("Redis health check failed")
        return JSONResponse(
            status_code=503,
            content={"redis": "unreachable", "detail": _maybe_detail(exc)},
        )


@router.get("/kafka", summary="Kafka health check")
async def health_kafka(
    producer: AIOKafkaProducer = Depends(get_producer),
) -> JSONResponse:
    """
    Kafka readiness check for MSK (aiokafka + IAM)
    """
    topic = settings.kafka.topic

    try:
        # Ensure metadata is loaded
        await producer.client.force_metadata_update()

        partitions = producer.client.cluster.partitions_for_topic(topic)

        if not partitions:
            raise RuntimeError(f"No partitions available for topic '{topic}'")

        return JSONResponse(
            {
                "kafka": "reachable",
                "topic": topic,
                "partitions": sorted(partitions),
                "bootstrap_servers": settings.kafka_bootstrap_servers,
            }
        )

    except Exception as exc:
        logger.exception("Kafka health check failed")
        return JSONResponse(
            status_code=503,
            content={
                "kafka": "unreachable",
                "topic": topic,
                "detail": _maybe_detail(exc),
            },
        )
