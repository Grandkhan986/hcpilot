import pytest
from httpx import AsyncClient


@pytest.mark.anyio
async def test_health_check(client: AsyncClient):
    response = await client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "timestamp" in data
    assert data["version"] == "1.0.0"


@pytest.mark.anyio
async def test_v1_prefix_strips_to_bare_route(client: AsyncClient):
    """Audit H14 — /v1/{path} must route to the same handler as /{path}."""
    versioned = await client.get("/v1/health")
    assert versioned.status_code == 200
    data = versioned.json()
    assert data["status"] == "healthy"
    assert data["version"] == "1.0.0"
