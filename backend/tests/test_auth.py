import pytest
from httpx import AsyncClient


@pytest.mark.anyio
async def test_login_returns_token(client: AsyncClient):
    response = await client.post(
        "/auth/login",
        json={"email": "doctor@hcpilot.com", "password": "password123"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"


@pytest.mark.anyio
async def test_protected_endpoint_requires_auth(client: AsyncClient):
    response = await client.get("/clients")
    assert response.status_code == 401


@pytest.mark.anyio
async def test_protected_endpoint_rejects_invalid_token(client: AsyncClient):
    response = await client.get(
        "/clients",
        headers={"Authorization": "Bearer invalid-token"}
    )
    assert response.status_code == 401
