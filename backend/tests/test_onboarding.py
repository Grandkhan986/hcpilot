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
async def test_update_practice_persists_fields_and_logs(client: AsyncClient):
    r = await client.put(
        "/users/me/practice",
        json={
            "state_code": "TX",
            "license_number": "RN-TX-2026-99",
            "license_expiration_date": "2028-01-15",
            "license_type": "NP",
            "practice_name": "Houston IV Wellness",
            "npi_number": "9876543210",
        },
        headers=HEADERS(),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["state_code"] == "TX"
    assert body["license_type"] == "NP"

    # Audit logged
    logs = (await client.get("/audit_logs?entity_type=users", headers=HEADERS())).json()
    assert len(logs) == 1
    assert logs[0]["changes"]["state_code"] == "TX"


@pytest.mark.anyio
async def test_create_medical_director_deactivates_previous(client: AsyncClient):
    """Un nouveau MD désactive l'ancien actif (un seul MD couvre la pratique)."""
    # MD existant : md_001
    r = await client.post(
        "/compliance/medical_directors",
        json={
            "first_name": "Dr. Sarah",
            "last_name": "Chen",
            "email": "s.chen@new.example",
            "license_number": "MD-CA-555",
            "state_code": "CA",
            "contract_start_date": "2026-05-20",
            "contract_end_date": "2027-05-20",
            "audit_frequency_days": 30,
        },
        headers=HEADERS(),
    )
    assert r.status_code == 201
    new_md = r.json()
    assert new_md["is_active"] is True

    # /compliance/medical_director renvoie le nouveau MD actif
    active = (await client.get("/compliance/medical_director", headers=HEADERS())).json()
    assert active["id"] == new_md["id"]
    assert active["last_name"] == "Chen"


@pytest.mark.anyio
async def test_create_standing_order_uses_template_text(client: AsyncClient):
    r = await client.post(
        "/compliance/standing_orders",
        json={
            "formulation_name": "Myers Cocktail",
            "expires_at": "2027-06-01",
        },
        headers=HEADERS(),
    )
    assert r.status_code == 201
    so = r.json()
    assert so["formulation_name"] == "Myers Cocktail"
    assert "Myers Cocktail" in so["consent_text"]
    assert so["is_active"] is True
    # Le MD par défaut est l'actif courant
    assert so["medical_director_id"] == "md_001"


@pytest.mark.anyio
async def test_create_standing_order_rejects_unknown_template(client: AsyncClient):
    r = await client.post(
        "/compliance/standing_orders",
        json={"formulation_name": "Potion magique"},
        headers=HEADERS(),
    )
    assert r.status_code == 400


@pytest.mark.anyio
async def test_full_onboarding_flow(client: AsyncClient):
    """Flow complet : practice → MD → SO. Vérifie l'état final via /compliance/dashboard."""
    # 1. License
    await client.put("/users/me/practice", json={
        "state_code": "NY", "license_number": "RN-NY-2026-001",
        "license_expiration_date": "2028-12-31", "license_type": "RN",
        "practice_name": "NYC Wellness IV",
    }, headers=HEADERS())

    # 2. MD
    md = (await client.post("/compliance/medical_directors", json={
        "first_name": "Dr. John", "last_name": "Smith",
        "email": "j.smith@example.com", "license_number": "MD-NY-111",
        "state_code": "NY", "contract_start_date": "2026-05-20",
        "contract_end_date": "2027-05-20", "audit_frequency_days": 30,
    }, headers=HEADERS())).json()

    # 3. Standing order
    so = (await client.post("/compliance/standing_orders", json={
        "formulation_name": "NAD+ 250mg",
        "medical_director_id": md["id"],
        "expires_at": "2027-05-20",
    }, headers=HEADERS())).json()

    # 4. Vérif dashboard
    dash = (await client.get("/compliance/dashboard", headers=HEADERS())).json()
    assert dash["license"]["state_code"] == "NY"
    assert dash["medical_director"]["id"] == md["id"]
    assert any(o["id"] == so["id"] for o in dash["standing_orders"])
