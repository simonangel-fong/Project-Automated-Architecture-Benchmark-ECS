# tests/test_main_root.py
from fastapi.testclient import TestClient
from app import main

def get_client():
    """build a TestClient from the main app."""
    return TestClient(main.app)


def test_home_basic_response():
    """
    Basic smoke test:
    - endpoint is reachable
    - returns HTTP 200
    - has core fields
    """
    client = get_client()
    resp = client.get("/api")
    assert resp.status_code == 200

    data = resp.json()
    assert isinstance(data, dict)

    # Core fields
    assert data["project"] == main.settings.project
    assert data["status"] == "ok"
    assert data["environment"] == main.settings.env
    assert data["debug"] == main.settings.debug

    # Docs links
    assert "docs" in data
    docs = data["docs"]
    assert docs["openapi"] == "/openapi.json"
    assert docs["swagger_ui"] == "/docs"
    assert docs["redoc"] == "/redoc"


def test_home_debug_false(monkeypatch):
    """
    When debug is False, sensitive sections (fastapi, postgres, redis)
    must NOT be present.
    """
    # Arrange
    monkeypatch.setattr(main.settings, "debug", False, raising=False)
    client = get_client()

    # Act
    resp = client.get("/api")
    assert resp.status_code == 200
    data = resp.json()

    # Assert base fields
    assert data["debug"] is False

    # Sensitive sections should be absent
    assert "fastapi" not in data
    assert "postgres" not in data
    assert "redis" not in data


def test_home_debug_true(monkeypatch):
    """
    When debug is True, response should include fastapi, postgres, redis
    sections with expected fields.
    """
    # Arrange
    monkeypatch.setattr(main.settings, "debug", True, raising=False)
    client = get_client()

    # Act
    resp = client.get("/api")
    assert resp.status_code == 200
    data = resp.json()

    # Debug flag
    assert data["debug"] is True

    # FastAPI section
    assert "fastapi" in data
    assert "fastapi_host" in data["fastapi"]
    # We don't assert the exact hostname value here, just that it exists.

    # Postgres section
    assert "postgres" in data
    pg = data["postgres"]
    assert pg["host"] == main.settings.postgres.host
    assert pg["port"] == main.settings.postgres.port
    assert pg["db_name"] == main.settings.postgres.db
    assert pg["user"] == main.settings.postgres.user
