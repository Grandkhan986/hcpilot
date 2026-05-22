import pytest
from jose import jwt
from datetime import datetime, timedelta
from httpx import AsyncClient


def create_test_token() -> str:
    """Create a valid JWT token for testing."""
    payload = {
        "sub": "test-user-id",
        "email": "provider@test.com",
        "role": "provider",
        "user_metadata": {
            "full_name": "Dr. Test",
            "specialty": "General"
        },
        "created_at": datetime.now().isoformat(),
        "exp": datetime.now() + timedelta(hours=1)
    }
    return jwt.encode(payload, "test-jwt-secret-key-for-testing-only", algorithm="HS256")


@pytest.mark.anyio
async def test_list_patients_authenticated(client: AsyncClient):
    token = create_test_token()
    response = await client.get(
        "/clients",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    assert isinstance(response.json(), list)


@pytest.mark.anyio
async def test_get_current_user(client: AsyncClient):
    token = create_test_token()
    response = await client.get(
        "/users/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["email"] == "provider@test.com"
    assert data["id"] == "test-user-id"
