# HCPilot — Operating System for Mobile IV Nurses (USA)

HCPilot est une application iOS native pour **infirmières IV mobiles indépendantes aux États-Unis** (RN, NP, LPN) qui pratiquent en private pay : Myers Cocktail, NAD+, hydratation, vitamines IV. Cible : 1 à 3 nurses par compte (mode solo ou micro-clinique).

## Trois douleurs adressées

1. **Documentation HIPAA** — consentement éclairé signé électroniquement (PencilKit + PDFKit + géoloc + IP), audit logs immuables, conservation 7 ans.
2. **Compliance par État** — licence (RN/NP/LPN/MD/PA), Medical Director + standing orders signées par formulation, alertes J-90/J-30/J-7 sur expirations.
3. **Inventaire IV** — traçabilité par lot (lot_number, expiration, supplier), scan code-barres AVFoundation, déduction automatique à la fin d'une session, alertes péremption.

## Stack

### iOS (iOS 18+)

- SwiftUI + MVVM
- PencilKit (signature consentement) + PDFKit (génération facture/consent)
- AVFoundation (scan code-barres EAN-13/8, UPC, Code 128, QR)
- MapKit (route optimization affichage) + CoreLocation (géoloc signature)
- UNUserNotificationCenter (alertes locales J-X)
- Keychain (token JWT + profil + lastActivity) — file protection `completeUntilFirstUserAuthentication`

### Backend serveur

**Actuel (MVP)** : FastAPI mock en mémoire — pas de DB, données seedées au démarrage.

**Production cible** : Supabase + add-on HIPAA + BAA signé, PostgreSQL avec Row Level Security stricte sur toutes les tables, Edge Functions pour la logique métier custom.

### Paiements

**Cible** : Stripe Connect Express (commission 0,99 $/transaction), Tap to Pay iPhone, génération de facture PDF avec taxe par État (Stripe Tax).

**Actuel** : non implémenté — Sprint 4 différé en attente de compte Stripe.

### Mapbox

Geocoding (création client) + Optimization API (route du jour). Token optionnel — fallback ligne droite si absent.

## Architecture de données (brief)

Tables principales : `nurses`, `clients`, `sessions`, `consents`, `standing_orders`, `medical_directors`, `inventory_lots`, `inventory_transactions`, `compliance_alerts`, `audit_logs`. RLS strict (chaque nurse n'accède qu'à ses propres données). Audit logs append-only via triggers PostgreSQL.

## État d'avancement

| Sprint brief | Statut |
| --- | --- |
| 1 — Foundations + onboarding wizard | ✅ |
| 2 — Clients + planning | ✅ |
| 3 — Consentement + signature + PDF + compliance + audit logs HIPAA | ✅ |
| 4 — Stripe Connect | ⏭️ en attente compte Stripe |
| 5 — Stock + scan + déduction par session | ✅ |
| 6 — Notifications locales + cache offline + queue mutations + tests unitaires | ✅ |
| Migration FastAPI mock → Supabase réel | ⏸️ |

**Tests** : 50 backend (pytest) + 11 iOS (XCTest) — verts.

## Structure repo

```text
hcpilot/
├── backend/          FastAPI mock + tests pytest
├── ios/              SwiftUI iOS 18 + XCTest target
│   ├── HCPilotApp/
│   │   ├── Models/   Client, Session, Consent, Compliance, Inventory, Invoice, AuditLog, User
│   │   ├── Views/    22 vues (onboarding, consent flow, compliance dashboard, inventory, etc.)
│   │   ├── ViewModels/
│   │   ├── Services/ APIService unique (Alamofire)
│   │   └── Utils/    SecureStorage (Keychain), OfflineCache, MutationQueue, NotificationService, etc.
│   └── HCPilotAppTests/
├── web/              Dashboard React legacy (à terme : remplacé par Supabase Dashboard)
└── Roadmap/          Brief HCPilot + guides fees
```

## Démarrage

### Démarrer le backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # valeurs factices fournies pour dev local
uvicorn main:app --reload
```

### Démarrer iOS

```bash
cd ios
xcodegen generate  # régénère HCPilot.xcodeproj depuis project.yml
open HCPilot.xcodeproj
# ⌘R dans Xcode pour lancer sur simulateur iPhone 17+ (iOS 18.0+)
```

## Sécurité & conformité

- **Keychain** pour le token de session et le profil utilisateur (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, non-iCloud)
- **Auto-logout** après 30 minutes d'inactivité (configurable 5/15/30/60 min depuis Profil → Sécurité)
- **Audit logs** append-only sur les actions sensibles : consentement créé, client archivé, session start/complete, usage stock — capture IP + user-agent côté serveur
- **Cache offline** chiffré via `NSFileProtectionCompleteUntilFirstUserAuthentication`
- **Queue de mutations** offline avec retry exponential (last-write-wins per brief)

## Documents légaux

Accessibles depuis Profil → Mentions légales & HIPAA :

- Politique de confidentialité
- HIPAA Notice of Privacy Practices (§164.520)
- Disclaimer médical
- Conditions d'utilisation

## Roadmap court terme (post-MVP)

- [ ] Sprint 4 — Stripe Connect Express (compte Stripe requis)
- [ ] Migration vers Supabase réel + BAA signé
- [ ] Création client multi-step 4 étapes (audit C5 UI)
- [ ] Vitals UI (saisie pendant la perfusion) + IV start/end timestamps
- [ ] Multi-select chips pour allergies/conditions (audit C6 UI)
- [ ] Notifications J-15 sur péremption stock + stock bas
- [ ] Apple Sign-In + magic link (Supabase Auth)
- [ ] Tests UI XCUITest (onboarding/consent/paiement/scan)

## Licence

Propriétaire. Contact : <contact@hcpilot.com>
