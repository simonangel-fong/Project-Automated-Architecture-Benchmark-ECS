# models/base.py
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy import MetaData

# specify app schema
metadata = MetaData(schema="app")


class Base(DeclarativeBase):
    metadata = metadata
