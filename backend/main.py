"""
HCPilot Backend API
FastAPI serveur avec Supabase comme backend
Conformité HIPAA active
"""

import os
import sys
import logging
import httpx
from urllib.parse import quote
from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from typing import Optional, List, Tuple
from jose import jwt
from datetime import datetime, timedelta
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Configuration
from dotenv import load_dotenv
load_dotenv()

# Validation des variables d'environnement obligatoires
REQUIRED_ENV_VARS = ["SUPABASE_URL", "SUPABASE_SERVICE_KEY", "SUPABASE_JWT_SECRET"]
missing_vars = [var for var in REQUIRED_ENV_VARS if not os.getenv(var)]
if missing_vars:
    sys.exit(f"ERREUR: Variables d'environnement manquantes: {', '.join(missing_vars)}")

# Configuration Supabase
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
SUPABASE_JWT_SECRET = os.getenv("SUPABASE_JWT_SECRET")

# Configuration Stripe
STRIPE_SECRET_KEY = os.getenv("STRIPE_SECRET_KEY")

# Configuration Mapbox (geocoding + routing). Optionnel : si absent, géocodage/
# optimisation tournent en mode passthrough — utile pour les tests sans réseau.
MAPBOX_ACCESS_TOKEN = os.getenv("MAPBOX_ACCESS_TOKEN")
MAPBOX_API_BASE = "https://api.mapbox.com"

# Configuration CORS
ALLOWED_ORIGINS = os.getenv(
    "ALLOWED_ORIGINS",
    "http://localhost:5173,http://localhost:3000"
).split(",")

# Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Rate Limiter
limiter = Limiter(key_func=get_remote_address)

# FastAPI App
app = FastAPI(
    title="HCPilot API",
    description="Operating System for Mobile Healthcare Professionals",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Rate Limiter State
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# OAuth2 Scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Modèles Pydantic
class User(BaseModel):
    id: str
    email: str
    full_name: str
    role: str
    specialty: Optional[str] = None
    state_license: Optional[str] = None
    created_at: datetime

class Client(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    date_of_birth: Optional[str] = None
    gender: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    medical_history: Optional[str] = None
    allergies: Optional[str] = None
    # Soft delete : la fiche reste consultable en "Archives" mais sort de la liste
    # principale. Conserve l'historique des visites/factures pour la facturation
    # et l'audit HIPAA.
    archived_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

class Session(BaseModel):
    id: str
    client_id: str
    nurse_id: str
    scheduled_at: datetime
    visit_type: str  # IV_Hydration, Post_Op, Primary_Care, etc.
    status: str  # scheduled, in_progress, completed, cancelled
    address: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    estimated_duration: int  # minutes
    notes: Optional[str] = None
    total_amount: float
    copay: Optional[float] = None
    insurance_claimed: Optional[bool] = False
    # Clock-in / clock-out — drive duration calculation, billing, audit trail.
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

class StockItem(BaseModel):
    id: str
    nurse_id: str
    product_name: str
    description: Optional[str] = None
    quantity: int
    min_quantity: int
    expiration_date: Optional[str] = None
    barcode: Optional[str] = None
    category: str  # IV_Supplies, Medication, Equipment, etc.
    cost_per_unit: float
    created_at: datetime
    updated_at: datetime

class ConsentCheckpoint(BaseModel):
    """Une case à cocher du consentement (acquittement d'un point spécifique)."""
    label: str
    accepted: bool


class Consent(BaseModel):
    """Consentement éclairé signé pour une visite IV.

    Capture l'ensemble des preuves pour la conformité HIPAA + jurisprudence US :
    snapshot du texte au moment de la signature, géoloc, IP, device, signature
    PNG et PDF complet du document. Liée à une `standing_order` qui autorise
    l'administration de la formulation (preuve réglementaire).
    """
    id: str
    session_id: str
    client_id: str
    nurse_id: str
    standing_order_id: str
    formulation_name: str
    consent_text: str
    checkpoints: List[ConsentCheckpoint]
    signature_image_b64: str
    pdf_b64: Optional[str] = None
    signed_at: datetime
    signed_latitude: Optional[float] = None
    signed_longitude: Optional[float] = None
    ip_address: Optional[str] = None
    device_info: Optional[dict] = None
    created_at: datetime


class AuditLog(BaseModel):
    """Trace immuable d'une action sur une entité sensible (HIPAA §164.312).
    Brief : conservation 7 ans minimum, jamais supprimée."""
    id: str
    nurse_id: Optional[str]
    entity_type: str  # consents | patients | visits | inventory_lots | inventory_transactions
    entity_id: str
    action: str  # create | read | update | delete | export
    changes: Optional[dict] = None
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    occurred_at: datetime


class InventoryLot(BaseModel):
    """Un lot physique de produit IV — identifié par son numéro de lot fabricant.
    Une même référence produit peut avoir plusieurs lots avec des péremptions
    différentes. Le brief tient à cette granularité pour traçabilité + rappels."""
    id: str
    nurse_id: str
    product_name: str
    product_category: str  # nad | vitamins | saline | medication | supplies | other
    barcode: Optional[str] = None
    lot_number: str
    expiration_date: str  # YYYY-MM-DD
    quantity_initial: int
    quantity_remaining: int
    unit_cost: Optional[float] = None
    supplier: Optional[str] = None
    received_at: str
    notes: Optional[str] = None
    created_at: datetime


class InventoryTransaction(BaseModel):
    """Mouvement de stock — historique immuable pour audit et rapport."""
    id: str
    inventory_lot_id: str
    session_id: Optional[str] = None
    transaction_type: str  # reception | usage | adjustment | expired_disposal | recall
    quantity_change: int  # négatif = sortie, positif = entrée
    notes: Optional[str] = None
    created_at: datetime


class MedicalDirector(BaseModel):
    """Médecin superviseur qui couvre la pratique de la nurse (réglementation US)."""
    id: str
    nurse_id: str
    first_name: str
    last_name: str
    email: str
    license_number: str
    state_code: str  # 2 chars : "CA", "TX", etc.
    contract_start_date: str
    contract_end_date: Optional[str] = None
    audit_frequency_days: int = 30
    next_audit_date: Optional[str] = None
    is_active: bool = True
    created_at: datetime


class StandingOrder(BaseModel):
    """Ordonnance permanente signée par le MD : autorise la nurse à
    administrer une formulation IV sans prescription individuelle."""
    id: str
    nurse_id: str
    medical_director_id: Optional[str] = None
    formulation_name: str
    formulation_category: str
    consent_text: str
    version: int = 1
    signed_at: Optional[datetime] = None
    expires_at: Optional[str] = None  # date string YYYY-MM-DD
    is_active: bool = True
    created_at: datetime


class ComplianceAlert(BaseModel):
    """Alerte personnalisée à présenter à la nurse (expiration, audit, etc.)."""
    id: str
    nurse_id: str
    alert_type: str  # license_expiration | md_contract_expiration | standing_order_expiration | audit_due | regulatory_change
    severity: str  # info | warning | critical
    title: str
    description: str
    related_entity_id: Optional[str] = None
    triggered_at: datetime
    acknowledged_at: Optional[datetime] = None
    resolved_at: Optional[datetime] = None


class Invoice(BaseModel):
    id: str
    client_id: str
    nurse_id: str
    session_id: str
    invoice_number: str
    items: List[dict]
    subtotal: float
    tax: float
    discount: float
    total: float
    status: str  # draft, sent, paid, overdue
    due_date: datetime
    paid_at: Optional[datetime] = None
    stripe_payment_intent_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime

# Utility Functions
def verify_token(token: str = Depends(oauth2_scheme)) -> dict:
    """Verify JWT token for authentication"""
    try:
        payload = jwt.decode(
            token, 
            SUPABASE_JWT_SECRET, 
            algorithms=["HS256"]
        )
        return payload
    except (jwt.JWTError, jwt.ExpiredSignatureError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

def get_supabase_client():
    """Get Supabase client (placeholder - actual implementation uses Supabase SDK)"""
    # Implementation uses Supabase Python SDK
    # For now, returning placeholder
    return None


# Mapbox helpers
# HIPAA: on n'envoie à Mapbox que l'adresse postale ou les coordonnées —
# jamais d'identifiant patient, nom, ou autre PHI corrélant.

async def geocode_address(address: str) -> Optional[Tuple[float, float]]:
    """Geocode an address via Mapbox. Returns (longitude, latitude) or None.

    Returns None silently when MAPBOX_ACCESS_TOKEN is missing, so dev/tests
    can run without a network round-trip.
    """
    if not MAPBOX_ACCESS_TOKEN or not address:
        return None
    encoded = quote(address, safe="")
    url = f"{MAPBOX_API_BASE}/geocoding/v5/mapbox.places/{encoded}.json"
    params = {"access_token": MAPBOX_ACCESS_TOKEN, "limit": 1}
    try:
        async with httpx.AsyncClient(timeout=5.0) as http:
            r = await http.get(url, params=params)
            r.raise_for_status()
            features = r.json().get("features", [])
            if not features:
                return None
            lng, lat = features[0]["center"]
            return (float(lng), float(lat))
    except (httpx.HTTPError, KeyError, ValueError) as e:
        logger.warning("Mapbox geocoding failed for %r: %s", address, e)
        return None


async def optimize_route_mapbox(
    coords: List[Tuple[float, float]],
) -> Optional[dict]:
    """Call Mapbox Optimization v1 with full GeoJSON geometry.

    coords: list of (longitude, latitude).
    Returns {"order": [...], "geometry": [[lng,lat],...], "distance_m", "duration_s"}
    or None if the call fails / token missing.
    """
    if not MAPBOX_ACCESS_TOKEN or len(coords) < 2:
        return None
    coord_str = ";".join(f"{lng},{lat}" for lng, lat in coords)
    url = f"{MAPBOX_API_BASE}/optimized-trips/v1/mapbox/driving/{coord_str}"
    params = {
        "access_token": MAPBOX_ACCESS_TOKEN,
        "roundtrip": "false",
        "source": "first",
        "destination": "last",
        "geometries": "geojson",
        "overview": "full",
    }
    try:
        async with httpx.AsyncClient(timeout=10.0) as http:
            r = await http.get(url, params=params)
            r.raise_for_status()
            data = r.json()
            waypoints = data.get("waypoints", [])
            # waypoint_index = position in the optimal trip for each input coord.
            order = sorted(
                range(len(waypoints)),
                key=lambda i: waypoints[i]["waypoint_index"],
            )
            trip = (data.get("trips") or [{}])[0]
            geometry = trip.get("geometry", {}).get("coordinates", [])
            return {
                "order": order,
                "geometry": geometry,
                "distance_m": trip.get("distance", 0),
                "duration_s": trip.get("duration", 0),
            }
    except (httpx.HTTPError, KeyError, IndexError, ValueError) as e:
        logger.warning("Mapbox optimization failed: %s", e)
        return None

# Health Check Endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "version": "1.0.0"
    }

# Modèles de requête
class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    email: str
    password: str
    full_name: str
    role: str = "provider"
    specialty: Optional[str] = None

# Données mock pour le mode développement
MOCK_USERS = {
    "doctor@hcpilot.com": {
        "id": "usr_001",
        "email": "doctor@hcpilot.com",
        "password": "password123",
        "full_name": "Dr. Marie Dupont",
        "role": "provider",
        "specialty": "Médecine générale",
        # Champs compliance US (brief HCPilot — RN/NP indépendantes US)
        "state_code": "CA",
        "license_number": "RN-CA-2024-12345",
        "license_expiration_date": "2026-08-15",
        "license_type": "RN",
        "npi_number": "1234567890",
        "practice_name": "Wellness IV California",
        # Compat avec l'ancien champ unique state_license
        "state_license": "FR-IDF-2024-001",
        "created_at": "2024-01-15T10:00:00"
    }
}

MOCK_CLIENTS = [
    {
        "id": "pat_001", "first_name": "Jean", "last_name": "Martin",
        "email": "jean.martin@email.com", "phone": "06 12 34 56 78",
        "date_of_birth": "1958-03-15", "gender": "M",
        "address": "12 Rue de la Paix, 75002 Paris",
        "latitude": 48.8688, "longitude": 2.3315,
        "medical_history": "Diabète type 2, hypertension",
        "allergies": "Pénicilline",
        "created_at": "2024-02-01T09:00:00", "updated_at": "2024-06-01T14:30:00"
    },
    {
        "id": "pat_002", "first_name": "Françoise", "last_name": "Bernard",
        "email": "f.bernard@email.com", "phone": "06 98 76 54 32",
        "date_of_birth": "1945-11-22", "gender": "F",
        "address": "45 Avenue Victor Hugo, 75016 Paris",
        "latitude": 48.8703, "longitude": 2.2855,
        "medical_history": "Post-op hanche droite, arthrose",
        "allergies": None,
        "created_at": "2024-03-10T11:00:00", "updated_at": "2024-06-15T09:00:00"
    },
    {
        "id": "pat_003", "first_name": "Ahmed", "last_name": "Benali",
        "email": "a.benali@email.com", "phone": "07 11 22 33 44",
        "date_of_birth": "1972-07-08", "gender": "M",
        "address": "8 Boulevard Haussmann, 75009 Paris",
        "latitude": 48.8730, "longitude": 2.3372,
        "medical_history": "Insuffisance cardiaque, BPCO",
        "allergies": "Aspirine, Iode",
        "created_at": "2024-04-05T08:30:00", "updated_at": "2024-06-20T16:00:00"
    },
]

MOCK_SESSIONS = [
    {
        "id": "vis_001", "client_id": "pat_001", "nurse_id": "usr_001",
        "scheduled_at": datetime.now().replace(hour=9, minute=0).isoformat(),
        "visit_type": "Primary_Care", "status": "scheduled",
        "address": "12 Rue de la Paix, 75002 Paris",
        "latitude": 48.8688, "longitude": 2.3315,
        "estimated_duration": 45, "notes": "Contrôle glycémie + tension",
        "total_amount": 75.00, "copay": 23.00, "insurance_claimed": True,
        "created_at": "2024-06-01T08:00:00", "updated_at": "2024-06-01T08:00:00"
    },
    {
        "id": "vis_002", "client_id": "pat_002", "nurse_id": "usr_001",
        "scheduled_at": datetime.now().replace(hour=11, minute=0).isoformat(),
        "visit_type": "Post_Op", "status": "scheduled",
        "address": "45 Avenue Victor Hugo, 75016 Paris",
        "latitude": 48.8703, "longitude": 2.2855,
        "estimated_duration": 60, "notes": "Rééducation post-op J+14",
        "total_amount": 120.00, "copay": 0.00, "insurance_claimed": True,
        "created_at": "2024-06-01T08:00:00", "updated_at": "2024-06-01T08:00:00"
    },
    {
        "id": "vis_003", "client_id": "pat_003", "nurse_id": "usr_001",
        "scheduled_at": datetime.now().replace(hour=14, minute=30).isoformat(),
        "visit_type": "IV_Hydration", "status": "scheduled",
        "address": "8 Boulevard Haussmann, 75009 Paris",
        "latitude": 48.8730, "longitude": 2.3372,
        "estimated_duration": 90, "notes": "Perfusion IV + monitoring cardiaque",
        "total_amount": 180.00, "copay": 45.00, "insurance_claimed": False,
        "created_at": "2024-06-01T08:00:00", "updated_at": "2024-06-01T08:00:00"
    },
]

# Inventory lots seed — alignés sur le brief (per-lot tracking, brief categories
# nad/vitamins/saline/medication/supplies/other). Démonstration : 3 lots de
# Myers (dont 1 péremption rapprochée), 2 lots de NAD+ 500, 2 lots saline, 1
# lot gants (faible stock).
MOCK_INVENTORY_LOTS = [
    {
        "id": "lot_001", "nurse_id": "usr_001",
        "product_name": "Myers Cocktail", "product_category": "vitamins",
        "barcode": "0301234567890",
        "lot_number": "MYR-2025-A12", "expiration_date": "2026-12-15",
        "quantity_initial": 12, "quantity_remaining": 10,
        "unit_cost": 35.00, "supplier": "Empower Pharmacy",
        "received_at": "2025-10-01", "notes": None,
        "created_at": "2025-10-01T08:00:00",
    },
    {
        "id": "lot_002", "nurse_id": "usr_001",
        "product_name": "Myers Cocktail", "product_category": "vitamins",
        "barcode": "0301234567890",
        "lot_number": "MYR-2025-B07", "expiration_date": "2026-06-05",  # <30j = critical
        "quantity_initial": 8, "quantity_remaining": 8,
        "unit_cost": 35.00, "supplier": "Empower Pharmacy",
        "received_at": "2025-11-10", "notes": "À utiliser en priorité",
        "created_at": "2025-11-10T08:00:00",
    },
    {
        "id": "lot_003", "nurse_id": "usr_001",
        "product_name": "Myers Cocktail", "product_category": "vitamins",
        "barcode": "0301234567890",
        "lot_number": "MYR-2026-A03", "expiration_date": "2027-03-20",
        "quantity_initial": 24, "quantity_remaining": 24,
        "unit_cost": 33.50, "supplier": "Olympia Pharmacy",
        "received_at": "2026-04-15", "notes": None,
        "created_at": "2026-04-15T08:00:00",
    },
    {
        "id": "lot_004", "nurse_id": "usr_001",
        "product_name": "NAD+ 500mg", "product_category": "nad",
        "barcode": "0301234567891",
        "lot_number": "NAD-2025-Q4", "expiration_date": "2027-02-01",
        "quantity_initial": 6, "quantity_remaining": 4,
        "unit_cost": 180.00, "supplier": "Empower Pharmacy",
        "received_at": "2025-11-15", "notes": None,
        "created_at": "2025-11-15T08:00:00",
    },
    {
        "id": "lot_005", "nurse_id": "usr_001",
        "product_name": "NAD+ 500mg", "product_category": "nad",
        "barcode": "0301234567891",
        "lot_number": "NAD-2026-Q2", "expiration_date": "2027-05-10",
        "quantity_initial": 6, "quantity_remaining": 6,
        "unit_cost": 175.00, "supplier": "Olympia Pharmacy",
        "received_at": "2026-04-20", "notes": None,
        "created_at": "2026-04-20T08:00:00",
    },
    {
        "id": "lot_006", "nurse_id": "usr_001",
        "product_name": "Saline 0.9% 500ml", "product_category": "saline",
        "barcode": "0301234567892",
        "lot_number": "NACL-2025-X88", "expiration_date": "2027-08-30",
        "quantity_initial": 50, "quantity_remaining": 38,
        "unit_cost": 3.20, "supplier": "Henry Schein",
        "received_at": "2025-08-01", "notes": None,
        "created_at": "2025-08-01T08:00:00",
    },
    {
        "id": "lot_007", "nurse_id": "usr_001",
        "product_name": "Saline 0.9% 500ml", "product_category": "saline",
        "barcode": "0301234567892",
        "lot_number": "NACL-2025-X89", "expiration_date": "2027-09-15",
        "quantity_initial": 50, "quantity_remaining": 50,
        "unit_cost": 3.20, "supplier": "Henry Schein",
        "received_at": "2025-09-01", "notes": None,
        "created_at": "2025-09-01T08:00:00",
    },
    {
        "id": "lot_008", "nurse_id": "usr_001",
        "product_name": "Gants nitrile M", "product_category": "supplies",
        "barcode": "0301234567893",
        "lot_number": "GLV-2025-M03", "expiration_date": "2028-01-01",
        "quantity_initial": 100, "quantity_remaining": 3,
        "unit_cost": 0.18, "supplier": "Henry Schein",
        "received_at": "2025-01-15", "notes": "Stock bas, commander",
        "created_at": "2025-01-15T08:00:00",
    },
]


MOCK_INVENTORY_TRANSACTIONS: List[dict] = []

# Catalogue de formulations IV — tient lieu de "standing orders" pour le MVP.
# Le brief prévoit une vraie table standing_orders signée par un Medical Director ;
# cette version statique permet de débloquer le flow consent sans dépendre de cette
# chaîne (qui viendra dans la tranche Compliance).
FORMULATIONS = [
    {
        "name": "Myers Cocktail",
        "category": "vitamins",
        "consent_text": (
            "Myers Cocktail — Composition : Magnésium, Calcium, Vitamines du "
            "complexe B (B1, B2, B3, B5, B6), Vitamine B12, Vitamine C, dans "
            "une solution saline.\n\n"
            "Risques généraux d'une perfusion IV : douleur ou hématome au site "
            "d'injection, réaction allergique rare, infection, infiltration. "
            "Risques spécifiques : sensation de chaleur, goût métallique, "
            "vasodilatation transitoire pendant l'administration.\n\n"
            "Contre-indications : hypersensibilité connue à l'un des composants, "
            "insuffisance rénale sévère, grossesse au 1er trimestre.\n\n"
            "Cette intervention n'est pas un traitement médical et ne remplace "
            "pas une consultation avec votre médecin traitant."
        ),
    },
    {
        "name": "NAD+ 250mg",
        "category": "nad",
        "consent_text": (
            "NAD+ 250mg — Nicotinamide Adénine Dinucléotide, coenzyme essentiel "
            "au métabolisme énergétique cellulaire, en solution saline.\n\n"
            "Risques généraux d'une perfusion IV : douleur/hématome au site, "
            "réaction allergique rare, infection, infiltration. Risques "
            "spécifiques NAD+ : sensation de pression thoracique transitoire, "
            "nausées, anxiété passagère. Ces effets sont contrôlés en ralentissant "
            "le débit de perfusion.\n\n"
            "Contre-indications : grossesse, allaitement, traitement chimio en "
            "cours, troubles psychiatriques aigus.\n\n"
            "Durée d'administration approximative : 60-90 minutes."
        ),
    },
    {
        "name": "NAD+ 500mg",
        "category": "nad",
        "consent_text": (
            "NAD+ 500mg — Dose élevée de NAD+ en perfusion IV lente.\n\n"
            "Mêmes risques généraux qu'une perfusion IV standard, avec une "
            "probabilité accrue d'effets transitoires (pression thoracique, "
            "nausées) liée à la dose. La perfusion sera ralentie ou interrompue "
            "si l'inconfort devient significatif.\n\n"
            "Durée d'administration : 2-3 heures.\n\n"
            "Vous reconnaissez avoir été informé(e) de la possibilité d'arrêter "
            "la perfusion à tout moment."
        ),
    },
]


MOCK_CONSENTS: List[dict] = []


# Audit logs HIPAA — immuables, jamais supprimés (brief §HIPAA "conservation 7 ans")
MOCK_AUDIT_LOGS: List[dict] = []


def _log_audit(
    nurse_id: Optional[str],
    entity_type: str,
    entity_id: str,
    action: str,
    changes: Optional[dict] = None,
    request: Optional[Request] = None,
) -> None:
    """Append-only. Aucun chemin de code ne doit modifier ou supprimer une entrée
    après création. Capture IP + user-agent côté serveur (anti-spoofing)."""
    MOCK_AUDIT_LOGS.append({
        "id": f"al_{len(MOCK_AUDIT_LOGS) + 1:06d}",
        "nurse_id": nurse_id,
        "entity_type": entity_type,
        "entity_id": entity_id,
        "action": action,
        "changes": changes,
        "ip_address": request.client.host if request and request.client else None,
        "user_agent": request.headers.get("user-agent") if request else None,
        "occurred_at": datetime.now().isoformat(),
    })


# Compliance seed data — Medical Director + Standing Orders + Alertes pré-câblés
# pour démontrer le dashboard. Pour le MVP : 1 MD actif, 3 standing orders
# correspondant aux formulations, et 2 alertes (license + audit).
MOCK_MEDICAL_DIRECTORS = [
    {
        "id": "md_001",
        "nurse_id": "usr_001",
        "first_name": "Dr. James",
        "last_name": "Patterson",
        "email": "j.patterson@medical.example",
        "license_number": "MD-CA-987654",
        "state_code": "CA",
        "contract_start_date": "2025-09-01",
        "contract_end_date": "2026-09-01",  # ~4 mois restants
        "audit_frequency_days": 30,
        "next_audit_date": "2026-06-15",  # ~1 mois
        "is_active": True,
        "created_at": "2025-09-01T10:00:00",
    }
]

MOCK_STANDING_ORDERS = [
    {
        "id": "so_001",
        "nurse_id": "usr_001",
        "medical_director_id": "md_001",
        "formulation_name": "Myers Cocktail",
        "formulation_category": "vitamins",
        "consent_text": FORMULATIONS[0]["consent_text"],
        "version": 1,
        "signed_at": "2025-09-01T10:30:00",
        "expires_at": "2026-09-01",
        "is_active": True,
        "created_at": "2025-09-01T10:30:00",
    },
    {
        "id": "so_002",
        "nurse_id": "usr_001",
        "medical_director_id": "md_001",
        "formulation_name": "NAD+ 250mg",
        "formulation_category": "nad",
        "consent_text": FORMULATIONS[1]["consent_text"],
        "version": 1,
        "signed_at": "2025-09-01T10:30:00",
        "expires_at": "2026-06-10",  # < 30 jours = alerte
        "is_active": True,
        "created_at": "2025-09-01T10:30:00",
    },
    {
        "id": "so_003",
        "nurse_id": "usr_001",
        "medical_director_id": "md_001",
        "formulation_name": "NAD+ 500mg",
        "formulation_category": "nad",
        "consent_text": FORMULATIONS[2]["consent_text"],
        "version": 1,
        "signed_at": "2025-09-01T10:30:00",
        "expires_at": "2026-09-01",
        "is_active": True,
        "created_at": "2025-09-01T10:30:00",
    },
]

MOCK_COMPLIANCE_ALERTS = [
    {
        "id": "alert_001",
        "nurse_id": "usr_001",
        "alert_type": "audit_due",
        "severity": "warning",
        "title": "Audit MD à programmer",
        "description": "L'audit mensuel avec Dr. Patterson est dû autour du 15 juin 2026.",
        "related_entity_id": "md_001",
        "triggered_at": "2026-05-15T08:00:00",
        "acknowledged_at": None,
        "resolved_at": None,
    },
]


MOCK_INVOICES = [
    {
        "id": "inv_001", "client_id": "pat_001", "nurse_id": "usr_001",
        "session_id": "vis_001", "invoice_number": "INV-20240601-001",
        "items": [{"description": "Consultation médecine générale", "quantity": 1, "price": 75.00}],
        "subtotal": 75.00, "tax": 0.00, "discount": 0.00, "total": 75.00,
        "status": "paid", "due_date": "2024-07-01T00:00:00",
        "paid_at": "2024-06-05T10:00:00", "stripe_payment_intent_id": "pi_mock_001",
        "created_at": "2024-06-01T09:00:00", "updated_at": "2024-06-05T10:00:00"
    },
    {
        "id": "inv_002", "client_id": "pat_002", "nurse_id": "usr_001",
        "session_id": "vis_002", "invoice_number": "INV-20240601-002",
        "items": [{"description": "Soins post-opératoires", "quantity": 1, "price": 120.00}],
        "subtotal": 120.00, "tax": 0.00, "discount": 0.00, "total": 120.00,
        "status": "sent", "due_date": "2024-07-01T00:00:00",
        "paid_at": None, "stripe_payment_intent_id": None,
        "created_at": "2024-06-01T11:00:00", "updated_at": "2024-06-01T11:00:00"
    },
]

# Authentication Endpoints
@app.post("/auth/login")
@limiter.limit("5/minute")
async def login(request: Request, body: LoginRequest):
    """Login endpoint - returns JWT token"""
    user = MOCK_USERS.get(body.email)
    if not user or user["password"] != body.password:
        raise HTTPException(status_code=401, detail="Email ou mot de passe incorrect")

    token_payload = {
        "sub": user["id"],
        "email": user["email"],
        "role": user["role"],
        "user_metadata": {
            "full_name": user["full_name"],
            "specialty": user["specialty"],
            "state_license": user["state_license"],
        },
        "created_at": user["created_at"],
        "exp": datetime.now() + timedelta(hours=24)
    }
    access_token = jwt.encode(token_payload, SUPABASE_JWT_SECRET, algorithm="HS256")
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": {
            "id": user["id"],
            "email": user["email"],
            "full_name": user["full_name"],
            "role": user["role"],
            "specialty": user["specialty"],
        }
    }

@app.post("/auth/register")
@limiter.limit("5/minute")
async def register(request: Request, body: RegisterRequest):
    """Registration endpoint for healthcare professionals"""
    if body.email in MOCK_USERS:
        raise HTTPException(status_code=400, detail="Cet email est déjà utilisé")
    new_id = f"usr_{len(MOCK_USERS) + 1:03d}"
    MOCK_USERS[body.email] = {
        "id": new_id,
        "email": body.email,
        "password": body.password,
        "full_name": body.full_name,
        "role": body.role,
        "specialty": body.specialty,
        "state_license": None,
        "created_at": datetime.now().isoformat()
    }
    return {"message": "Inscription réussie", "user_id": new_id}

# User Endpoints
@app.get("/users/me", response_model=User)
async def get_current_user(payload: dict = Depends(verify_token)):
    """Get current user profile"""
    return User(
        id=payload.get("sub"),
        email=payload.get("email"),
        full_name=payload.get("user_metadata", {}).get("full_name", ""),
        role=payload.get("role", "provider"),
        specialty=payload.get("user_metadata", {}).get("specialty"),
        state_license=payload.get("user_metadata", {}).get("state_license"),
        created_at=datetime.fromisoformat(payload.get("created_at", datetime.now().isoformat()))
    )

@app.put("/users/me")
async def update_user(user: User, payload: dict = Depends(verify_token)):
    """Update current user profile"""
    return {"message": "User updated successfully", "user_id": payload.get("sub")}


class UpdatePracticeRequest(BaseModel):
    """Profil de pratique (brief Sprint 1 onboarding) — états US, licence, NPI."""
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None
    state_code: Optional[str] = None  # CA, TX, NY...
    license_number: Optional[str] = None
    license_expiration_date: Optional[str] = None
    license_type: Optional[str] = None  # RN | NP | LPN | MD | PA
    practice_name: Optional[str] = None
    npi_number: Optional[str] = None


@app.put("/users/me/practice")
async def update_practice(
    body: UpdatePracticeRequest,
    request: Request,
    payload: dict = Depends(verify_token),
):
    """Met à jour les infos de pratique (licence + État). Étape 1 du wizard.
    Audit-logé (modification du profil nurse = action sensible HIPAA)."""
    nurse_id = payload.get("sub")
    user = next((u for u in MOCK_USERS.values() if u["id"] == nurse_id), None)
    if not user:
        raise HTTPException(status_code=404, detail="Profil non trouvé")
    updates = body.model_dump(exclude_none=True)
    if "first_name" in updates and "last_name" in updates:
        updates["full_name"] = f"{updates['first_name']} {updates['last_name']}"
    elif "first_name" in updates:
        # Préserver le nom existant
        existing_last = user.get("full_name", "").split(" ", 1)
        last = existing_last[1] if len(existing_last) > 1 else ""
        updates["full_name"] = f"{updates['first_name']} {last}".strip()
    user.update(updates)
    _log_audit(
        nurse_id=nurse_id,
        entity_type="users",
        entity_id=nurse_id,
        action="update",
        changes={k: v for k, v in updates.items() if k != "full_name"},
        request=request,
    )
    return {
        "message": "Profil mis à jour",
        "user_id": nurse_id,
        "state_code": user.get("state_code"),
        "license_number": user.get("license_number"),
        "license_expiration_date": user.get("license_expiration_date"),
        "license_type": user.get("license_type"),
        "practice_name": user.get("practice_name"),
        "npi_number": user.get("npi_number"),
    }

# Client Endpoints
@app.get("/clients")
async def list_patients(
    skip: int = 0,
    limit: int = 100,
    archived: Optional[bool] = None,
    payload: dict = Depends(verify_token),
):
    """List patients.

    Par défaut : seulement les patients actifs (non archivés).
    - ?archived=true  → uniquement les archivés (Room d'archives)
    - ?archived=false → uniquement les actifs (= défaut)
    - paramètre absent → comportement par défaut (actifs)
    """
    show_archived = archived is True
    results = [
        p for p in MOCK_CLIENTS
        if (p.get("archived_at") is not None) == show_archived
    ]
    return results[skip:skip + limit]

@app.post("/clients", status_code=status.HTTP_201_CREATED)
async def create_patient(patient: dict, payload: dict = Depends(verify_token)):
    """Create a new patient. Auto-geocodes address if lat/lng not provided."""
    now = datetime.now().isoformat()
    new_patient = {
        **patient,
        "id": f"pat_{len(MOCK_CLIENTS) + 1:03d}",
        "created_at": now,
        "updated_at": now,
    }
    if new_patient.get("address") and new_patient.get("latitude") is None:
        coords = await geocode_address(new_patient["address"])
        if coords:
            new_patient["longitude"], new_patient["latitude"] = coords
    MOCK_CLIENTS.append(new_patient)
    return new_patient

@app.get("/clients/{client_id}")
async def get_patient(client_id: str, payload: dict = Depends(verify_token)):
    """Get patient by ID"""
    patient = next((p for p in MOCK_CLIENTS if p["id"] == client_id), None)
    if not patient:
        raise HTTPException(status_code=404, detail="Client non trouvé")
    return patient

@app.put("/clients/{client_id}")
async def update_patient(client_id: str, patient: dict, payload: dict = Depends(verify_token)):
    """Update patient.

    Sémantique PATCH : un champ envoyé à null est ignoré (non touché). Pour vider
    un champ, envoyer une chaîne vide.

    Si l'adresse change :
      - re-géocode l'adresse (sauf si lat/lng forcés explicitement)
      - sync les visites futures (status=scheduled ET scheduled_at >= maintenant)
        avec la nouvelle adresse + coords. Les visites passées/en cours/terminées
        gardent leur snapshot historique pour préserver la facturation et l'audit.
    """
    patient = {k: v for k, v in patient.items() if v is not None}
    for i, p in enumerate(MOCK_CLIENTS):
        if p["id"] == client_id:
            merged = {**p, **patient, "updated_at": datetime.now().isoformat()}
            address_changed = (
                "address" in patient and patient["address"] != p.get("address")
            )
            coords_overridden = "latitude" in patient or "longitude" in patient
            if address_changed and not coords_overridden and merged.get("address"):
                coords = await geocode_address(merged["address"])
                if coords:
                    merged["longitude"], merged["latitude"] = coords
                else:
                    merged["latitude"] = None
                    merged["longitude"] = None
            MOCK_CLIENTS[i] = merged

            synced_visits = 0
            if address_changed:
                now = datetime.now()
                new_addr = merged.get("address")
                new_lat = merged.get("latitude")
                new_lng = merged.get("longitude")
                for v in MOCK_SESSIONS:
                    if v["client_id"] != client_id:
                        continue
                    if v.get("status") != "scheduled":
                        continue
                    scheduled_at_raw = v.get("scheduled_at")
                    try:
                        scheduled_at = datetime.fromisoformat(scheduled_at_raw)
                    except (TypeError, ValueError):
                        continue
                    if scheduled_at < now:
                        continue
                    if new_addr is not None:
                        v["address"] = new_addr
                    v["latitude"] = new_lat
                    v["longitude"] = new_lng
                    v["updated_at"] = datetime.now().isoformat()
                    synced_visits += 1
            return {**merged, "synced_future_visits": synced_visits}
    raise HTTPException(status_code=404, detail="Client non trouvé")


@app.delete("/clients/{client_id}")
async def archive_patient(
    client_id: str,
    request: Request,
    payload: dict = Depends(verify_token),
):
    """Archive (soft-delete) un patient.

    - Le patient sort de la liste principale, reste consultable via ?archived=true.
    - TOUTES ses visites status=scheduled sont SUPPRIMÉES (hard delete) —
      elles n'ont aucune valeur d'audit car elles n'ont jamais eu lieu.
    - Les visites in_progress / completed / cancelled sont préservées (audit +
      facturation + room d'archives).
    - Réversible via POST /patients/{id}/restore, mais les visites supprimées
      ne sont pas restaurées.
    """
    for p in MOCK_CLIENTS:
        if p["id"] == client_id:
            if p.get("archived_at"):
                raise HTTPException(status_code=409, detail="Client déjà archivé")
            now_iso = datetime.now().isoformat()
            p["archived_at"] = now_iso
            p["updated_at"] = now_iso

            before = len(MOCK_SESSIONS)
            MOCK_SESSIONS[:] = [
                v for v in MOCK_SESSIONS
                if not (
                    v["client_id"] == client_id and v.get("status") == "scheduled"
                )
            ]
            deleted = before - len(MOCK_SESSIONS)

            _log_audit(
                nurse_id=payload.get("sub"),
                entity_type="clients",
                entity_id=client_id,
                action="delete",
                changes={"deleted_scheduled_visits": deleted},
                request=request,
            )
            return {
                "message": "Client archivé",
                "client_id": client_id,
                "deleted_scheduled_visits": deleted,
            }
    raise HTTPException(status_code=404, detail="Client non trouvé")


@app.post("/clients/{client_id}/restore")
async def restore_patient(client_id: str, payload: dict = Depends(verify_token)):
    """Restaure un patient archivé. Ne ressuscite PAS les visites annulées
    automatiquement par l'archivage — le soignant doit les recréer si besoin."""
    for p in MOCK_CLIENTS:
        if p["id"] == client_id:
            if not p.get("archived_at"):
                raise HTTPException(status_code=409, detail="Client déjà actif")
            p["archived_at"] = None
            p["updated_at"] = datetime.now().isoformat()
            return {"message": "Client restauré", "client_id": client_id}
    raise HTTPException(status_code=404, detail="Client non trouvé")

# Session Endpoints
@app.get("/sessions")
async def list_visits(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    visit_status: Optional[str] = None,
    client_id: Optional[str] = None,
    payload: dict = Depends(verify_token)
):
    """List visits for the current provider"""
    results = MOCK_SESSIONS
    if visit_status:
        results = [v for v in results if v["status"] == visit_status]
    if client_id:
        results = [v for v in results if v["client_id"] == client_id]
    return [_enrich_visit(v) for v in results]

@app.post("/sessions", status_code=status.HTTP_201_CREATED)
async def create_visit(visit: dict, payload: dict = Depends(verify_token)):
    """Create a new visit. Inherits lat/lng from the patient when not provided."""
    now = datetime.now().isoformat()
    new_visit = {
        **visit,
        "id": f"vis_{len(MOCK_SESSIONS) + 1:03d}",
        "nurse_id": payload.get("sub"),
        "created_at": now,
        "updated_at": now,
    }
    if new_visit.get("latitude") is None or new_visit.get("longitude") is None:
        patient = next(
            (p for p in MOCK_CLIENTS if p["id"] == new_visit.get("client_id")),
            None,
        )
        if patient and patient.get("latitude") and patient.get("longitude"):
            new_visit["latitude"] = patient["latitude"]
            new_visit["longitude"] = patient["longitude"]
    MOCK_SESSIONS.append(new_visit)
    return new_visit

@app.get("/sessions/{session_id}")
async def get_visit(session_id: str, payload: dict = Depends(verify_token)):
    """Get visit by ID"""
    visit = next((v for v in MOCK_SESSIONS if v["id"] == session_id), None)
    if not visit:
        raise HTTPException(status_code=404, detail="Session non trouvée")
    return _enrich_visit(visit)

@app.put("/sessions/{session_id}")
async def update_visit(session_id: str, visit: dict, payload: dict = Depends(verify_token)):
    """Update visit. Champ envoyé à null = non touché (PATCH-like)."""
    visit = {k: v for k, v in visit.items() if v is not None}
    for i, v in enumerate(MOCK_SESSIONS):
        if v["id"] == session_id:
            MOCK_SESSIONS[i] = {**v, **visit, "updated_at": datetime.now().isoformat()}
            return _enrich_visit(MOCK_SESSIONS[i])
    raise HTTPException(status_code=404, detail="Session non trouvée")

@app.delete("/sessions/{session_id}")
async def delete_visit(session_id: str, payload: dict = Depends(verify_token)):
    """Annulation de visite (soft delete via status=cancelled).

    On préserve la trace dans MOCK_SESSIONS pour l'audit et les rapports.
    Une session déjà terminée ne peut pas être annulée (409).
    """
    for v in MOCK_SESSIONS:
        if v["id"] == session_id:
            if v.get("status") == "completed":
                raise HTTPException(
                    status_code=409,
                    detail="Une session terminée ne peut pas être annulée",
                )
            v["status"] = "cancelled"
            v["updated_at"] = datetime.now().isoformat()
            return {"message": "Session annulée", "session_id": session_id}
    raise HTTPException(status_code=404, detail="Session non trouvée")

@app.post("/sessions/{session_id}/start")
async def start_visit(
    session_id: str,
    request: Request,
    payload: dict = Depends(verify_token),
):
    """Clock-in: marque le début effectif de la visite (statut + timestamp).

    Idempotent : ne réécrit pas started_at si déjà défini.
    """
    now = datetime.now().isoformat()
    for v in MOCK_SESSIONS:
        if v["id"] == session_id:
            v["status"] = "in_progress"
            if not v.get("started_at"):
                v["started_at"] = now
            v["updated_at"] = now
            _log_audit(
                nurse_id=payload.get("sub"),
                entity_type="sessions",
                entity_id=session_id,
                action="update",
                changes={"status": "in_progress", "started_at": v["started_at"]},
                request=request,
            )
            return {
                "message": "Session démarrée",
                "session_id": session_id,
                "started_at": v["started_at"],
            }
    raise HTTPException(status_code=404, detail="Session non trouvée")

@app.post("/sessions/{session_id}/complete")
async def complete_visit(
    session_id: str,
    request: Request,
    payload: dict = Depends(verify_token),
):
    """Clock-out: marque la fin de la visite (statut + timestamp)."""
    now = datetime.now().isoformat()
    for v in MOCK_SESSIONS:
        if v["id"] == session_id:
            v["status"] = "completed"
            if not v.get("started_at"):
                v["started_at"] = now
            v["completed_at"] = now
            v["updated_at"] = now
            _log_audit(
                nurse_id=payload.get("sub"),
                entity_type="sessions",
                entity_id=session_id,
                action="update",
                changes={
                    "status": "completed",
                    "started_at": v["started_at"],
                    "completed_at": v["completed_at"],
                },
                request=request,
            )
            return {
                "message": "Session terminée",
                "session_id": session_id,
                "started_at": v["started_at"],
                "completed_at": v["completed_at"],
            }
    raise HTTPException(status_code=404, detail="Session non trouvée")

# Consent Endpoints
@app.get("/formulations")
async def list_formulations(payload: dict = Depends(verify_token)):
    """Catalogue de formulations IV disponibles pour le consentement."""
    return FORMULATIONS


class CreateConsentRequest(BaseModel):
    session_id: str
    standing_order_id: str  # référence réglementaire (preuve d'autorisation)
    checkpoints: List[ConsentCheckpoint]
    signature_image_b64: str
    pdf_b64: Optional[str] = None
    signed_latitude: Optional[float] = None
    signed_longitude: Optional[float] = None
    device_info: Optional[dict] = None


@app.post("/consents", status_code=status.HTTP_201_CREATED)
async def create_consent(
    body: CreateConsentRequest,
    request: Request,
    payload: dict = Depends(verify_token),
):
    """Enregistre un consentement signé, rattaché à une standing_order active.

    Sécurité :
    - L'IP est capturée serveur (anti-spoofing).
    - La standing_order doit appartenir à la nurse authentifiée et être active.
    - Le `formulation_name` et `consent_text` sont **résolus** depuis la standing
      order — le client ne peut pas spoofer un texte de consentement custom.
    - Tous les checkpoints doivent être acceptés.
    """
    if not all(c.accepted for c in body.checkpoints):
        raise HTTPException(
            status_code=400,
            detail="Tous les checkpoints doivent être acceptés pour signer un consentement.",
        )

    nurse_id = payload.get("sub")
    visit = next((v for v in MOCK_SESSIONS if v["id"] == body.session_id), None)
    if not visit:
        raise HTTPException(status_code=404, detail="Session non trouvée")

    standing_order = next(
        (
            so for so in MOCK_STANDING_ORDERS
            if so["id"] == body.standing_order_id
            and so["nurse_id"] == nurse_id
            and so["is_active"]
        ),
        None,
    )
    if not standing_order:
        raise HTTPException(
            status_code=400,
            detail="Standing order inconnue, inactive ou rattachée à une autre nurse.",
        )

    if any(c["session_id"] == body.session_id for c in MOCK_CONSENTS):
        raise HTTPException(
            status_code=409,
            detail="Un consentement existe déjà pour cette visite.",
        )

    now = datetime.now().isoformat()
    new_id = f"cnt_{len(MOCK_CONSENTS) + 1:04d}"
    ip = request.client.host if request.client else None
    consent = {
        "id": new_id,
        "session_id": body.session_id,
        "client_id": visit["client_id"],
        "nurse_id": nurse_id,
        "standing_order_id": standing_order["id"],
        "formulation_name": standing_order["formulation_name"],
        "consent_text": standing_order["consent_text"],
        "checkpoints": [c.model_dump() for c in body.checkpoints],
        "signature_image_b64": body.signature_image_b64,
        "pdf_b64": body.pdf_b64,
        "signed_at": now,
        "signed_latitude": body.signed_latitude,
        "signed_longitude": body.signed_longitude,
        "ip_address": ip,
        "device_info": body.device_info,
        "created_at": now,
    }
    MOCK_CONSENTS.append(consent)
    visit["consent_id"] = new_id
    visit["updated_at"] = now

    _log_audit(
        nurse_id=nurse_id,
        entity_type="consents",
        entity_id=new_id,
        action="create",
        changes={
            "session_id": body.session_id,
            "standing_order_id": standing_order["id"],
            "client_id": visit["client_id"],
        },
        request=request,
    )

    return _consent_summary(consent)


def _consent_summary(c: dict) -> dict:
    """Réponse allégée : exclut les blobs binaires (signature PNG + PDF base64)
    qui pèsent lourd. Le PDF/signature se récupèrent via les endpoints dédiés."""
    return {
        "id": c["id"],
        "session_id": c["session_id"],
        "client_id": c["client_id"],
        "nurse_id": c["nurse_id"],
        "standing_order_id": c.get("standing_order_id"),
        "formulation_name": c["formulation_name"],
        "checkpoints": c["checkpoints"],
        "signed_at": c["signed_at"],
        "signed_latitude": c.get("signed_latitude"),
        "signed_longitude": c.get("signed_longitude"),
        "ip_address": c.get("ip_address"),
        "device_info": c.get("device_info"),
        "has_pdf": bool(c.get("pdf_b64")),
        "created_at": c["created_at"],
    }


@app.get("/sessions/{session_id}/consent")
async def get_visit_consent(session_id: str, payload: dict = Depends(verify_token)):
    """Récupère le consentement associé à une visite (ou 404)."""
    consent = next((c for c in MOCK_CONSENTS if c["session_id"] == session_id), None)
    if not consent:
        raise HTTPException(status_code=404, detail="Aucun consentement pour cette visite")
    return _consent_summary(consent)


@app.get("/consents/{consent_id}/pdf")
async def get_consent_pdf(consent_id: str, payload: dict = Depends(verify_token)):
    """Renvoie le PDF en base64. Côté Supabase Storage réel, on renverrait une
    URL signée temporaire à la place."""
    consent = next((c for c in MOCK_CONSENTS if c["id"] == consent_id), None)
    if not consent:
        raise HTTPException(status_code=404, detail="Consentement non trouvé")
    if not consent.get("pdf_b64"):
        raise HTTPException(status_code=404, detail="PDF non disponible")
    return {"pdf_b64": consent["pdf_b64"]}


# Audit Logs Endpoints
@app.get("/audit_logs")
async def list_audit_logs(
    entity_type: Optional[str] = None,
    limit: int = 100,
    offset: int = 0,
    payload: dict = Depends(verify_token),
):
    """Retourne les entrées d'audit de la nurse courante, du plus récent au plus
    ancien. HIPAA : append-only, jamais modifié/supprimé côté serveur."""
    nurse_id = payload.get("sub")
    entries = [a for a in MOCK_AUDIT_LOGS if a["nurse_id"] == nurse_id]
    if entity_type:
        entries = [a for a in entries if a["entity_type"] == entity_type]
    entries = sorted(entries, key=lambda a: a["occurred_at"], reverse=True)
    return entries[offset:offset + limit]


# Compliance Endpoints

def _license_status(expiration_date_str: Optional[str]) -> dict:
    """Calcule le statut visuel de la licence (vert/orange/rouge) selon la date
    d'expiration. Brief : vert >90j, orange 30-90j, rouge <30j."""
    if not expiration_date_str:
        return {"days_remaining": None, "status": "unknown"}
    try:
        exp = datetime.strptime(expiration_date_str, "%Y-%m-%d").date()
    except ValueError:
        return {"days_remaining": None, "status": "unknown"}
    days = (exp - datetime.now().date()).days
    if days < 0:
        status = "expired"
    elif days < 30:
        status = "critical"
    elif days < 90:
        status = "warning"
    else:
        status = "ok"
    return {"days_remaining": days, "status": status, "expiration_date": expiration_date_str}


def _expiration_status(date_str: Optional[str]) -> str:
    """Variante pour les contrats MD et standing orders (mêmes seuils)."""
    if not date_str:
        return "unknown"
    try:
        exp = datetime.strptime(date_str, "%Y-%m-%d").date()
    except ValueError:
        return "unknown"
    days = (exp - datetime.now().date()).days
    if days < 0:
        return "expired"
    if days < 30:
        return "critical"
    if days < 90:
        return "warning"
    return "ok"


@app.get("/compliance/dashboard")
async def compliance_dashboard(payload: dict = Depends(verify_token)):
    """Vue agrégée pour l'écran Compliance : licence + MD + standing orders + alertes."""
    nurse_id = payload.get("sub")
    user = next(
        (u for u in MOCK_USERS.values() if u["id"] == nurse_id),
        None,
    )

    license_info = None
    if user:
        s = _license_status(user.get("license_expiration_date"))
        license_info = {
            "license_number": user.get("license_number"),
            "license_type": user.get("license_type"),
            "state_code": user.get("state_code"),
            "expiration_date": user.get("license_expiration_date"),
            "days_remaining": s["days_remaining"],
            "status": s["status"],
        }

    md = next(
        (m for m in MOCK_MEDICAL_DIRECTORS if m["nurse_id"] == nurse_id and m["is_active"]),
        None,
    )
    md_view = None
    if md:
        md_view = {
            **md,
            "contract_status": _expiration_status(md.get("contract_end_date")),
            "next_audit_status": _expiration_status(md.get("next_audit_date")),
        }

    orders = [
        {
            **so,
            "expiration_status": _expiration_status(so.get("expires_at")),
        }
        for so in MOCK_STANDING_ORDERS
        if so["nurse_id"] == nurse_id and so["is_active"]
    ]
    orders_expiring_soon = sum(
        1 for o in orders if o["expiration_status"] in ("warning", "critical", "expired")
    )

    alerts = [
        a for a in MOCK_COMPLIANCE_ALERTS
        if a["nurse_id"] == nurse_id and a.get("resolved_at") is None
    ]
    unread_alerts = sum(1 for a in alerts if a.get("acknowledged_at") is None)

    return {
        "license": license_info,
        "medical_director": md_view,
        "standing_orders": orders,
        "standing_orders_expiring_soon": orders_expiring_soon,
        "alerts": alerts,
        "unread_alerts": unread_alerts,
    }


@app.get("/compliance/standing_orders")
async def list_standing_orders(payload: dict = Depends(verify_token)):
    nurse_id = payload.get("sub")
    return [so for so in MOCK_STANDING_ORDERS if so["nurse_id"] == nurse_id]


class CreateMedicalDirectorRequest(BaseModel):
    first_name: str
    last_name: str
    email: str
    license_number: str
    state_code: str
    contract_start_date: str
    contract_end_date: Optional[str] = None
    audit_frequency_days: int = 30
    next_audit_date: Optional[str] = None


@app.post("/compliance/medical_directors", status_code=status.HTTP_201_CREATED)
async def create_medical_director(
    body: CreateMedicalDirectorRequest,
    request: Request,
    payload: dict = Depends(verify_token),
):
    """Créé un MD actif. Désactive les MDs précédemment actifs de la nurse
    (un seul MD couvre la pratique à un instant T par défaut)."""
    nurse_id = payload.get("sub")
    for md in MOCK_MEDICAL_DIRECTORS:
        if md["nurse_id"] == nurse_id and md["is_active"]:
            md["is_active"] = False
    new_id = f"md_{len(MOCK_MEDICAL_DIRECTORS) + 1:03d}"
    md = {
        "id": new_id,
        "nurse_id": nurse_id,
        "first_name": body.first_name,
        "last_name": body.last_name,
        "email": body.email,
        "license_number": body.license_number,
        "state_code": body.state_code,
        "contract_start_date": body.contract_start_date,
        "contract_end_date": body.contract_end_date,
        "audit_frequency_days": body.audit_frequency_days,
        "next_audit_date": body.next_audit_date,
        "is_active": True,
        "created_at": datetime.now().isoformat(),
    }
    MOCK_MEDICAL_DIRECTORS.append(md)
    _log_audit(
        nurse_id=nurse_id,
        entity_type="medical_directors",
        entity_id=new_id,
        action="create",
        changes={"email": body.email, "state_code": body.state_code},
        request=request,
    )
    return md


class CreateStandingOrderRequest(BaseModel):
    formulation_name: str  # doit matcher un nom de FORMULATIONS (template)
    medical_director_id: Optional[str] = None  # défaut: le MD actif
    expires_at: Optional[str] = None  # YYYY-MM-DD


@app.post("/compliance/standing_orders", status_code=status.HTTP_201_CREATED)
async def create_standing_order(
    body: CreateStandingOrderRequest,
    request: Request,
    payload: dict = Depends(verify_token),
):
    """Créé une standing order à partir d'un template de formulation. Le
    consent_text est snapshoté depuis le template (immuable une fois créé)."""
    nurse_id = payload.get("sub")
    template = next(
        (f for f in FORMULATIONS if f["name"] == body.formulation_name),
        None,
    )
    if not template:
        raise HTTPException(
            status_code=400,
            detail=f"Formulation inconnue : {body.formulation_name}. Disponibles : {[f['name'] for f in FORMULATIONS]}",
        )
    md_id = body.medical_director_id
    if md_id is None:
        active_md = next(
            (m for m in MOCK_MEDICAL_DIRECTORS if m["nurse_id"] == nurse_id and m["is_active"]),
            None,
        )
        md_id = active_md["id"] if active_md else None
    new_id = f"so_{len(MOCK_STANDING_ORDERS) + 1:03d}"
    so = {
        "id": new_id,
        "nurse_id": nurse_id,
        "medical_director_id": md_id,
        "formulation_name": template["name"],
        "formulation_category": template["category"],
        "consent_text": template["consent_text"],
        "version": 1,
        "signed_at": datetime.now().isoformat(),
        "expires_at": body.expires_at,
        "is_active": True,
        "created_at": datetime.now().isoformat(),
    }
    MOCK_STANDING_ORDERS.append(so)
    _log_audit(
        nurse_id=nurse_id,
        entity_type="standing_orders",
        entity_id=new_id,
        action="create",
        changes={"formulation_name": template["name"], "medical_director_id": md_id},
        request=request,
    )
    return so


@app.get("/compliance/medical_director")
async def get_medical_director(payload: dict = Depends(verify_token)):
    nurse_id = payload.get("sub")
    md = next(
        (m for m in MOCK_MEDICAL_DIRECTORS if m["nurse_id"] == nurse_id and m["is_active"]),
        None,
    )
    if not md:
        raise HTTPException(status_code=404, detail="Aucun Medical Director actif")
    return md


@app.post("/compliance/alerts/{alert_id}/acknowledge")
async def acknowledge_alert(alert_id: str, payload: dict = Depends(verify_token)):
    nurse_id = payload.get("sub")
    for a in MOCK_COMPLIANCE_ALERTS:
        if a["id"] == alert_id and a["nurse_id"] == nurse_id:
            a["acknowledged_at"] = datetime.now().isoformat()
            return a
    raise HTTPException(status_code=404, detail="Alerte non trouvée")


# Inventory Endpoints (brief-aligned : per-lot tracking)

def _lot_expiration_status(expiration_date: str) -> str:
    """Statut de péremption : ok / warning (<90j) / critical (<15j) / expired."""
    try:
        exp = datetime.strptime(expiration_date, "%Y-%m-%d").date()
    except ValueError:
        return "unknown"
    days = (exp - datetime.now().date()).days
    if days < 0:
        return "expired"
    if days < 15:
        return "critical"
    if days < 90:
        return "warning"
    return "ok"


def _enrich_lot(lot: dict) -> dict:
    """Ajoute expiration_status + days_to_expiry."""
    status = _lot_expiration_status(lot.get("expiration_date", ""))
    try:
        exp = datetime.strptime(lot["expiration_date"], "%Y-%m-%d").date()
        days = (exp - datetime.now().date()).days
    except (ValueError, KeyError):
        days = None
    return {**lot, "expiration_status": status, "days_to_expiry": days}


@app.get("/inventory/lots")
async def list_lots(
    include_depleted: bool = False,
    payload: dict = Depends(verify_token),
):
    """Liste tous les lots du provider courant. Par défaut, exclut les lots
    épuisés (quantity_remaining = 0)."""
    nurse_id = payload.get("sub")
    results = [l for l in MOCK_INVENTORY_LOTS if l["nurse_id"] == nurse_id]
    if not include_depleted:
        results = [l for l in results if l["quantity_remaining"] > 0]
    return [_enrich_lot(l) for l in results]


@app.get("/inventory/products")
async def list_products_grouped(payload: dict = Depends(verify_token)):
    """Agrégation par référence produit : somme des quantités, péremption la
    plus proche, count des lots. Pour la vue liste principale."""
    nurse_id = payload.get("sub")
    lots = [l for l in MOCK_INVENTORY_LOTS if l["nurse_id"] == nurse_id and l["quantity_remaining"] > 0]
    by_product: dict = {}
    for l in lots:
        key = l["product_name"]
        if key not in by_product:
            by_product[key] = {
                "product_name": l["product_name"],
                "product_category": l["product_category"],
                "barcode": l.get("barcode"),
                "total_quantity": 0,
                "lot_count": 0,
                "nearest_expiration": l["expiration_date"],
                "total_value": 0.0,
            }
        agg = by_product[key]
        agg["total_quantity"] += l["quantity_remaining"]
        agg["lot_count"] += 1
        if l["expiration_date"] < agg["nearest_expiration"]:
            agg["nearest_expiration"] = l["expiration_date"]
        if l.get("unit_cost"):
            agg["total_value"] += l["unit_cost"] * l["quantity_remaining"]

    products = list(by_product.values())
    for p in products:
        p["expiration_status"] = _lot_expiration_status(p["nearest_expiration"])
    return products


@app.get("/inventory/lots/{lot_id}")
async def get_lot(lot_id: str, payload: dict = Depends(verify_token)):
    lot = next((l for l in MOCK_INVENTORY_LOTS if l["id"] == lot_id), None)
    if not lot:
        raise HTTPException(status_code=404, detail="Lot non trouvé")
    return _enrich_lot(lot)


@app.post("/inventory/lots", status_code=status.HTTP_201_CREATED)
async def add_lot(lot: dict, payload: dict = Depends(verify_token)):
    """Ajoute un lot après scan/saisie. Crée aussi une transaction 'reception'
    pour la traçabilité."""
    new_id = f"lot_{len(MOCK_INVENTORY_LOTS) + 1:03d}"
    now_iso = datetime.now().isoformat()
    qty = int(lot.get("quantity_initial", 1))
    new_lot = {
        "id": new_id,
        "nurse_id": payload.get("sub"),
        "product_name": lot.get("product_name", ""),
        "product_category": lot.get("product_category", "other"),
        "barcode": lot.get("barcode"),
        "lot_number": lot.get("lot_number", ""),
        "expiration_date": lot.get("expiration_date", ""),
        "quantity_initial": qty,
        "quantity_remaining": qty,
        "unit_cost": lot.get("unit_cost"),
        "supplier": lot.get("supplier"),
        "received_at": lot.get("received_at") or now_iso[:10],
        "notes": lot.get("notes"),
        "created_at": now_iso,
    }
    MOCK_INVENTORY_LOTS.append(new_lot)
    MOCK_INVENTORY_TRANSACTIONS.append({
        "id": f"itx_{len(MOCK_INVENTORY_TRANSACTIONS) + 1:04d}",
        "inventory_lot_id": new_id,
        "session_id": None,
        "transaction_type": "reception",
        "quantity_change": qty,
        "notes": "Réception (scan/saisie)",
        "created_at": now_iso,
    })
    return _enrich_lot(new_lot)


class RecordUsageRequest(BaseModel):
    lot_id: str
    session_id: Optional[str] = None
    quantity: int = 1
    notes: Optional[str] = None


@app.post("/inventory/usage")
async def record_usage(
    body: RecordUsageRequest,
    request: Request,
    payload: dict = Depends(verify_token),
):
    """Décrémente un lot après usage en session. Crée la transaction associée."""
    lot = next((l for l in MOCK_INVENTORY_LOTS if l["id"] == body.lot_id), None)
    if not lot:
        raise HTTPException(status_code=404, detail="Lot non trouvé")
    if body.quantity <= 0:
        raise HTTPException(status_code=400, detail="Quantité doit être > 0")
    if lot["quantity_remaining"] < body.quantity:
        raise HTTPException(
            status_code=409,
            detail=f"Stock insuffisant ({lot['quantity_remaining']} restant)",
        )
    lot["quantity_remaining"] -= body.quantity
    now_iso = datetime.now().isoformat()
    txn = {
        "id": f"itx_{len(MOCK_INVENTORY_TRANSACTIONS) + 1:04d}",
        "inventory_lot_id": body.lot_id,
        "session_id": body.session_id,
        "transaction_type": "usage",
        "quantity_change": -body.quantity,
        "notes": body.notes,
        "created_at": now_iso,
    }
    MOCK_INVENTORY_TRANSACTIONS.append(txn)
    _log_audit(
        nurse_id=payload.get("sub"),
        entity_type="inventory_transactions",
        entity_id=txn["id"],
        action="create",
        changes={
            "lot_id": body.lot_id,
            "session_id": body.session_id,
            "quantity": body.quantity,
        },
        request=request,
    )
    return {"lot": _enrich_lot(lot), "transaction": txn}


@app.get("/inventory/lots/{lot_id}/transactions")
async def list_lot_transactions(lot_id: str, payload: dict = Depends(verify_token)):
    """Historique des mouvements pour un lot donné — audit + rapport."""
    return [t for t in MOCK_INVENTORY_TRANSACTIONS if t["inventory_lot_id"] == lot_id]


@app.get("/inventory/by_barcode/{barcode}")
async def find_lots_by_barcode(barcode: str, payload: dict = Depends(verify_token)):
    """Recherche par code-barres scanné. Utilisé pour pré-remplir le formulaire
    de saisie quand on rescanne un produit déjà connu."""
    nurse_id = payload.get("sub")
    return [
        _enrich_lot(l) for l in MOCK_INVENTORY_LOTS
        if l["nurse_id"] == nurse_id and l.get("barcode") == barcode
    ]

# Invoice Endpoints
@app.get("/invoices")
async def list_invoices(
    invoice_status: Optional[str] = None,
    payload: dict = Depends(verify_token)
):
    """List invoices for the current provider"""
    results = MOCK_INVOICES
    if invoice_status:
        results = [inv for inv in results if inv["status"] == invoice_status]
    return results

@app.post("/invoices", status_code=status.HTTP_201_CREATED)
async def create_invoice(invoice: dict, payload: dict = Depends(verify_token)):
    """Create a new invoice"""
    new_invoice = {**invoice, "id": f"inv_{len(MOCK_INVOICES) + 1:03d}", "nurse_id": payload.get("sub"), "created_at": datetime.now().isoformat(), "updated_at": datetime.now().isoformat()}
    MOCK_INVOICES.append(new_invoice)
    return new_invoice

@app.get("/invoices/{invoice_id}")
async def get_invoice(invoice_id: str, payload: dict = Depends(verify_token)):
    """Get invoice by ID"""
    invoice = next((inv for inv in MOCK_INVOICES if inv["id"] == invoice_id), None)
    if not invoice:
        raise HTTPException(status_code=404, detail="Facture non trouvée")
    return invoice

# Stripe Integration Endpoints
@app.post("/stripe/create-payment-intent")
async def create_payment_intent(
    amount: int,  # in cents
    client_id: str,
    session_id: str,
    payload: dict = Depends(verify_token)
):
    """Create a Stripe payment intent"""
    # Implementation uses Stripe SDK
    return {
        "client_secret": "payment_intent_client_secret",
        "payment_method_types": ["card"]
    }

@app.post("/stripe/webhook")
async def stripe_webhook(request: Request):
    """Stripe webhook endpoint for payment events"""
    # Implementation handles Stripe events
    return {"received": True}

# Reporting Endpoints
def _enrich_visit(visit: dict) -> dict:
    """Attach client_name to a visit dict (denormalized join)"""
    patient = next((p for p in MOCK_CLIENTS if p["id"] == visit.get("client_id")), None)
    name = f"{patient['first_name']} {patient['last_name']}" if patient else None
    return {**visit, "client_name": name}

LOW_STOCK_THRESHOLD = 5  # par référence produit (somme tous lots)


def _low_stock_products(nurse_id: str) -> List[dict]:
    """Agrège les lots actifs par référence et renvoie celles sous le seuil."""
    by_product: dict = {}
    for lot in MOCK_INVENTORY_LOTS:
        if lot["nurse_id"] != nurse_id or lot["quantity_remaining"] <= 0:
            continue
        key = lot["product_name"]
        if key not in by_product:
            by_product[key] = {
                "product_name": lot["product_name"],
                "product_category": lot["product_category"],
                "total_quantity": 0,
                "nearest_expiration": lot["expiration_date"],
            }
        agg = by_product[key]
        agg["total_quantity"] += lot["quantity_remaining"]
        if lot["expiration_date"] < agg["nearest_expiration"]:
            agg["nearest_expiration"] = lot["expiration_date"]
    return [p for p in by_product.values() if p["total_quantity"] <= LOW_STOCK_THRESHOLD]


@app.get("/reports/dashboard")
async def get_dashboard(payload: dict = Depends(verify_token)):
    """Get dashboard statistics"""
    nurse_id = payload.get("sub")
    low_stock = _low_stock_products(nurse_id)
    today_visits = [_enrich_visit(v) for v in MOCK_SESSIONS if v["status"] in ("scheduled", "in_progress")]
    today_revenue = sum(v["total_amount"] for v in MOCK_SESSIONS if v["status"] == "completed")
    return {
        "total_patients": len(MOCK_CLIENTS),
        "today_visits": len(today_visits),
        "pending_invoices": len([i for i in MOCK_INVOICES if i["status"] == "sent"]),
        "low_stock_alerts": len(low_stock),
        "monthly_revenue": 4250.00,
        "today_revenue": today_revenue,
        "visits_today": today_visits,
        "low_stock_items": low_stock,
    }

@app.get("/reports/revenue")
async def get_revenue_report(
    start_date: str,
    end_date: str,
    payload: dict = Depends(verify_token)
):
    """Get revenue report"""
    return {
        "total_revenue": 50000.00,
        "total_visits": 500,
        "average_visit_value": 100.00,
        "by_visit_type": {
            "IV_Hydration": 30000.00,
            "Post_Op": 15000.00,
            "Primary_Care": 5000.00
        }
    }

@app.get("/reports/stock")
async def get_stock_report(payload: dict = Depends(verify_token)):
    """Get stock report"""
    return {
        "total_items": 100,
        "low_stock_items": 5,
        "expired_items": 0,
        "total_value": 5000.00
    }

class OptimizeVisitInput(BaseModel):
    """Modèle léger pour POST /optimize/routes. On n'a besoin que de l'id et
    des coords (lat/lng directs ou résolus depuis le patient). Évite d'imposer
    aux clients d'envoyer tous les champs d'une Session complète (nurse_id,
    updated_at, etc.) qui sont gérés côté serveur."""
    id: str
    client_id: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

    model_config = {"extra": "ignore"}


# Route Optimization Endpoint
@app.post("/optimize/routes")
async def optimize_routes(
    visits: List[OptimizeVisitInput],
    payload: dict = Depends(verify_token),
):
    """Optimize visit routes via Mapbox Optimization v1 + return road geometry.

    Falls back to input order with a straight-line geometry when:
      - MAPBOX_ACCESS_TOKEN is missing
      - fewer than 2 visits have coordinates
      - Mapbox API returns an error
    """
    if not visits:
        return {
            "optimized_route": [],
            "route_geometry": [],
            "total_distance_m": 0,
            "total_duration_s": 0,
        }

    # Resolve coords: prefer visit's own lat/lng, fall back to patient's.
    resolved: List[Tuple[Session, Optional[Tuple[float, float]]]] = []
    for v in visits:
        coords: Optional[Tuple[float, float]] = None
        if v.latitude is not None and v.longitude is not None:
            coords = (v.longitude, v.latitude)
        else:
            patient = next(
                (p for p in MOCK_CLIENTS if p["id"] == v.client_id), None
            )
            if patient and patient.get("latitude") and patient.get("longitude"):
                coords = (patient["longitude"], patient["latitude"])
        resolved.append((v, coords))

    visits_with_coords = [(v, c) for v, c in resolved if c is not None]

    # Pas assez de coords → on renvoie l'ordre d'entrée tel quel.
    if len(visits_with_coords) < 2:
        return {
            "optimized_route": [
                {"session_id": v.id, "order": i}
                for i, (v, _) in enumerate(resolved)
            ],
            "route_geometry": [list(c) for _, c in resolved if c is not None],
            "total_distance_m": 0,
            "total_duration_s": 0,
            "warning": "Coordonnées insuffisantes — ordre d'entrée conservé",
        }

    coords_list = [c for _, c in visits_with_coords]
    result = await optimize_route_mapbox(coords_list)

    if result is None:
        # Mapbox indispo : passthrough + ligne droite reliant les stops.
        return {
            "optimized_route": [
                {"session_id": v.id, "order": i}
                for i, (v, _) in enumerate(visits_with_coords)
            ],
            "route_geometry": [list(c) for c in coords_list],
            "total_distance_m": 0,
            "total_duration_s": 0,
            "warning": "Optimisation Mapbox indisponible — ordre d'entrée conservé",
        }

    return {
        "optimized_route": [
            {"session_id": visits_with_coords[idx][0].id, "order": position}
            for position, idx in enumerate(result["order"])
        ],
        "route_geometry": result["geometry"],
        "total_distance_m": result["distance_m"],
        "total_duration_s": result["duration_s"],
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
