# config/setting.py
from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import List, Literal
from urllib.parse import quote_plus

from pydantic import BaseModel, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


# ==============================
# Kafka
# ==============================
class KafkaSettings(BaseModel):
    """Kafka configuration."""

    bootstrap_servers: str = Field(default="broker:9092")
    client_id: str = Field(default="auto-benchmark")

    # consumer settings
    group_id: str = Field(default="telemetry-consumer")
    auto_offset_reset: Literal["earliest", "latest",
                               "none"] = Field(default="earliest")
    enable_auto_commit: bool = Field(default=True)

    # topic(s)
    topic: str = Field(default="telemetry")
    topics: List[str] = Field(default_factory=list)

    # msk auth
    use_msk_auth: bool = False # turn on for aws msk

# ==============================
# PostgreSQL
# ==============================
class PostgresSettings(BaseModel):
    """PostgreSQL database configuration."""

    host: str = "postgres"
    port: int = 5432
    user: str = "app_user"
    db: str = "app_db"
    password: str = "postgres"

    @property
    def url(self) -> str:
        """
        SQLAlchemy async connection URL.

        Example:
            postgresql+asyncpg://user:password@host:5432/db
        """
        user = quote_plus(self.user)
        pwd = quote_plus(self.password)
        return f"postgresql+asyncpg://{user}:{pwd}@{self.host}:{self.port}/{self.db}"


# ==============================
# Redis
# ==============================
class RedisSettings(BaseModel):
    """Redis configuration."""

    host: str = "redis"
    port: int = 6379
    db: int = 0
    password: str | None = None

    @property
    def url(self) -> str:
        """
        Redis connection URL.

        Example:
            redis://:password@host:6379/0
            redis://host:6379/0
        """
        if self.password:
            pwd = quote_plus(self.password)
            return f"redis://:{pwd}@{self.host}:{self.port}/{self.db}"
        return f"redis://{self.host}:{self.port}/{self.db}"


# ==============================
# Application Settings
# ==============================
class Settings(BaseSettings):
    """Application settings."""

    aws_region: str = "ca-central-1"
    debug: bool = True
    kafka: KafkaSettings = KafkaSettings()

    # performance tuning
    pool_size: int = Field(
        default=5,
        alias="POOL_SIZE",
        description="The largest number of connections that will be kept persistently in the pool.",
    )

    max_overflow: int = Field(
        default=10,
        alias="MAX_OVERFLOW",
        description="The additional connections when the pool_size is reached.",
    )

    batch_size: int = Field(
        default=1000,
        alias="BATCH_SIZE",
        description="The number of data rows for a batch job.",
    )

    # Pydantic Settings config
    model_config = SettingsConfigDict(
        # project root .env
        env_file=str(Path(__file__).resolve().parent.parent.parent / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",               # ignore unknown env vars
        env_nested_delimiter="__",    # POSTGRES__HOST -> settings.postgres.host
    )

    # Nested config
    postgres: PostgresSettings = PostgresSettings()
    redis: RedisSettings = RedisSettings()
    kafka: KafkaSettings = KafkaSettings()

    # Properties
    @property
    def postgres_url(self) -> str:
        """Postgres connection URL."""
        return self.postgres.url

    @property
    def redis_url(self) -> str:
        """Redis connection URL."""
        return self.redis.url

    @property
    def kafka_bootstrap_servers(self) -> str:
        """Kafka bootstrap servers string."""
        return self.kafka.bootstrap_servers

    @property
    def kafka_topics(self) -> list[str]:
        """Use kafka.topics if provided, else fall back to single kafka.topic."""
        return self.kafka.topics or [self.kafka.topic]


# ==============================
# Settings
# ==============================
@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """
    Get a cached Settings instance.
    """
    return Settings()
