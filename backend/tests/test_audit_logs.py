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


HEADERS = lambda: {"Authorization": f"Bearer {_token()}"}


@pytest.mark.anyio
async def test_audit_log_is_empty_at_start(client: AsyncClient):
    r = await client.get("/audit_logs", headers=HEADERS())
    assert r.status_code == 200
    assert r.json() == []


@pytest.mark.anyio
async def test_start_visit_creates_audit_entry(client: AsyncClient):
    await client.post("/sessions/vis_001/start", headers=HEADERS())
    logs = (await client.get("/audit_logs?entity_type=sessions", headers=HEADERS())).json()
    assert len(logs) == 1
    assert logs[0]["entity_type"] == "sessions"
    assert logs[0]["entity_id"] == "vis_001"
    assert logs[0]["action"] == "update"
    assert logs[0]["changes"]["status"] == "in_progress"
    assert logs[0]["ip_address"] is not None


@pytest.mark.anyio
async def test_complete_visit_creates_audit_entry(client: AsyncClient):
    await client.post("/sessions/vis_002/start", headers=HEADERS())
    await client.post("/sessions/vis_002/complete", headers=HEADERS())
    logs = (await client.get("/audit_logs?entity_type=sessions", headers=HEADERS())).json()
    # 2 entrées : start + complete
    actions = sorted(l["action"] for l in logs)
    statuses = sorted(l["changes"]["status"] for l in logs if "status" in (l.get("changes") or {}))
    assert "update" in actions
    assert "completed" in statuses


@pytest.mark.anyio
async def test_archive_patient_creates_audit_entry(client: AsyncClient):
    await client.delete("/clients/pat_003", headers=HEADERS())
    logs = (await client.get("/audit_logs?entity_type=clients", headers=HEADERS())).json()
    assert len(logs) == 1
    assert logs[0]["entity_id"] == "pat_003"
    assert logs[0]["action"] == "delete"


@pytest.mark.anyio
async def test_record_usage_creates_audit_entry(client: AsyncClient):
    await client.post(
        "/inventory/usage",
        json={"lot_id": "lot_001", "quantity": 1},
        headers=HEADERS(),
    )
    logs = (await client.get(
        "/audit_logs?entity_type=inventory_transactions", headers=HEADERS()
    )).json()
    assert len(logs) == 1
    assert logs[0]["action"] == "create"
    assert logs[0]["changes"]["lot_id"] == "lot_001"


@pytest.mark.anyio
async def test_audit_logs_isolated_per_nurse(client: AsyncClient):
    """Une nurse ne doit pas voir les logs d'une autre nurse."""
    await client.post("/sessions/vis_001/start", headers=HEADERS())
    # Token d'une autre nurse fictive
    other_token = jwt.encode({
        "sub": "usr_999", "email": "other@x.com", "role": "provider",
        "user_metadata": {"full_name": "Other"},
        "created_at": datetime.now().isoformat(),
        "exp": datetime.now() + timedelta(hours=1),
    }, "test-jwt-secret-key-for-testing-only", algorithm="HS256")
    r = await client.get("/audit_logs", headers={"Authorization": f"Bearer {other_token}"})
    assert r.status_code == 200
    assert r.json() == []
