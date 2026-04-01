from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_returns_200():
    response = client.get("/health")
    assert response.status_code == 200


def test_health_body():
    response = client.get("/health")
    body = response.json()
    assert body["status"] == "healthy"
    assert "environment" in body
    assert "timestamp" in body


def test_root_returns_200():
    response = client.get("/")
    assert response.status_code == 200
