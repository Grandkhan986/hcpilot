# HCPilot Backend Setup

## Prerequisites

- Python 3.9+
- PostgreSQL/Supabase database
- pip

## Installation

1. Create a virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On macOS/Linux
venv\Scripts\activate     # On Windows
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment variables:
```bash
cp .env.example .env
# Edit .env with your Supabase credentials
```

4. Run the application:
```bash
# Development mode with auto-reload
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Production mode
uvicorn main:app --host 0.0.0.0 --port 8000
```

## API Endpoints

### Authentication
- `POST /auth/register` - Register new user
- `POST /auth/login` - Login and get JWT token
- `POST /auth/logout` - Logout user

### Patients
- `GET /patients` - List all patients
- `GET /patients/{id}` - Get patient details
- `POST /patients` - Create new patient
- `PUT /patients/{id}` - Update patient
- `DELETE /patients/{id}` - Delete patient

### Visits
- `GET /visits` - List all visits
- `GET /visits/{id}` - Get visit details
- `POST /visits` - Create new visit
- `PUT /visits/{id}` - Update visit
- `DELETE /visits/{id}` - Delete visit

### Stock
- `GET /stock` - List all stock items
- `POST /stock` - Add stock item
- `PUT /stock/{id}` - Update stock
- `DELETE /stock/{id}` - Delete stock item

### Invoices
- `GET /invoices` - List all invoices
- `GET /invoices/{id}` - Get invoice details
- `POST /invoices` - Create new invoice

### Reports
- `GET /reports/overview` - Get overview statistics
- `GET /reports/revenue` - Get revenue data
- `GET /reports/visits` - Get visit statistics

### Route Optimization
- `POST /route/optimize` - Optimize visit route

## Docker (Optional)

```bash
docker build -t hcpilot .
docker run -p 8000:8000 hcpilot
```
