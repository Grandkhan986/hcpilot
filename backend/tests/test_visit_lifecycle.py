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


@pytest.mark.anyio
async def test_start_visit_sets_started_at(client: AsyncClient):
    headers = {"Authorization": f"Bearer {_token()}"}

    # Reset si un test précédent a déjà démarré ces visites.
    import main
    for v in main.MOCK_SESSIONS:
        if v["id"] == "vis_001":
            v["status"] = "scheduled"
            v["started_at"] = None
            v["completed_at"] = None
            break

    r = await client.post("/sessions/vis_001/start", headers=headers)
    assert r.status_code == 200
    body = r.json()
    assert body["session_id"] == "vis_001"
    assert body["started_at"] is not None

    fetched = await client.get("/sessions/vis_001", headers=headers)
    assert fetched.status_code == 200
    visit = fetched.json()
    assert visit["status"] == "in_progress"
    assert visit["started_at"] is not None


@pytest.mark.anyio
async def test_start_is_idempotent(client: AsyncClient):
    headers = {"Authorization": f"Bearer {_token()}"}

    r1 = await client.post("/sessions/vis_001/start", headers=headers)
    first_start = r1.json()["started_at"]
    r2 = await client.post("/sessions/vis_001/start", headers=headers)
    second_start = r2.json()["started_at"]
    assert first_start == second_start


@pytest.mark.anyio
async def test_complete_visit_sets_completed_at(client: AsyncClient):
    headers = {"Authorization": f"Bearer {_token()}"}

    import main
    for v in main.MOCK_SESSIONS:
        if v["id"] == "vis_002":
            v["status"] = "scheduled"
            v["started_at"] = None
            v["completed_at"] = None
            break

    await client.post("/sessions/vis_002/start", headers=headers)
    r = await client.post("/sessions/vis_002/complete", headers=headers)
    assert r.status_code == 200
    body = r.json()
    assert body["started_at"] is not None
    assert body["completed_at"] is not None
    assert body["completed_at"] >= body["started_at"]
