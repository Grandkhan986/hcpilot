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


def _reset_state():
    import main
    # Restore patient archived state
    for p in main.MOCK_CLIENTS:
        p["archived_at"] = None
    # Reset sessions to scheduled with future dates
    future = (datetime.now() + timedelta(hours=2)).isoformat()
    for v in main.MOCK_SESSIONS:
        v["status"] = "scheduled"
        v["scheduled_at"] = future
        v["started_at"] = None
        v["completed_at"] = None


@pytest.mark.anyio
async def test_archive_patient_deletes_scheduled_visits(client: AsyncClient):
    _reset_state()
    headers = {"Authorization": f"Bearer {_token()}"}

    r = await client.delete("/clients/pat_001", headers=headers)
    assert r.status_code == 200
    body = r.json()
    assert body["deleted_scheduled_sessions"] >= 1

    # Le patient sort de la liste par défaut
    actives = await client.get("/clients", headers=headers)
    ids = [p["id"] for p in actives.json()]
    assert "pat_001" not in ids

    # Mais apparaît dans ?archived=true
    archived = await client.get("/clients?archived=true", headers=headers)
    archived_ids = [p["id"] for p in archived.json()]
    assert "pat_001" in archived_ids

    # Session planifiée du patient → supprimée (404)
    session = await client.get("/sessions/vis_001", headers=headers)
    assert session.status_code == 404


@pytest.mark.anyio
async def test_archive_keeps_completed_visits(client: AsyncClient):
    _reset_state()
    headers = {"Authorization": f"Bearer {_token()}"}

    # On termine vis_002 d'abord, puis on archive son patient
    await client.post("/sessions/vis_002/start", headers=headers)
    await client.post("/sessions/vis_002/complete", headers=headers)

    r = await client.delete("/clients/pat_002", headers=headers)
    assert r.status_code == 200
    # Aucune session supprimée (la seule session était completed)
    assert r.json()["deleted_scheduled_sessions"] == 0

    # La session completed est toujours là (audit/facturation)
    v = await client.get("/sessions/vis_002", headers=headers)
    assert v.status_code == 200
    assert v.json()["status"] == "completed"


@pytest.mark.anyio
async def test_archive_then_restore(client: AsyncClient):
    _reset_state()
    headers = {"Authorization": f"Bearer {_token()}"}

    await client.delete("/clients/pat_002", headers=headers)
    r = await client.post("/clients/pat_002/restore", headers=headers)
    assert r.status_code == 200

    # Réapparaît dans la liste par défaut
    actives = await client.get("/clients", headers=headers)
    ids = [p["id"] for p in actives.json()]
    assert "pat_002" in ids


@pytest.mark.anyio
async def test_archive_twice_returns_409(client: AsyncClient):
    _reset_state()
    headers = {"Authorization": f"Bearer {_token()}"}

    await client.delete("/clients/pat_003", headers=headers)
    r = await client.delete("/clients/pat_003", headers=headers)
    assert r.status_code == 409


@pytest.mark.anyio
async def test_address_change_syncs_future_scheduled_visits(client: AsyncClient):
    _reset_state()
    headers = {"Authorization": f"Bearer {_token()}"}

    # Brief : adresse splittée en 5 champs ; nouveau line1 = adresse changée
    new_line1 = "100 Rue de Rivoli"
    r = await client.put(
        "/clients/pat_001",
        json={"address_line1": new_line1},
        headers=headers,
    )
    assert r.status_code == 200
    assert r.json()["synced_future_sessions"] >= 1

    v = (await client.get("/sessions/vis_001", headers=headers)).json()
    assert new_line1 in v["address"]


@pytest.mark.anyio
async def test_address_change_does_not_touch_past_or_in_progress(client: AsyncClient):
    _reset_state()
    headers = {"Authorization": f"Bearer {_token()}"}

    # Session déjà en cours → ne doit pas être resync'ée
    await client.post("/sessions/vis_001/start", headers=headers)
    original_addr = (await client.get("/sessions/vis_001", headers=headers)).json()["address"]

    await client.put(
        "/clients/pat_001",
        json={"address_line1": "200 Avenue Foch"},
        headers=headers,
    )

    after = (await client.get("/sessions/vis_001", headers=headers)).json()
    assert after["address"] == original_addr  # snapshot préservé


@pytest.mark.anyio
async def test_delete_visit_sets_cancelled(client: AsyncClient):
    _reset_state()
    headers = {"Authorization": f"Bearer {_token()}"}

    r = await client.delete("/sessions/vis_002", headers=headers)
    assert r.status_code == 200
    v = (await client.get("/sessions/vis_002", headers=headers)).json()
    assert v["status"] == "cancelled"


@pytest.mark.anyio
async def test_delete_completed_visit_returns_409(client: AsyncClient):
    _reset_state()
    headers = {"Authorization": f"Bearer {_token()}"}

    await client.post("/sessions/vis_003/start", headers=headers)
    await client.post("/sessions/vis_003/complete", headers=headers)

    r = await client.delete("/sessions/vis_003", headers=headers)
    assert r.status_code == 409


@pytest.mark.anyio
async def test_visits_filterable_by_client_id(client: AsyncClient):
    _reset_state()
    headers = {"Authorization": f"Bearer {_token()}"}

    r = await client.get("/sessions?client_id=pat_001", headers=headers)
    assert r.status_code == 200
    sessions = r.json()
    assert all(v["client_id"] == "pat_001" for v in sessions)
    assert len(sessions) >= 1
