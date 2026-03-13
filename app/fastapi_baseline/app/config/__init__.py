# app/config/__init__.py
from .setting import get_settings
from .logging import setup_logging

__all__ = [
    "get_settings",
    "setup_logging",
]
