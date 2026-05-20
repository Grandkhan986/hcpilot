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
async def test_list_lots_excludes_depleted_by_default(client: AsyncClient):
    r = await client.get("/inventory/lots", headers=HEADERS())
    assert r.status_code == 200
    lots = r.json()
    assert all(l["quantity_remaining"] > 0 for l in lots)
    # Champs enrichis
    assert all("expiration_status" in l for l in lots)
    assert all("days_to_expiry" in l for l in lots)


@pytest.mark.anyio
async def test_products_grouped_by_name(client: AsyncClient):
    r = await client.get("/inventory/products", headers=HEADERS())
    assert r.status_code == 200
    products = r.json()
    names = [p["product_name"] for p in products]
    # Myers a 3 lots, doit apparaître une seule fois
    assert names.count("Myers Cocktail") == 1
    myers = next(p for p in products if p["product_name"] == "Myers Cocktail")
    assert myers["lot_count"] == 3
    assert myers["total_quantity"] == 10 + 8 + 24


@pytest.mark.anyio
async def test_add_lot_creates_reception_transaction(client: AsyncClient):
    payload = {
        "product_name": "B12 1000mcg",
        "product_category": "vitamins",
        "barcode": "0987654321098",
        "lot_number": "B12-2026-T01",
        "expiration_date": "2027-12-31",
        "quantity_initial": 10,
        "unit_cost": 8.50,
        "supplier": "Empower",
    }
    r = await client.post("/inventory/lots", json=payload, headers=HEADERS())
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["quantity_remaining"] == 10
    assert body["expiration_status"] == "ok"

    txns = (await client.get(f"/inventory/lots/{body['id']}/transactions", headers=HEADERS())).json()
    assert len(txns) == 1
    assert txns[0]["transaction_type"] == "reception"


@pytest.mark.anyio
async def test_record_usage_decrements_and_logs(client: AsyncClient):
    r = await client.post(
        "/inventory/usage",
        json={"lot_id": "lot_001", "session_id": "vis_001", "quantity": 2},
        headers=HEADERS(),
    )
    assert r.status_code == 200
    body = r.json()
    assert body["lot"]["quantity_remaining"] == 10 - 2
    assert body["transaction"]["quantity_change"] == -2
    assert body["transaction"]["transaction_type"] == "usage"


@pytest.mark.anyio
async def test_usage_refuses_insufficient_stock(client: AsyncClient):
    r = await client.post(
        "/inventory/usage",
        json={"lot_id": "lot_008", "quantity": 100},  # gants = 3 remaining
        headers=HEADERS(),
    )
    assert r.status_code == 409


@pytest.mark.anyio
async def test_find_by_barcode_returns_all_lots_of_product(client: AsyncClient):
    r = await client.get("/inventory/by_barcode/0301234567890", headers=HEADERS())
    assert r.status_code == 200
    lots = r.json()
    # 3 lots de Myers partagent ce barcode
    assert len(lots) == 3
    assert all(l["product_name"] == "Myers Cocktail" for l in lots)


@pytest.mark.anyio
async def test_dashboard_low_stock_uses_inventory(client: AsyncClient):
    """Le dashboard /reports/dashboard doit utiliser le nouvel inventory et
    flagger les produits dont la somme tous lots <= seuil (5)."""
    r = await client.get("/reports/dashboard", headers=HEADERS())
    assert r.status_code == 200
    data = r.json()
    # Gants nitrile M : 3 unités au total → low_stock
    names = [p["product_name"] for p in data["low_stock_items"]]
    assert "Gants nitrile M" in names
    # NAD+ 500mg : 4 + 6 = 10 → pas low_stock
    assert "NAD+ 500mg" not in names
