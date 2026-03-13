# config/setting.py
from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Literal
from urllib.parse import quote_plus

from pydantic import BaseModel, Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


# ==============================
# Kafka
# ==============================
class KafkaSettings(BaseModel):
    """Kafka configuration."""
    bootstrap_servers: str = "broker:9092"
    client_id: str = "telemetry_producer"
    topic: str = "telemetry"
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

    # Pydantic Settings config
    model_config = SettingsConfigDict(
        # project root .env
        env_file=str(Path(__file__).resolve().parent.parent.parent / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",               # ignore unknown env vars
        env_nested_delimiter="__",    # POSTGRES__HOST -> settings.postgres.host
    )

    # ------------------------------
    # General
    # ------------------------------
    project: str = Field(
        default="auto benchmark",
        alias="PROJECT",
        description="The project name",
    )

    env: str = Field(
        default="dev",
        alias="ENV",
        description="The environment name",
    )

    debug: bool = Field(
        default=True,
        alias="DEBUG",
        description="Whether it is debug mode",
    )

    cors: str = Field(
        default="http://localhost,http://localhost:8000,http://localhost:8080",
        alias="CORS",
        description="Comma-separated list of allowed CORS origins",
    )

    # General
    aws_region: str = "ca-central-1"

    # ------------------------------
    # Performance tuning
    # ------------------------------
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

    workers: int = Field(
        default=1,
        alias="WORKER",
        description="The number of uvicorn workers.",
    )

    # ------------------------------
    # Logging controls
    # ------------------------------
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = Field(
        default="INFO",
        alias="LOG_LEVEL",
        description="Logging level: DEBUG/INFO/WARNING/ERROR/CRITICAL.",
    )

    # enable access log
    access_log_enabled: bool = Field(
        default=False,  # no access log, prevents log explode volume
        alias="ACCESS_LOG_ENABLED",
        description="Enable Uvicorn access logs.",
    )

    # enable log to file
    log_to_file: bool = Field(
        default=False,  # no log to file, log to stdout/stderr for best practice
        alias="LOG_TO_FILE",
        description="Write rotated files (usually False for ECS/EKS).",
    )

    @field_validator("log_level", mode="before")
    @classmethod
    def normalize_log_level(cls, v: str) -> str:
        """Normalize LOG_LEVEL input to uppercase (e.g., 'warn' -> 'WARN' -> invalid)."""
        return str(v).strip().upper()

    # ------------------------------
    # Nested config
    # ------------------------------
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
    def cors_list(self) -> list[str]:
        """Parsed list of CORS origins from the comma-separated string."""
        return [
            origin.strip()
            for origin in self.cors.split(",")
            if origin.strip()
        ]


# ==============================
# Settings
# ==============================
@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """
    Get a cached Settings instance.
    """
    return Settings()
