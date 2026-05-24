# CLAUDE.md — HCPilot

Mémo projet pour Claude Code. Lisible en < 2 min. Si tu (Claude) reprends sur ce repo, lis ça d'abord.

## Pitch en 1 ligne

App iOS native pour infirmières IV mobiles solo aux USA. Stack : SwiftUI 18+ / FastAPI Python 3.11 (mock backend) / Supabase prévu (jamais branché). Backend **n'utilise pas Supabase aujourd'hui** — tout est en `MOCK_*` listes mémoire dans [backend/main.py](backend/main.py).

## Commandes critiques

```bash
# Backend (port 8000, mock seed déterministe)
cd backend && uvicorn main:app --host 0.0.0.0 --port 8000 --log-level warning

# Backend tests (54 verts)
cd backend && python -m pytest tests/ -q

# iOS build (simulateur iPhone 17 — ID à adapter)
xcodebuild -project ios/HCPilot.xcodeproj -scheme HCPilotApp \
  -destination 'id=1237C1B9-36A9-46BE-8C8A-23B45578E380' build

# iOS unit tests (84 verts)
xcodebuild test -project ios/HCPilot.xcodeproj -scheme HCPilotApp \
  -destination 'id=1237C1B9-36A9-46BE-8C8A-23B45578E380' \
  -only-testing:HCPilotAppTests

# iOS UI tests (lents, flakiness HomeDashboard/InventoryLot connue)
xcodebuild test -project ios/HCPilot.xcodeproj -scheme HCPilotApp \
  -destination 'id=1237C1B9-36A9-46BE-8C8A-23B45578E380' \
  -only-testing:HCPilotAppUITests
```

## Architecture iOS

```
ios/HCPilotApp/
├── Views/           # 33 fichiers SwiftUI — 5 dépassent 500 LOC (SessionsList, SetupWizard, ConsentFlow, ComplianceDashboard, RouteMap)
├── ViewModels/      # 2 root (Auth, Home) + plusieurs inline dans les vues (Sessions/Clients/Invoices) — non-testables unitairement aujourd'hui
├── Services/        # APIService (Alamofire singleton + offline fallback + cert pinning scaffold), APIDTOs, InvoiceService
├── Models/          # Codable purs (Session, Client, Inventory, Invoice, Consent, User, Compliance, AuditLog)
└── Utils/           # MutationQueue (offline POST/PUT/DELETE), OfflineCache (GET disk cache), SecureStorage (Keychain), ConsentPDFBuilder, InvoicePDFBuilder, NotificationService, OnboardingState, LocationService, ConnectivityState
```

Patterns : `@MainActor` + `ObservableObject` + async/await partout. Pas encore migré vers `@Observable` iOS 17.

## Architecture backend

Monolithe : tout dans [backend/main.py](backend/main.py) (~2200 lignes). 48 endpoints. Auth JWT HS256. RBAC déclaré dans le payload (`role: provider`) **mais pas enforcé** côté endpoints.

Persistance : 10 listes Python (`MOCK_USERS`, `MOCK_CLIENTS`, `MOCK_SESSIONS`, etc.). Mutations en place — les tests utilisent la fixture `_reset_mocks_between_tests`. **Aucune intégration Supabase active**. Stripe = 2 endpoints stubs.

Tests : 13 fichiers dans [backend/tests/](backend/tests/), pytest-asyncio, ~54 verts.

## Conventions

- **Swift** : camelCase. **Python** : snake_case. **JSON DTOs** : snake_case côté serveur, mapping camelCase côté Swift via Codable `convertFromSnakeCase`.
- **Commits** : atomiques, format `H-XX — titre` (issue ID de l'audit-parcours), `C-XX — titre` (critique), `M-XX — titre` (moyenne), ou `Fork A — ...` pour les travaux groupés.
- **Tests** : ajouter UnitTests pour toute logique métier ; UITests seulement pour parcours critiques (XCUI lent + flaky).
- **Préfixes accessibility identifiers** : `tab.X`, `home.X`, `session.X`, `consent.X`, `client.X`, etc. — utilisés par les UITests.

## Pièges connus (validés en prod du fork Démo Client)

- `confirmationDialog` SwiftUI non queryable en XCUI iOS 18 → toujours préférer `.alert(...)` pour les confirmations testées.
- PencilKit `PKCanvasView` non dessinable via XCUI → en mode `-uitest`, exposer un bouton debug qui injecte un `PKDrawing` canned + `@State Bool` tripwire (cf. `ConsentFlowView.SignatureStep`).
- `TabView(.page)` crée des conflits d'identifiers XCUI (plusieurs "Continuer" coexistent). Préférer `Group { switch step }` + `.transition(...)`.
- Backend mock mutation **en place** → les tests Python **doivent** reset via `_reset_mocks_between_tests` fixture.
- `OnboardingState` skip via flag `-uitest-skipOnboarding` (set dans tous les UITests).
- `xcrun simctl io booted recordVideo demo/X.mov` pour la démo vidéo (cf. [demo/SCRIPT.md](demo/SCRIPT.md)).

## État courant (mai 2026)

- ✅ Démo client/investisseur crédible bout-en-bout (script `demo/SCRIPT.md`)
- ✅ 84 unit tests iOS + 54 backend + ~30 UI tests verts
- ✅ Offline complète (MutationQueue + OfflineCache)
- ✅ Audit-parcours 10 fichiers, 48/115 issues fermées
- ❌ Non livrable client payant : Supabase = stub, Stripe = stub, BAA non signé
- ❌ Pas de CI iOS (backend.yml + web.yml seuls)
- 67 issues différées tracées dans [audit-parcours/TODO-improvements.md](audit-parcours/TODO-improvements.md)

## Pour aller plus loin

- Setup détaillé : [BACKEND_SETUP.md](BACKEND_SETUP.md), [IOS_SETUP.md](IOS_SETUP.md), [WEB_SETUP.md](WEB_SETUP.md)
- Brief produit complet (32 KB) : [Roadmap/brief-hcpilot.md](Roadmap/brief-hcpilot.md)
- Tarification : [Roadmap/Guide_fees_HCPilot.md](Roadmap/Guide_fees_HCPilot.md)
- Audit & TODO : [audit-parcours/SUMMARY.md](audit-parcours/SUMMARY.md), [audit-parcours/TODO-improvements.md](audit-parcours/TODO-improvements.md)
- Démo : [demo/SCRIPT.md](demo/SCRIPT.md)
