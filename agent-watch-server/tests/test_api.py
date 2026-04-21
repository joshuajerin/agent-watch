"""Tests for REST API endpoints."""

import os
import sys

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.environ.setdefault("AUTH_TOKEN", "test-token-abc123")
os.environ.setdefault("ANTHROPIC_API_KEY", "sk-ant-test-key")

from fastapi.testclient import TestClient
from main import app


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def test_health_endpoint(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "ok"
    assert data["version"] == "1.0.0"
    assert data["provider"] == "anthropic"
    assert data["model"] == "claude-haiku-4-5-20251001"
    assert data["rate_limit_qpm"] == 20


def test_query_no_auth(client):
    resp = client.post("/v1/query", json={"text": "hello"})
    assert resp.status_code == 401


def test_query_invalid_auth(client):
    resp = client.post(
        "/v1/query",
        json={"text": "hello"},
        headers={"Authorization": "Bearer wrong-token"},
    )
    assert resp.status_code == 401


def test_query_text_too_long(client):
    long_text = "a" * 4097
    resp = client.post(
        "/v1/query",
        json={"text": long_text},
        headers={"Authorization": "Bearer test-token-abc123"},
    )
    assert resp.status_code == 422  # Pydantic validation


def test_query_valid_auth_triggers_agent(client, monkeypatch):
    """Verify a valid auth'd request reaches the agent layer (mock the AI call)."""

    async def mock_run_agent(query: str):
        yield "The answer is 42."

    import routers.api as api_module
    import agent.runner as runner_module
    monkeypatch.setattr(runner_module, "run_agent", mock_run_agent)
    monkeypatch.setattr(api_module, "run_agent", mock_run_agent)

    resp = client.post(
        "/v1/query",
        json={"text": "What is 6 times 7?", "session_id": "test-session-1"},
        headers={"Authorization": "Bearer test-token-abc123"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["session_id"] == "test-session-1"
    assert "42" in data["response"]


def test_swagger_disabled(client):
    """Swagger UI should be disabled in production."""
    resp = client.get("/docs")
    assert resp.status_code == 404

    resp = client.get("/redoc")
    assert resp.status_code == 404
