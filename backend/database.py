"""
backend/database.py
--------------------
SQLAlchemy engine + session factory.
All routers import `get_db` and use it as a FastAPI dependency.

SPECIAL-CHARACTER PASSWORD SAFETY
----------------------------------
The connection URL is built with sqlalchemy.engine.URL.create() instead of
plain f-string interpolation.  This ensures that passwords containing
@, /, %, +, :, or other URL-reserved characters are percent-encoded
correctly by SQLAlchemy before being passed to PyMySQL.
"""

import os
import logging
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL
from sqlalchemy.orm import sessionmaker, DeclarativeBase
from sqlalchemy.exc import SQLAlchemyError
from dotenv import load_dotenv

logger = logging.getLogger(__name__)

# Load .env from the backend/ directory
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))

DB_HOST     = os.getenv("DB_HOST",     "localhost")
DB_PORT     = int(os.getenv("DB_PORT", "3306"))
DB_USER     = os.getenv("DB_USER",     "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")
DB_NAME     = os.getenv("DB_NAME",     "olist_ecommerce")

# Build the URL safely — special characters in the password are
# percent-encoded by SQLAlchemy, not interpolated raw into the URL string.
_db_url = URL.create(
    drivername="mysql+pymysql",
    username=DB_USER,
    password=DB_PASSWORD,   # SQLAlchemy handles encoding
    host=DB_HOST,
    port=DB_PORT,
    database=DB_NAME,
    query={"charset": "utf8mb4"},
)

# ---------------------------------------------------------------------------
# Engine — created once at import time.
# If MySQL is unavailable the engine object is still created (SQLAlchemy is
# lazy — it does not open a connection until first use).  pool_pre_ping
# ensures stale connections are transparently recycled.
# ---------------------------------------------------------------------------
try:
    engine = create_engine(
        _db_url,
        pool_pre_ping=True,    # silently reconnect on dropped connections
        pool_size=5,
        max_overflow=10,
    )
except Exception as exc:            # pragma: no cover — only triggers on bad args
    logger.error("Failed to create SQLAlchemy engine: %s", exc)
    engine = None  # type: ignore[assignment]

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy ORM models."""
    pass


def get_db():
    """
    FastAPI dependency that yields a database session and
    always closes it when the request is finished.

    Raises HTTP 503 (via the router's error handler) if the engine was
    not initialised or the database is unreachable.

    Usage in a router:
        from backend.database import get_db
        from sqlalchemy.orm import Session
        from fastapi import Depends

        @router.get("/example")
        def example(db: Session = Depends(get_db)):
            ...
    """
    if engine is None:
        raise RuntimeError("Database engine is not available.")
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def test_connection() -> bool:
    """Return True if the database is reachable, False otherwise."""
    if engine is None:
        return False
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
