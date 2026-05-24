# Audit Lot 2 — 5 fichiers core HCPilot

**Date** : 2026-05-24
**Référence** : état `main` avant les patches L2-*
**Périmètre** : APIService.swift, ConsentPDFBuilder.swift, Client.swift, Session.swift, Invoice.swift

**42 issues identifiées**. Numérotation L2-XX pour distinguer du Lot 1.

---

## CRITIQUE (1)

### L2-1 — Filtre audit logs cassé silencieusement

- **Fichier** : [APIService.swift:603-606](ios/HCPilotApp/Services/APIService.swift#L603)
- **Cause** : iOS envoie `&entityType=...` (camelCase) dans l'URL ; backend attend `entity_type` (snake_case, confirmé dans [backend/tests/test_audit_logs.py](backend/tests/test_audit_logs.py)).
- **Impact** : le filtre n'a JAMAIS fonctionné. L'app retourne toujours TOUS les logs même quand on filtre par type. Bug HIPAA-sensible (la nurse pense voir uniquement les logs `sessions` mais voit aussi clients/inventory).
- **Effort** : ~5 min (1 ligne)

---

## HAUTE (3)

### L2-2 — Currency manquante dans Invoice

- **Fichier** : [Invoice.swift](ios/HCPilotApp/Models/Invoice.swift)
- **Cause** : aucun champ `currency`. Tous les montants sont des `Double` sans devise.
- **Impact** : Stripe Connect (Sprint 4) exige un currency code par invoice → bloque l'intégration.
- **Effort** : ~30 min (ajout champ + migration + tests)

### L2-3 — Race condition sur `authToken`

- **Fichier** : [APIService.swift:16](ios/HCPilotApp/Services/APIService.swift#L16)
- **Cause** : `authToken: String?` est un `var` accédé depuis plusieurs threads (callbacks Alamofire, `headers` computed, `setToken/clearToken`). Pas de synchro.
- **Impact** : un `clearToken()` pendant qu'une requête lit `headers` → état incohérent. Race intermittente, bug non-reproductible en dev.
- **Effort** : ~30 min (NSLock ou actor)

### L2-4 — `device_info` contient PHI

- **Fichier** : [ConsentPDFBuilder.swift:344-346](ios/HCPilotApp/Utils/ConsentPDFBuilder.swift#L344)
- **Cause** : `UIDevice.current.name` sur iOS est typiquement "iPhone de Marie Dupont". Ce nom apparaît dans `device_info` envoyé au backend et rendu dans le PDF de consentement.
- **Impact** : PHI fuit dans des champs non-PHI prévus. **HIPAA risk** — un document de consentement client mentionnant le nom du soignant en métadonnée est analysable par toute personne ayant accès au PDF.
- **Effort** : ~10 min (remplacer par `identifierForVendor`)

---

## MOYENNE (12)

### L2-5 — `DateFormatter` recréé à chaque date décodée

- **Fichier** : [APIService.swift:32-59](ios/HCPilotApp/Services/APIService.swift#L32)
- **Cause** : 5 DateFormatters alloués par date.
- **Impact** : sur `/audit_logs` (100 entrées × 2 dates × 5 formats) → 1000 allocations par appel. Perf.
- **Effort** : ~15 min (cache static)

### L2-6 — `RequestTimeout.upload` jamais utilisé

- **Fichier** : [APIService.swift:75-79](ios/HCPilotApp/Services/APIService.swift#L75)
- **Cause** : le commentaire claim "timeouts par catégorie" mais aucune méthode (POST consent PDF lourd, etc.) ne passe `upload`.
- **Impact** : annonce non tenue, PDF de consentement potentiellement timeout sur réseau lent (30s default).
- **Effort** : ~20 min (override per request)

### L2-7 — `touchActivity()` Keychain write par requête

- **Fichier** : [APIService.swift:148-150](ios/HCPilotApp/Services/APIService.swift#L148)
- **Cause** : chaque appel HTTP écrit dans le Keychain (latence cumulée).
- **Impact** : sur un burst de 20 requêtes, 20 writes Keychain (chacun ~5-15ms).
- **Effort** : ~20 min (batch + flush périodique)

### L2-8 — `intercept` n'intercepte que 401

- **Fichier** : [APIService.swift:295-302](ios/HCPilotApp/Services/APIService.swift#L295)
- **Cause** : tous les 4xx (403, 404, 409, 422) et 5xx restent des `AFError` opaques pour l'UI.
- **Impact** : la nurse voit des erreurs "la requête a échoué" sans contexte.
- **Effort** : ~30 min (étendre intercept + APIError cases)

### L2-9 — `countPages` fragile

- **Fichier** : [ConsentPDFBuilder.swift:131-197](ios/HCPilotApp/Utils/ConsentPDFBuilder.swift#L131)
- **Cause** : le calcul "Page X / Y" miroirise la géométrie de rendu. Tout changement de `draw*` casse silencieusement le count.
- **Impact** : footer affiche "Page 1/3" sur 2 pages, ou inversement. Pas de test cross-validant.
- **Effort** : ~3-4 h (refactor break logic partagé) ou ~30 min (juste tests, fix structurel déféré)

### L2-10 — `dateOfBirth: String?` non typée

- **Fichier** : [Client.swift:14](ios/HCPilotApp/Models/Client.swift#L14)
- **Cause** : DOB en String. Format ambigu (US `MM/dd/yyyy` vs ISO `YYYY-MM-DD`).
- **Impact** : comparaison/sort hacky, calculs d'âge fragiles, parsing dupliqué dans 3+ endroits.
- **Effort** : ~30 min (helper Date + centralisation parse)

### L2-11 — `gender: String?` free-form

- **Fichier** : [Client.swift:15](ios/HCPilotApp/Models/Client.swift#L15)
- **Cause** : pas d'enum. Peut stocker n'importe quoi.
- **Impact** : duplication de la logique d'affichage (`gender == "M" ? "Homme" : "Femme"` dans 2+ vues), pas de type safety au niveau du Model.
- **Effort** : ~45 min (enum + custom Codable + update UI)

### L2-12 — `Session.formulationName: String` non typée

- **Fichier** : [Session.swift:11](ios/HCPilotApp/Models/Session.swift#L11)
- **Cause** : String pour ce qui devrait être enum ou FK vers une table de formulations.
- **Impact** : pas de garantie que la valeur corresponde à une formulation existante. Décision **backend** (FK constraint).
- **Effort** : ~2 h backend + iOS

### L2-13 — `pre/during/postVitals: [String: String]?` non typés

- **Fichier** : [Session.swift:28-30](ios/HCPilotApp/Models/Session.swift#L28)
- **Cause** : vitals en dictionnaire de strings. Aucune validation au décode, perte du type au niveau du modèle.
- **Impact** : duplication de la conversion String → Int dans tous les callers (VitalsViewModel, display, validations).
- **Effort** : ~1 h (struct Vitals + custom Codable + tests)

### L2-14 — `InvoiceItem.id` synthétique collisable

- **Fichier** : [Invoice.swift:66](ios/HCPilotApp/Models/Invoice.swift#L66)
- **Cause** : `id = "\(description)-\(quantity)"`.
- **Impact** : deux items "Apple x1" → même id → warning SwiftUI `ForEach` + état UI partagé.
- **Effort** : ~15 min (UUID + custom Codable)

### L2-15 — `Double` pour montants

- **Fichier** : [Invoice.swift:16-21](ios/HCPilotApp/Models/Invoice.swift#L16)
- **Cause** : tous les amounts en `Double`. Erreurs d'arrondi accountancy classiques.
- **Impact** : invoice `$99.99 + $0.30` peut donner `$100.28999...` au lieu de `$100.29`. Bloquant audit comptable, sensible Sprint 4.
- **Effort** : ~4-6 h (Decimal + coordination backend)

### L2-16 — `clinicalNotes: String?` sans audit trail

- **Fichier** : [Session.swift:32](ios/HCPilotApp/Models/Session.swift#L32)
- **Cause** : une seule note, overwriting silencieux. Pas d'historique des édits.
- **Impact** : HIPAA recommande append-only pour notes cliniques (preuve en cas de plainte). Décision **backend**.
- **Effort** : ~3 h (table notes + endpoint + UI)

### L2-17 — `formulationInventoryId: String?` optionnel pour completed

- **Fichier** : [Session.swift:12](ios/HCPilotApp/Models/Session.swift#L12)
- **Cause** : FK traçabilité FDA peut être nil même sur session complétée.
- **Impact** : bloquant audit FDA si on ne peut pas remonter le lot consommé. Décision **backend** (check constraint).
- **Effort** : ~30 min backend

---

## BAS-MOYEN (8)

### L2-18 — `intercept` non triggeré sur `queued*` quand offline

- **Fichier** : [APIService.swift:307-361](ios/HCPilotApp/Services/APIService.swift#L307)
- **Cause** : `queuedPostAction`, `queuedPost`, `queuedDelete` capturent l'erreur réseau AVANT d'appeler `intercept`. Replay() ne call jamais intercept.
- **Impact** : 401 pendant un drain offline-to-online laisse la session locale en état zombie ("connecté" iOS, "déconnecté" serveur).
- **Effort** : ~15 min

### L2-19 — `Task { await drain }` fire-and-forget non bornée

- **Fichier** : [APIService.swift:312, 330, 348](ios/HCPilotApp/Services/APIService.swift#L312)
- **Cause** : plusieurs drain peuvent se chevaucher.
- **Impact** : compte sur MutationQueue interne pour locker (à confirmer). Sinon : drain concurrents qui rejouent les mêmes mutations.
- **Effort** : ~10 min (doc) ou ~30 min (vérif + fix)

### L2-20 — `class APIService` n'est pas `final`

- **Fichier** : [APIService.swift:4](ios/HCPilotApp/Services/APIService.swift#L4)
- **Cause** : pas marqué `final` → possibilité subclassing accidentel.
- **Impact** : standard Swift violation, devirt compiler manquée.
- **Effort** : ~1 min

### L2-21 — `findLotsByBarcode` n'URL-encode pas

- **Fichier** : [APIService.swift:533](ios/HCPilotApp/Services/APIService.swift#L533)
- **Cause** : barcode injecté tel quel dans l'URL.
- **Impact** : si `/` ou `+`, URL cassée. Practical risk faible (barcodes numériques) mais defensive coding.
- **Effort** : ~5 min

### L2-22 — `optimizeRoute(sessions: [Session])` payload énorme

- **Fichier** : [APIService.swift:629-631](ios/HCPilotApp/Services/APIService.swift#L629)
- **Cause** : POST envoie l'array complet de Sessions (avec photosPaths, allVitals, etc.).
- **Impact** : ~1 KB par session × 20 sessions = 20 KB pour un endpoint qui n'a besoin que de id + lat/lng.
- **Effort** : ~15 min (DTO léger)

### L2-23 — `getConsentPDF` erreur b64 vague

- **Fichier** : [APIService.swift:619-625](ios/HCPilotApp/Services/APIService.swift#L619)
- **Cause** : `Data(base64Encoded:)` échec → `APIError.invalidResponse` (vague, couvre 5+ causes possibles).
- **Impact** : debug difficile en prod.
- **Effort** : ~5 min (erreur typée)

### L2-24 — Magic numbers PDF non-nommés

- **Fichier** : [ConsentPDFBuilder.swift:285, 296, 248](ios/HCPilotApp/Utils/ConsentPDFBuilder.swift#L285)
- **Cause** : `ctx.y += 6`, `at: y - 2`, etc. Aimantés au font size.
- **Impact** : si on change `bodyFontSize`, le checkbox check se décale. Hidden coupling.
- **Effort** : ~10 min (constantes nommées)

### L2-25 — `InvoiceStatus` divergent de Stripe

- **Fichier** : [Invoice.swift:35-43](ios/HCPilotApp/Models/Invoice.swift#L35)
- **Cause** : Stripe Invoice statuses : draft/open/paid/void/uncollectible. Notre enum : draft/sent/paid/overdue/refunded/partialRefund/cancelled.
- **Impact** : Sprint 4 demandera une couche de mapping. Aujourd'hui pas bloquant mais à anticiper.
- **Effort** : ~15 min (extension `stripeStatus`)

---

## BAS (18)

### L2-26 — `Client.fullName` ne gère pas les composants vides

- **Fichier** : [Client.swift:39](ios/HCPilotApp/Models/Client.swift#L39)
- **Cause** : `"\(firstName) \(lastName)"` naïf — affiche " Martin" si firstName vide.
- **Effort** : ~5 min (trim + fallback)

### L2-27 — `Client.initials` sans fallback empty

- **Fichier** : [Client.swift:41](ios/HCPilotApp/Models/Client.swift#L41)
- **Cause** : `firstName.prefix(1) + lastName.prefix(1)` → "" si tous vides → avatar circle vide.
- **Effort** : ~5 min

### L2-28 — `Client.idDocumentPath` jamais set en backend

- **Fichier** : [Client.swift:32](ios/HCPilotApp/Models/Client.swift#L32)
- **Cause** : champ déclaré mais aucun backend ne le remplit. Dead field.
- **Effort** : ~5 min (supprimer) ou Sprint 6 (wire Supabase Storage)

### L2-29 — `allergies/conditions/medications: [String]` sans codes

- **Fichier** : [Client.swift:27-29](ios/HCPilotApp/Models/Client.swift#L27)
- **Cause** : free-form strings, pas de codes ICD-10/RxNorm.
- **Impact** : pas d'interop avec EMR US. Sprint 6+.
- **Effort** : significatif

### L2-30 — `Session.photosPaths: [String]` sans metadata

- **Fichier** : [Session.swift:33](ios/HCPilotApp/Models/Session.swift#L33)
- **Cause** : juste paths. Pas de timestamp, caption, ou ordre garanti.
- **Effort** : ~1 h (struct Photo)

### L2-31 — `Invoice.PaymentMethod` incomplet

- **Fichier** : [Invoice.swift:47-54](ios/HCPilotApp/Models/Invoice.swift#L47)
- **Cause** : manque `check`, `wire_transfer` (cas IV mobile : règlement à 30j).
- **Effort** : ~5 min

### L2-32 — `description` shadow `CustomStringConvertible.description`

- **Fichier** : [Invoice.swift:67](ios/HCPilotApp/Models/Invoice.swift#L67)
- **Cause** : property name conflict avec Swift built-in.
- **Effort** : ~5 min (rename `itemDescription`)

### L2-33 — `replay` bypass encoder

- **Fichier** : [APIService.swift:365-390](ios/HCPilotApp/Services/APIService.swift#L365)
- **Cause** : body déjà encodé en Data avant enqueue → bypass intentionnel.
- **Effort** : ~0 (doc seulement)

### L2-34 — `headers.dictionary` accessed in replay

- **Fichier** : [APIService.swift:371](ios/HCPilotApp/Services/APIService.swift#L371)
- **Cause** : style — utilise `headers.dictionary` (Alamofire helper) au lieu de itération.
- **Effort** : ~0

### L2-35 à L2-42 — Divers code style mineurs

- Variables non-mutated `let`, comments TODO obsolètes, ordering propriétés Codable, etc.
- **Effort cumulé** : ~30 min

---

## Synthèse globale

| Sévérité | Count | Effort estimé |
|---|---|---|
| CRITIQUE | 1 | ~5 min |
| HAUTE | 3 | ~70 min |
| MOYENNE | 12 | ~14-19 h (dont 5 backend) |
| BAS-MOYEN | 8 | ~2 h |
| BAS | 18 | ~2 h |
| **Total** | **42** | **~19-24 h** |

---

## Reco priorisation initiale (avant patch)

### Phase 1 — Critiques sécurité/correction (~45 min)
- L2-1 audit log filter (5 min)
- L2-3 race authToken (30 min)
- L2-4 PHI device.name (10 min)

### Phase 2 — Bloquants Sprint 4 (~2-3 h)
- L2-2 currency Invoice (30 min)
- L2-25 Stripe status mapping (15 min)
- L2-14 InvoiceItem id (15 min)

### Phase 3 — Performance & code health (~4-6 h)
- L2-5 DateFormatter cache (15 min)
- L2-6 upload timeout (20 min)
- L2-7 touchActivity batching (20 min)
- L2-8 intercept étendu (30 min)
- L2-10 DOB Date helper (30 min)
- L2-11 Gender enum (45 min)
- L2-13 Vitals struct (1 h)

### Phase 4 — Code quality batch (~2-3 h)
- L2-18 à L2-31 (en batch)
- BAS L2-26 à L2-42

---

## Statut post-patch (référence)

**31/42 traitées** (74 %). Détail dans [`audit-lot2-patch-rapport.md`](audit-lot2-patch-rapport.md).

11 issues différées :
- 5 MOYENNES (dont 4 nécessitent backend) : L2-9 (partiel), L2-12, L2-15, L2-16, L2-17
- 6 BAS : L2-28, L2-29, L2-30, L2-32, L2-33-34, L2-35-42

Voir [`audit-parcours/TODO-improvements.md`](audit-parcours/TODO-improvements.md) section "Lot 2 audit — Issues différées".
