# config/logging.py
from __future__ import annotations

import logging.config
from pathlib import Path

from .setting import get_settings

settings = get_settings()


def setup_logging() -> None:
    """
    Configure application-wide logging.

    - Dev local:
        LOG_LEVEL=DEBUG
        ACCESS_LOG_ENABLED=true
        LOG_TO_FILE=true  (optional)
    - Staging (stress test):
        LOG_LEVEL=WARNING
        ACCESS_LOG_ENABLED=false
        LOG_TO_FILE=false
    - Production:
        LOG_LEVEL=INFO or WARNING
        ACCESS_LOG_ENABLED=true (or false if you don't need request logs)
        LOG_TO_FILE=false
    """

    # get base level from setting; otherwise, from settings.debug
    base_level = getattr(settings, "log_level", None) or (
        "DEBUG" if settings.debug else "INFO")

    # get values from setting
    log_to_file = getattr(settings, "log_to_file", False)
    log_dir = Path(getattr(settings, "log_dir", "logs"))

    if log_to_file:
        log_dir.mkdir(parents=True, exist_ok=True)

    handlers: dict[str, dict] = {
        "console": {
            "class": "logging.StreamHandler",
            "level": base_level,
            "formatter": "standard",
        },
    }

    if log_to_file:
        handlers.update(
            {
                "app_file": {
                    "class": "logging.handlers.TimedRotatingFileHandler",
                    "level": base_level,
                    "formatter": "standard",
                    "filename": str(log_dir / "app.log"),
                    "when": "midnight",
                    "backupCount": 7,
                    "encoding": "utf-8",
                },
                "uvicorn_access_file": {
                    "class": "logging.handlers.TimedRotatingFileHandler",
                    "level": base_level,
                    "formatter": "standard",
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
            }
        )

    # Attach file handlers only when enabled.
    app_handlers = ["console"] + (["app_file"] if log_to_file else [])
    access_handlers = ["console"] + \
        (["uvicorn_access_file"] if log_to_file else [])
    error_handlers = ["console"] + \
        (["uvicorn_error_file"] if log_to_file else [])

    access_log_level = "INFO" if getattr(
        settings, "access_log_enabled", True) else "WARNING"

    logging_config = {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "standard": {
                "format": "%(asctime)s [%(levelname)s] %(name)s - %(message)s",
            },
        },
        "handlers": handlers,
        "loggers": {
            "app": {
                "handlers": app_handlers,
                "level": base_level,
                "propagate": False,
            },
            # Uvicorn access logs (HTTP requests)
            "uvicorn.access": {
                "handlers": access_handlers,
                "level": access_log_level,
                "propagate": False,
            },
            # Uvicorn error logs (server errors, tracebacks)
            "uvicorn.error": {
                "handlers": error_handlers,
                "level": "WARNING",
                "propagate": False,
            },
            # Root logger fallback
            # Keep aligned with base_level so LOG_LEVEL controls overall noise.
            "": {
                "handlers": app_handlers,
                "level": base_level,
            },
        },
    }

    logging.config.dictConfig(logging_config)
