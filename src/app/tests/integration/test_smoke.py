"""
Integration smoke tests — run against a live environment.
Requires --base-url pytest option or BASE_URL env var.
"""
import os
import pytest
import httpx


BASE_URL = os.getenv("BASE_URL", "http://localhost:8000")


@pytest.fixture(scope="session")
def base_url(request):
    return getattr(request.config.option, "base_url", None) or BASE_URL


def test_health_endpoint(base_url):
    response = httpx.get(f"{base_url}/health", timeout=10)
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_root_endpoint(base_url):
    response = httpx.get(f"{base_url}/", timeout=10)
    assert response.status_code == 200
