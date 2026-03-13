# config/logging.py
from __future__ import annotations

import logging
import logging.config
# from logging.handlers import TimedRotatingFileHandler
from pathlib import Path

from .setting import get_settings

settings = get_settings()


def setup_logging() -> None:
    """
    Configure application-wide logging.

    - Writes logs to a dedicated directory (configurable via settings).
    - Uses rotating log files for app, access, and error logs.
    - Integrates with uvicorn loggers so HTTP access logs are captured as well.
    """
    log_dir = Path(getattr(settings, "log_dir", "logs"))
    log_dir.mkdir(parents=True, exist_ok=True)

    logging_config = {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "standard": {
                "format": "%(asctime)s [%(levelname)s] %(name)s - %(message)s",
            },
            "access": {
                "format": "%(asctime)s [%(levelname)s] %(name)s - %(message)s",
            },
        },
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "level": "DEBUG" if settings.debug else "INFO",
                "formatter": "standard",
            },
            "app_file": {
                "class": "logging.handlers.TimedRotatingFileHandler",
                "level": "INFO",
                "formatter": "standard",
                "filename": str(log_dir / "app.log"),
                "when": "midnight",
                "backupCount": 7,
                "encoding": "utf-8",
            },
            "uvicorn_access_file": {
                "class": "logging.handlers.TimedRotatingFileHandler",
                "level": "INFO",
                "formatter": "access",
                "filename": str(log_dir / "access.log"),
                "when": "midnight",
                "backupCount": 7,
                "encoding": "utf-8",
            },
            "uvicorn_error_file": {
                "class": "logging.handlers.TimedRotatingFileHandler",
                "level": "WARNING",
                "formatter": "standard",
                "filename": str(log_dir / "error.log"),
                "when": "midnight",
                "backupCount": 7,
                "encoding": "utf-8",
            },
        },
        "loggers": {
            # Your application code: app.*, app.routers.*, etc.
            "app": {
                "handlers": ["console", "app_file"],
                "level": "DEBUG" if settings.debug else "INFO",
                "propagate": False,
            },
            # Uvicorn access logs (HTTP requests)
            "uvicorn.access": {
                "handlers": ["console", "uvicorn_access_file"],
                "level": "INFO",
                "propagate": False,
            },
            # Uvicorn error logs (server errors, tracebacks)
            "uvicorn.error": {
                "handlers": ["console", "uvicorn_error_file"],
                "level": "INFO",
                "propagate": False,
            },
            # Root logger fallback
            "": {
                "handlers": ["console", "app_file"],
                "level": "INFO",
            },
        },
    }

    logging.config.dictConfig(logging_config)
