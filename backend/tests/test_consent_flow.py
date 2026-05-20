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


def _payload(
    session_id: str = "vis_001",
    standing_order_id: str = "so_001",
    all_accepted: bool = True,
) -> dict:
    return {
        "session_id": session_id,
        "standing_order_id": standing_order_id,
        "checkpoints": [
            {"label": "Je comprends les risques généraux de l'IV", "accepted": all_accepted},
            {"label": "Je comprends les risques spécifiques", "accepted": True},
            {"label": "J'autorise le partage avec mon medical director", "accepted": True},
            {"label": "J'accepte la politique d'annulation", "accepted": True},
        ],
        "signature_image_b64": "iVBORw0KGgo=",
        "pdf_b64": "JVBERi0xLjQK",
        "signed_latitude": 48.8688,
        "signed_longitude": 2.3315,
        "device_info": {"model": "iPhone17,3", "os": "iOS 18.2"},
    }


@pytest.mark.anyio
async def test_list_formulations(client: AsyncClient):
    r = await client.get("/formulations", headers=HEADERS())
    assert r.status_code == 200
    items = r.json()
    assert len(items) >= 1
    assert all("consent_text" in f and "name" in f for f in items)


@pytest.mark.anyio
async def test_create_consent_happy_path(client: AsyncClient):
    r = await client.post("/consents", json=_payload(), headers=HEADERS())
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["session_id"] == "vis_001"
    assert body["formulation_name"] == "Myers Cocktail"  # résolu via standing order
    assert body["standing_order_id"] == "so_001"
    assert body["has_pdf"] is True
    assert body["ip_address"] is not None


@pytest.mark.anyio
async def test_create_consent_rejects_unknown_standing_order(client: AsyncClient):
    r = await client.post(
        "/consents",
        json=_payload(standing_order_id="so_fake"),
        headers=HEADERS(),
    )
    assert r.status_code == 400


@pytest.mark.anyio
async def test_create_consent_rejected_if_any_checkpoint_unchecked(client: AsyncClient):
    r = await client.post("/consents", json=_payload(all_accepted=False), headers=HEADERS())
    assert r.status_code == 400


@pytest.mark.anyio
async def test_create_consent_404_if_visit_missing(client: AsyncClient):
    p = _payload(session_id="vis_does_not_exist")
    r = await client.post("/consents", json=p, headers=HEADERS())
    assert r.status_code == 404


@pytest.mark.anyio
async def test_create_consent_409_if_already_exists(client: AsyncClient):
    r1 = await client.post("/consents", json=_payload(), headers=HEADERS())
    assert r1.status_code == 201
    r2 = await client.post("/consents", json=_payload(), headers=HEADERS())
    assert r2.status_code == 409


@pytest.mark.anyio
async def test_visit_links_to_consent_after_signing(client: AsyncClient):
    await client.post("/consents", json=_payload(), headers=HEADERS())
    r = await client.get("/sessions/vis_001/consent", headers=HEADERS())
    assert r.status_code == 200
    assert r.json()["session_id"] == "vis_001"


@pytest.mark.anyio
async def test_get_consent_pdf(client: AsyncClient):
    created = (await client.post("/consents", json=_payload(), headers=HEADERS())).json()
    r = await client.get(f"/consents/{created['id']}/pdf", headers=HEADERS())
    assert r.status_code == 200
    assert r.json()["pdf_b64"].startswith("JVBE")  # signature PDF
