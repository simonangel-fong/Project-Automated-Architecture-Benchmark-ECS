# mq/kafka_producer.py
from __future__ import annotations

import ssl
import json
import asyncio
import logging
from typing import Optional

from aiokafka import AIOKafkaProducer
from aiokafka.abc import AbstractTokenProvider
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

from ..config import get_settings

logger = logging.getLogger(__name__)

# singleton
_producer: Optional[AIOKafkaProducer] = None
_init_lock = asyncio.Lock()


class MSKTokenProvider(AbstractTokenProvider):
    """Token provider for AWS MSK IAM authentication."""

    def __init__(self, aws_region: str):
        self.aws_region = aws_region

    async def token(self) -> str:
        token, _ = MSKAuthTokenProvider.generate_auth_token(self.aws_region)
        return token


# def _build_ssl_context() -> ssl.SSLContext:
#     # Default TLS
#     return ssl.create_default_context()


async def init_producer() -> AIOKafkaProducer:
    """
    Initialize and start the global Kafka producer (singleton).

    Supports both local PLAINTEXT and AWS MSK SASL_SSL configurations
    based on settings.kafka.use_msk_auth.

    Returns the started producer instance.
    """
    global _producer

    if _producer is not None:
        return _producer

    # acquire lock
    async with _init_lock:
        # Re-check after acquiring lock
        if _producer is not None:
            return _producer

        settings = get_settings()

        # Base configuration
        producer_config = {
            "bootstrap_servers": settings.kafka_bootstrap_servers,
            "client_id": getattr(settings.kafka, "client_id", None) or "producer",
            "value_serializer": lambda v: json.dumps(v).encode("utf-8"),
            "request_timeout_ms": 40000,
            "acks": 1,
            "compression_type": "gzip",
            "max_request_size": 1048576,
            "linger_ms": 10,
        }

        print(f"######## {settings.kafka.use_msk_auth} ########")
        
        # AWS MSK security configuration
        if settings.kafka.use_msk_auth:
            producer_config.update({
                "security_protocol": "SASL_SSL",
                "sasl_mechanism": "OAUTHBEARER",
                "sasl_oauth_token_provider": MSKTokenProvider(settings.aws_region),
                "ssl_context": ssl.create_default_context(),
            })
            logger.info("Producer configured for AWS MSK with SASL_SSL")
        else:
            logger.info("Producer configured for local Kafka with PLAINTEXT")

        producer = AIOKafkaProducer(**producer_config)

        try:
            await producer.start()
            logger.info(
                "Kafka producer started successfully, bootstrap_servers=%s",
                settings.kafka_bootstrap_servers
            )
        except Exception as e:
            logger.exception("Failed to start Kafka producer")
            # Best-effort cleanup
            try:
                await producer.stop()
            except Exception:
                pass
            raise

        _producer = producer
        return _producer


async def close_producer() -> None:
    """
    Stop and clear the global producer.

    Flushes any pending messages before stopping.
    """
    global _producer

    if _producer is None:
        return

    # Acquire lock
    async with _init_lock:
        if _producer is None:
            return

        try:
            # Flush pending messages before stopping
            await _producer.flush()
            logger.info("Kafka producer flushed pending messages")

            await _producer.stop()
            logger.info("Kafka producer stopped successfully")
        except Exception:
            logger.exception("Error while stopping Kafka producer")
        finally:
            _producer = None


def get_producer() -> AIOKafkaProducer:
    """
    Get the started producer; raise if not initialized.

    Raises:
        RuntimeError: If producer hasn't been initialized via init_producer()
    """
    if _producer is None:
        raise RuntimeError(
            "Kafka producer not initialized. Call await init_producer() first."
        )
    return _producer
