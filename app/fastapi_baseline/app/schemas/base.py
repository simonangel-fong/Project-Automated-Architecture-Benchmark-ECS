# schemas/base.py
from pydantic import BaseModel, ConfigDict


class ORMModel(BaseModel):
    """define data schemas with automatic data parsing and validation"""
    model_config = ConfigDict(from_attributes=True)
