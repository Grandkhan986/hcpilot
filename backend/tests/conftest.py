import copy
import os
import pytest
from httpx import AsyncClient, ASGITransport

# Set required env vars for testing
os.environ.setdefault("SUPABASE_URL", "http://localhost:54321")
os.environ.setdefault("SUPABASE_SERVICE_KEY", "test-service-key")
os.environ.setdefault("SUPABASE_JWT_SECRET", "test-jwt-secret-key-for-testing-only")

import main
from main import app

# Snapshot initial des mocks pour réinitialiser entre chaque test (l'archivage
# hard-supprime des sessions, l'édition mute en place — sans reset, les tests
# se contaminent les uns les autres).
_INITIAL_PATIENTS = copy.deepcopy(main.MOCK_CLIENTS)
_INITIAL_VISITS = copy.deepcopy(main.MOCK_SESSIONS)
_INITIAL_LOTS = copy.deepcopy(main.MOCK_INVENTORY_LOTS)
_INITIAL_TXNS = copy.deepcopy(main.MOCK_INVENTORY_TRANSACTIONS)
_INITIAL_INVOICES = copy.deepcopy(main.MOCK_INVOICES)
_INITIAL_CONSENTS = copy.deepcopy(main.MOCK_CONSENTS)
_INITIAL_MDS = copy.deepcopy(main.MOCK_MEDICAL_DIRECTORS)
_INITIAL_STANDING_ORDERS = copy.deepcopy(main.MOCK_STANDING_ORDERS)
_INITIAL_COMPLIANCE_ALERTS = copy.deepcopy(main.MOCK_COMPLIANCE_ALERTS)
_INITIAL_AUDIT_LOGS = copy.deepcopy(main.MOCK_AUDIT_LOGS)


@pytest.fixture(autouse=True)
def _reset_mocks_between_tests():
    main.MOCK_CLIENTS[:] = copy.deepcopy(_INITIAL_PATIENTS)
    main.MOCK_SESSIONS[:] = copy.deepcopy(_INITIAL_VISITS)
    main.MOCK_INVENTORY_LOTS[:] = copy.deepcopy(_INITIAL_LOTS)
    main.MOCK_INVENTORY_TRANSACTIONS[:] = copy.deepcopy(_INITIAL_TXNS)
    main.MOCK_INVOICES[:] = copy.deepcopy(_INITIAL_INVOICES)
    main.MOCK_CONSENTS[:] = copy.deepcopy(_INITIAL_CONSENTS)
    main.MOCK_MEDICAL_DIRECTORS[:] = copy.deepcopy(_INITIAL_MDS)
    main.MOCK_STANDING_ORDERS[:] = copy.deepcopy(_INITIAL_STANDING_ORDERS)
    main.MOCK_COMPLIANCE_ALERTS[:] = copy.deepcopy(_INITIAL_COMPLIANCE_ALERTS)
    main.MOCK_AUDIT_LOGS[:] = copy.deepcopy(_INITIAL_AUDIT_LOGS)
    yield


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
