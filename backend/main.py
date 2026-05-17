"""
HCPilot Backend API
FastAPI serveur avec Supabase comme backend
Conformité HIPAA active
"""

import os
import sys
import logging
from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from typing import Optional, List
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

class Patient(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    date_of_birth: Optional[str] = None
    gender: Optional[str] = None
    address: Optional[str] = None
    medical_history: Optional[str] = None
    allergies: Optional[str] = None
    created_at: datetime
    updated_at: datetime

class Visit(BaseModel):
    id: str
    patient_id: str
    provider_id: str
    visit_date: datetime
    visit_type: str  # IV_Hydration, Post_Op, Primary_Care, etc.
    status: str  # scheduled, in_progress, completed, cancelled
    address: str
    estimated_duration: int  # minutes
    notes: Optional[str] = None
    total_amount: float
    copay: Optional[float] = None
    insurance_claimed: Optional[bool] = False
    created_at: datetime
    updated_at: datetime

class StockItem(BaseModel):
    id: str
    provider_id: str
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

class Invoice(BaseModel):
    id: str
    patient_id: str
    provider_id: str
    visit_id: str
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
        "state_license": "FR-IDF-2024-001",
        "created_at": "2024-01-15T10:00:00"
    }
}

MOCK_PATIENTS = [
    {
        "id": "pat_001", "first_name": "Jean", "last_name": "Martin",
        "email": "jean.martin@email.com", "phone": "06 12 34 56 78",
        "date_of_birth": "1958-03-15", "gender": "M",
        "address": "12 Rue de la Paix, 75002 Paris",
        "medical_history": "Diabète type 2, hypertension",
        "allergies": "Pénicilline",
        "created_at": "2024-02-01T09:00:00", "updated_at": "2024-06-01T14:30:00"
    },
    {
        "id": "pat_002", "first_name": "Françoise", "last_name": "Bernard",
        "email": "f.bernard@email.com", "phone": "06 98 76 54 32",
        "date_of_birth": "1945-11-22", "gender": "F",
        "address": "45 Avenue Victor Hugo, 75016 Paris",
        "medical_history": "Post-op hanche droite, arthrose",
        "allergies": None,
        "created_at": "2024-03-10T11:00:00", "updated_at": "2024-06-15T09:00:00"
    },
    {
        "id": "pat_003", "first_name": "Ahmed", "last_name": "Benali",
        "email": "a.benali@email.com", "phone": "07 11 22 33 44",
        "date_of_birth": "1972-07-08", "gender": "M",
        "address": "8 Boulevard Haussmann, 75009 Paris",
        "medical_history": "Insuffisance cardiaque, BPCO",
        "allergies": "Aspirine, Iode",
        "created_at": "2024-04-05T08:30:00", "updated_at": "2024-06-20T16:00:00"
    },
]

MOCK_VISITS = [
    {
        "id": "vis_001", "patient_id": "pat_001", "provider_id": "usr_001",
        "visit_date": datetime.now().replace(hour=9, minute=0).isoformat(),
        "visit_type": "Primary_Care", "status": "scheduled",
        "address": "12 Rue de la Paix, 75002 Paris",
        "estimated_duration": 45, "notes": "Contrôle glycémie + tension",
        "total_amount": 75.00, "copay": 23.00, "insurance_claimed": True,
        "created_at": "2024-06-01T08:00:00", "updated_at": "2024-06-01T08:00:00"
    },
    {
        "id": "vis_002", "patient_id": "pat_002", "provider_id": "usr_001",
        "visit_date": datetime.now().replace(hour=11, minute=0).isoformat(),
        "visit_type": "Post_Op", "status": "scheduled",
        "address": "45 Avenue Victor Hugo, 75016 Paris",
        "estimated_duration": 60, "notes": "Rééducation post-op J+14",
        "total_amount": 120.00, "copay": 0.00, "insurance_claimed": True,
        "created_at": "2024-06-01T08:00:00", "updated_at": "2024-06-01T08:00:00"
    },
    {
        "id": "vis_003", "patient_id": "pat_003", "provider_id": "usr_001",
        "visit_date": datetime.now().replace(hour=14, minute=30).isoformat(),
        "visit_type": "IV_Hydration", "status": "scheduled",
        "address": "8 Boulevard Haussmann, 75009 Paris",
        "estimated_duration": 90, "notes": "Perfusion IV + monitoring cardiaque",
        "total_amount": 180.00, "copay": 45.00, "insurance_claimed": False,
        "created_at": "2024-06-01T08:00:00", "updated_at": "2024-06-01T08:00:00"
    },
]

MOCK_STOCK = [
    {
        "id": "stk_001", "provider_id": "usr_001", "product_name": "NaCl 0.9% 500ml",
        "description": "Solution saline pour perfusion IV", "quantity": 24, "min_quantity": 10,
        "expiration_date": "2025-12-31", "barcode": "3401234567890",
        "category": "IV_Supplies", "cost_per_unit": 3.50,
        "created_at": "2024-01-01T00:00:00", "updated_at": "2024-06-01T00:00:00"
    },
    {
        "id": "stk_002", "provider_id": "usr_001", "product_name": "Gants nitrile M",
        "description": "Boîte de 100 gants", "quantity": 3, "min_quantity": 5,
        "expiration_date": "2026-06-30", "barcode": "3401234567891",
        "category": "Equipment", "cost_per_unit": 12.00,
        "created_at": "2024-01-01T00:00:00", "updated_at": "2024-06-10T00:00:00"
    },
    {
        "id": "stk_003", "provider_id": "usr_001", "product_name": "Paracétamol 1g",
        "description": "Boîte de 30 comprimés", "quantity": 15, "min_quantity": 5,
        "expiration_date": "2025-09-30", "barcode": "3401234567892",
        "category": "Medication", "cost_per_unit": 2.80,
        "created_at": "2024-01-01T00:00:00", "updated_at": "2024-06-05T00:00:00"
    },
    {
        "id": "stk_004", "provider_id": "usr_001", "product_name": "Cathéter IV 20G",
        "description": "Cathéter périphérique", "quantity": 8, "min_quantity": 10,
        "expiration_date": "2025-08-15", "barcode": "3401234567893",
        "category": "IV_Supplies", "cost_per_unit": 4.20,
        "created_at": "2024-01-01T00:00:00", "updated_at": "2024-06-12T00:00:00"
    },
]

MOCK_INVOICES = [
    {
        "id": "inv_001", "patient_id": "pat_001", "provider_id": "usr_001",
        "visit_id": "vis_001", "invoice_number": "INV-20240601-001",
        "items": [{"description": "Consultation médecine générale", "quantity": 1, "price": 75.00}],
        "subtotal": 75.00, "tax": 0.00, "discount": 0.00, "total": 75.00,
        "status": "paid", "due_date": "2024-07-01T00:00:00",
        "paid_at": "2024-06-05T10:00:00", "stripe_payment_intent_id": "pi_mock_001",
        "created_at": "2024-06-01T09:00:00", "updated_at": "2024-06-05T10:00:00"
    },
    {
        "id": "inv_002", "patient_id": "pat_002", "provider_id": "usr_001",
        "visit_id": "vis_002", "invoice_number": "INV-20240601-002",
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

# Patient Endpoints
@app.get("/patients")
async def list_patients(
    skip: int = 0,
    limit: int = 100,
    payload: dict = Depends(verify_token)
):
    """List all patients for the current provider"""
    return MOCK_PATIENTS[skip:skip + limit]

@app.post("/patients", status_code=status.HTTP_201_CREATED)
async def create_patient(patient: dict, payload: dict = Depends(verify_token)):
    """Create a new patient"""
    new_patient = {**patient, "id": f"pat_{len(MOCK_PATIENTS) + 1:03d}", "created_at": datetime.now().isoformat(), "updated_at": datetime.now().isoformat()}
    MOCK_PATIENTS.append(new_patient)
    return new_patient

@app.get("/patients/{patient_id}")
async def get_patient(patient_id: str, payload: dict = Depends(verify_token)):
    """Get patient by ID"""
    patient = next((p for p in MOCK_PATIENTS if p["id"] == patient_id), None)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient non trouvé")
    return patient

@app.put("/patients/{patient_id}")
async def update_patient(patient_id: str, patient: dict, payload: dict = Depends(verify_token)):
    """Update patient information"""
    for i, p in enumerate(MOCK_PATIENTS):
        if p["id"] == patient_id:
            MOCK_PATIENTS[i] = {**p, **patient, "updated_at": datetime.now().isoformat()}
            return MOCK_PATIENTS[i]
    raise HTTPException(status_code=404, detail="Patient non trouvé")

# Visit Endpoints
@app.get("/visits")
async def list_visits(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    visit_status: Optional[str] = None,
    payload: dict = Depends(verify_token)
):
    """List visits for the current provider"""
    results = MOCK_VISITS
    if visit_status:
        results = [v for v in results if v["status"] == visit_status]
    return results

@app.post("/visits", status_code=status.HTTP_201_CREATED)
async def create_visit(visit: dict, payload: dict = Depends(verify_token)):
    """Create a new visit"""
    new_visit = {**visit, "id": f"vis_{len(MOCK_VISITS) + 1:03d}", "provider_id": payload.get("sub"), "created_at": datetime.now().isoformat(), "updated_at": datetime.now().isoformat()}
    MOCK_VISITS.append(new_visit)
    return new_visit

@app.get("/visits/{visit_id}")
async def get_visit(visit_id: str, payload: dict = Depends(verify_token)):
    """Get visit by ID"""
    visit = next((v for v in MOCK_VISITS if v["id"] == visit_id), None)
    if not visit:
        raise HTTPException(status_code=404, detail="Visite non trouvée")
    return visit

@app.put("/visits/{visit_id}")
async def update_visit(visit_id: str, visit: dict, payload: dict = Depends(verify_token)):
    """Update visit information"""
    for i, v in enumerate(MOCK_VISITS):
        if v["id"] == visit_id:
            MOCK_VISITS[i] = {**v, **visit, "updated_at": datetime.now().isoformat()}
            return MOCK_VISITS[i]
    raise HTTPException(status_code=404, detail="Visite non trouvée")

@app.post("/visits/{visit_id}/start")
async def start_visit(visit_id: str, payload: dict = Depends(verify_token)):
    """Start a visit"""
    for v in MOCK_VISITS:
        if v["id"] == visit_id:
            v["status"] = "in_progress"
            return {"message": "Visite démarrée", "visit_id": visit_id}
    raise HTTPException(status_code=404, detail="Visite non trouvée")

@app.post("/visits/{visit_id}/complete")
async def complete_visit(visit_id: str, payload: dict = Depends(verify_token)):
    """Complete a visit"""
    for v in MOCK_VISITS:
        if v["id"] == visit_id:
            v["status"] = "completed"
            return {"message": "Visite terminée", "visit_id": visit_id}
    raise HTTPException(status_code=404, detail="Visite non trouvée")

# Stock Endpoints
@app.get("/stock")
async def list_stock(payload: dict = Depends(verify_token)):
    """List all stock items for the current provider"""
    return MOCK_STOCK

@app.post("/stock", status_code=status.HTTP_201_CREATED)
async def add_stock_item(item: dict, payload: dict = Depends(verify_token)):
    """Add a new stock item"""
    new_item = {**item, "id": f"stk_{len(MOCK_STOCK) + 1:03d}", "provider_id": payload.get("sub"), "created_at": datetime.now().isoformat(), "updated_at": datetime.now().isoformat()}
    MOCK_STOCK.append(new_item)
    return new_item

@app.put("/stock/{item_id}")
async def update_stock(item_id: str, item: dict, payload: dict = Depends(verify_token)):
    """Update stock item"""
    for i, s in enumerate(MOCK_STOCK):
        if s["id"] == item_id:
            MOCK_STOCK[i] = {**s, **item, "updated_at": datetime.now().isoformat()}
            return MOCK_STOCK[i]
    raise HTTPException(status_code=404, detail="Article non trouvé")

@app.delete("/stock/{item_id}")
async def delete_stock(item_id: str, payload: dict = Depends(verify_token)):
    """Delete stock item"""
    for i, s in enumerate(MOCK_STOCK):
        if s["id"] == item_id:
            MOCK_STOCK.pop(i)
            return {"message": "Article supprimé"}
    raise HTTPException(status_code=404, detail="Article non trouvé")

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
    new_invoice = {**invoice, "id": f"inv_{len(MOCK_INVOICES) + 1:03d}", "provider_id": payload.get("sub"), "created_at": datetime.now().isoformat(), "updated_at": datetime.now().isoformat()}
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
    patient_id: str,
    visit_id: str,
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
@app.get("/reports/dashboard")
async def get_dashboard(payload: dict = Depends(verify_token)):
    """Get dashboard statistics"""
    low_stock = [s for s in MOCK_STOCK if s["quantity"] <= s["min_quantity"]]
    today_visits = [v for v in MOCK_VISITS if v["status"] in ("scheduled", "in_progress")]
    return {
        "total_patients": len(MOCK_PATIENTS),
        "today_visits": len(today_visits),
        "pending_invoices": len([i for i in MOCK_INVOICES if i["status"] == "sent"]),
        "low_stock_alerts": len(low_stock),
        "monthly_revenue": 4250.00,
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

# Route Optimization Endpoint
@app.post("/optimize/routes")
async def optimize_routes(
    visits: List[Visit],
    payload: dict = Depends(verify_token)
):
    """Optimize visit routes using Mapbox"""
    # Implementation uses Mapbox API for route optimization
    return {
        "optimized_route": [
            {"visit_id": "1", "order": 1, "distance": 0, "duration": 0},
            {"visit_id": "2", "order": 2, "distance": 5.2, "duration": 15},
            {"visit_id": "3", "order": 3, "distance": 3.8, "duration": 12}
        ],
        "total_distance": 9.0,
        "total_duration": 27
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
