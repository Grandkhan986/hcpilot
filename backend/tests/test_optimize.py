import pytest
from jose import jwt
from datetime import datetime, timedelta
from httpx import AsyncClient


def _token() -> str:
    payload = {
        "sub": "usr_001",
        "email": "doctor@hcpilot.com",
        "role": "provider",
        "user_metadata": {"full_name": "Dr. Test"},
        "created_at": datetime.now().isoformat(),
        "exp": datetime.now() + timedelta(hours=1),
    }
    return jwt.encode(payload, "test-jwt-secret-key-for-testing-only", algorithm="HS256")


def _visit(id_: str, client_id: str, lat: float | None = None, lng: float | None = None) -> dict:
    return {
        "id": id_,
        "client_id": client_id,
        "nurse_id": "usr_001",
        "scheduled_at": datetime.now().isoformat(),
        "formulation_name": "Primary_Care",
        "status": "scheduled",
        "address": "n/a",
        "latitude": lat,
        "longitude": lng,
        "estimated_duration": 30,
        "total_amount": 50.0,
        "created_at": datetime.now().isoformat(),
        "updated_at": datetime.now().isoformat(),
    }


@pytest.mark.anyio
async def test_optimize_empty_returns_empty(client: AsyncClient):
    r = await client.post(
        "/optimize/routes", json=[], headers={"Authorization": f"Bearer {_token()}"}
    )
    assert r.status_code == 200
    assert r.json()["optimized_route"] == []


@pytest.mark.anyio
async def test_optimize_falls_back_without_mapbox_token(client: AsyncClient, monkeypatch):
    # Garantit l'absence de token au moment de l'appel.
    import main
    monkeypatch.setattr(main, "MAPBOX_ACCESS_TOKEN", None)

    sessions = [
        _visit("vis_001", "pat_001", 48.8688, 2.3315),
        _visit("vis_002", "pat_002", 48.8703, 2.2855),
        _visit("vis_003", "pat_003", 48.8730, 2.3372),
    ]
    r = await client.post(
        "/optimize/routes", json=sessions, headers={"Authorization": f"Bearer {_token()}"}
    )
    assert r.status_code == 200
    body = r.json()
    assert "warning" in body
    assert [item["session_id"] for item in body["optimized_route"]] == [
        "vis_001", "vis_002", "vis_003"
    ]
