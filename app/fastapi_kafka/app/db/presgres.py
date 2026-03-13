# app/db/presgres.py
from collections.abc import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncEngine
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from ..config import get_settings

settings = get_settings()

# Async SQLAlchemy engine
engine: AsyncEngine = create_async_engine(
    settings.postgres_url,
    echo=settings.debug,                    # SQL logging in debug mode only
    pool_pre_ping=settings.debug,           # Validate connections before using them
    pool_size=settings.pool_size,           # Persistent connections in the pool; Default: 5
    max_overflow=settings.max_overflow,     # Extra temporary connections allowed; Default: 10
    pool_timeout=3,                         # Seconds to wait for a connection from the pool
    pool_recycle=1800,                      # Recycle connections every 30 minutes
    connect_args={
        "timeout": 5,                       # Connection attempt timeout (asyncpg)
        "server_settings": {"jit": "off"},  # Disable PostgreSQL JIT
        # "ssl": False,
    },
)

# Session factory that creates AsyncSession instances
async_session_maker = async_sessionmaker(
    engine,
    expire_on_commit=False,       # Keep instance attributes after commit
    autoflush=False,              # Explicit flush control
    class_=AsyncSession,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Async database session dependency for FastAPI.

    Yields:
        AsyncSession: SQLAlchemy async session that is automatically closed.
    """
    async with async_session_maker() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
