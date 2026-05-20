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
async def test_compliance_dashboard_shape(client: AsyncClient):
    r = await client.get("/compliance/dashboard", headers=HEADERS())
    assert r.status_code == 200
    data = r.json()
    assert "license" in data
    assert "medical_director" in data
    assert "standing_orders" in data
    assert "alerts" in data
    assert data["license"]["state_code"] == "CA"
    assert data["medical_director"]["last_name"] == "Patterson"
    assert len(data["standing_orders"]) >= 1


@pytest.mark.anyio
async def test_license_status_color(client: AsyncClient):
    """La licence expire le 2026-08-15 ; on s'attend à 'ok' ou 'warning' selon
    qu'on est à <90j de l'échéance au moment du run."""
    r = await client.get("/compliance/dashboard", headers=HEADERS())
    license = r.json()["license"]
    assert license["status"] in ("ok", "warning", "critical", "expired")
    assert isinstance(license["days_remaining"], int)


@pytest.mark.anyio
async def test_standing_orders_expiring_count(client: AsyncClient):
    """Le seed contient un standing_order qui expire le 2026-06-10 → critical ou warning."""
    r = await client.get("/compliance/dashboard", headers=HEADERS())
    data = r.json()
    assert data["standing_orders_expiring_soon"] >= 1


@pytest.mark.anyio
async def test_list_standing_orders(client: AsyncClient):
    r = await client.get("/compliance/standing_orders", headers=HEADERS())
    assert r.status_code == 200
    items = r.json()
    assert len(items) == 3
    names = [i["formulation_name"] for i in items]
    assert "Myers Cocktail" in names


@pytest.mark.anyio
async def test_get_medical_director(client: AsyncClient):
    r = await client.get("/compliance/medical_director", headers=HEADERS())
    assert r.status_code == 200
    md = r.json()
    assert md["email"] == "j.patterson@medical.example"


@pytest.mark.anyio
async def test_acknowledge_alert(client: AsyncClient):
    r = await client.post(
        "/compliance/alerts/alert_001/acknowledge", headers=HEADERS()
    )
    assert r.status_code == 200
    body = r.json()
    assert body["acknowledged_at"] is not None

    dash = (await client.get("/compliance/dashboard", headers=HEADERS())).json()
    # Une seule alerte non lue à l'origine → 0 après ack
    assert dash["unread_alerts"] == 0


@pytest.mark.anyio
async def test_acknowledge_unknown_alert_returns_404(client: AsyncClient):
    r = await client.post(
        "/compliance/alerts/alert_does_not_exist/acknowledge", headers=HEADERS()
    )
    assert r.status_code == 404
