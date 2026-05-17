# HCPilot - Operating System for Mobile Healthcare Professionals

HCPilot is a comprehensive platform designed for mobile healthcare professionals including doctors, nurses, and paramedics who provide home care services.

## Features

### Mobile App (iOS)
- ✅ Patient management and search
- ✅ Visit scheduling and tracking
- ✅ Real-time route optimization
- ✅ Stock management with alerts
- ✅ Invoice generation and management
- ✅ Reports and analytics
- ✅ Dark mode support

### Web Dashboard
- Patient and visit management
- Financial reports and analytics
- Invoice creation and tracking
- Settings and preferences

### Backend
- FastAPI REST API
- Supabase for database and authentication
- Route optimization algorithms
- HIPAA-compliant architecture

## Project Structure

```
hcpilot/
├── backend/          # FastAPI backend with Supabase
├── web/              # React + TypeScript + Tailwind dashboard
├── ios/              # SwiftUI iOS application
└── README.md
```

## Getting Started

### Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your Supabase credentials
uvicorn main:app --reload
```

### Web Dashboard

```bash
cd web
npm install
npm run dev
```

### iOS App

Open `hcpilot/ios/HCPilotApp.xcodeproj` in Xcode and run on simulator or device.

## API Documentation

Once the backend is running, visit:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## Authentication

The app uses Supabase JWT authentication. API endpoints require the `Authorization: Bearer <token>` header.

## HIPAA Compliance

HCPilot is designed with HIPAA compliance in mind:
- End-to-end encryption for patient data
- Secure authentication with Supabase
- Audit logging for all data access
- Role-based access control

## Roadmap

- [ ] Stripe Connect integration for payments
- [ ] Offline mode for mobile app
- [ ] Voice commands for hands-free operation
- [ ] Telemedicine integration
- [ ] Lab results integration

## License

MIT License

## Support

For support, contact support@hcpilot.com
