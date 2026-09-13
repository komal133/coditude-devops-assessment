"""Tests that run in CI without any database or AWS account."""

from fastapi.testclient import TestClient

from app import app

client = TestClient(app)


def test_health_returns_ok():
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
