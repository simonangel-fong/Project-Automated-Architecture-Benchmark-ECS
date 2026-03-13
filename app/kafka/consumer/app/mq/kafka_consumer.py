# mq/kafka_consumer.py
from __future__ import annotations

import asyncio
import json
import ssl
from typing import Optional

from aiokafka import AIOKafkaConsumer
from aiokafka.abc import AbstractTokenProvider
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

from ..config import get_settings

_consumer: Optional[AIOKafkaConsumer] = None
_init_lock = asyncio.Lock()


class MSKTokenProvider(AbstractTokenProvider):
    def __init__(self, aws_region: str):
        self.aws_region = aws_region

    async def token(self) -> str:
        token, _ = MSKAuthTokenProvider.generate_auth_token(self.aws_region)
        return token


async def init_consumer() -> AIOKafkaConsumer:
    global _consumer

    if _consumer is not None:
        return _consumer

    async with _init_lock:
        if _consumer is not None:
            return _consumer

        settings = get_settings()
        topics = settings.kafka.topics or [settings.kafka.topic]

        # Base configuration
        consumer_config = {
            "bootstrap_servers": settings.kafka_bootstrap_servers,
            "client_id": settings.kafka.client_id,
            "group_id": settings.kafka.group_id,
            "auto_offset_reset": settings.kafka.auto_offset_reset,
            "enable_auto_commit": False,
            "value_deserializer": lambda v: json.loads(v.decode("utf-8")),
            "request_timeout_ms": 40000,
            "session_timeout_ms": 30000,
            "heartbeat_interval_ms": 10000,
            "max_poll_interval_ms": 600000,
        }
    
        print(f"######## {settings.kafka.use_msk_auth} ########")
        # AWS MSK security configuration
        if settings.kafka.use_msk_auth:
            consumer_config.update({
                "security_protocol": "SASL_SSL",
                "sasl_mechanism": "OAUTHBEARER",
                "sasl_oauth_token_provider": MSKTokenProvider(settings.aws_region),
                "ssl_context": ssl.create_default_context(),
            })

        # create consumer
        consumer = AIOKafkaConsumer(*topics, **consumer_config)

        try:
            await consumer.start()
        except Exception:
            try:
                await consumer.stop()
            except Exception:
                pass
            raise

        _consumer = consumer
        return _consumer


async def close_consumer() -> None:
    global _consumer

    if _consumer is None:
        return

    async with _init_lock:
        if _consumer is None:
            return
        try:
            await _consumer.stop()
        finally:
            _consumer = None


def get_consumer() -> AIOKafkaConsumer:
    if _consumer is None:
        raise RuntimeError(
            "Kafka consumer not initialized. Call await init_consumer() first.")
    return _consumer
