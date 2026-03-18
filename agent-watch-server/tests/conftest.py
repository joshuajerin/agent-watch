"""Shared test fixtures."""

import pytest
from fastapi.testclient import TestClient

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Set env vars before importing app modules
os.environ.setdefault("AUTH_TOKEN", "test-token-abc123")
os.environ.setdefault("ANTHROPIC_API_KEY", "sk-ant-test-key")

from main import app


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


@pytest.fixture
def valid_token():
    return "test-token-abc123"


@pytest.fixture
def invalid_token():
    return "wrong-token"
