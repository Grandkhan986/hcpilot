# Récapitulatif final — Audit des 10 parcours critiques HCPilot

**État de référence** : `main` au commit `2c3fe65a` au début de la passe 10.
**Brief de référence** : `Roadmap/brief-hcpilot.md`.

---

## Vue d'ensemble

Audit en 10 parcours sur l'application iOS HCPilot, cible **nurses IV mobiles indépendantes USA** (RN, NP, LPN). Chaque parcours a été analysé par 4 personas (Sarah RN technophile, Linda NP prudente, Jessica mini-clinique interrompue, Maria RN débutante), avec corrections in-place des issues CRITIQUE et HAUTE, génération de tests XCUITest, et différement structuré des MOYENNE/BASSE dans `TODO-improvements.md`.

## Issues par sévérité (synthèse 10 parcours)

| Sévérité | Détectées | Corrigées | Différées |
|---|---|---|---|
| CRITIQUE | 6 | 5 | 1 (C-01) |
| HAUTE | ~50 | ~30 | ~20 |
| MOYENNE | ~30 | ~8 | ~22 |
| BASSE | ~15 | 0 | ~15 |
| **Total** | **~100+** | **~45+** | **~58+** |

(chiffres approximatifs ; détail dans chaque audit-parcours/XX.md)

## Issues corrigées par parcours

| Parcours | Issues | Corrigées | Bugs majeurs détectés |
|---|---|---|---|
| 1. Onboarding | 18 | 9 | Welcome step + validation + confirm dismiss + URL `/standing_orders` |
| 2. Home dashboard | 12 | 2 | **C-19** SessionListItem non cliquable depuis Aujourd'hui |
| 3. Client form | 14 | 7 | DOB DatePicker + validation email/phone + gender étendu |
| 4. Consent | 12 | 4 | **C-50** Empty state SO + signature minimale |
| 5. Session lifecycle | 12 | 3 | Confirm skip-scan FDA + a11y |
| 6. Inventory lot | 10 | 4 | Labels catégorie + Code 128 keyboard |
| 7. Compliance | 9 | 4 | **C-85** Cards tappables → action de correction |
| 8. Offline | 9 | 5 | **C-94** createClient queueable + dedupe queue |
| 9. Profil & sécurité | 10 | 6 | Toggles notifications granulaires + confirm lock |
| 10. Audit logs | 9 | 4 | **H-114** AuditLogDetailView au tap |
| **Total** | **115** | **48** | |

## Top 5 frictions les plus importantes

### 1. ⚠️ C-19 — SessionListItem non cliquable (parcours 2)

Avant correction, depuis l'écran Accueil, taper sur une session **ne faisait rien**. Le seul accès au détail passait par le tab Sessions → liste → tap (3 taps vs 1). Bug catastrophique pour une utilisatrice qui veut reprendre une session interrompue. **Corrigé**.

### 2. ⚠️ C-50 — Empty state Standing Order manquant (parcours 4)

Une nurse fraîchement onboardée (pas de standing order configurée) lançant le flow de consentement voyait un `ProgressView` infini sans message ni CTA. Blocage total. **Corrigé** : empty state explicite avec orientation vers Profil/Conformité.

### 3. ⚠️ C-85 — Cards Conformité non-tappables (parcours 7)

L'écran Conformité affichait "Licence expire dans 12 j" en rouge, mais tap = rien. Brief explicite "action de correction". **Corrigé** : chaque card en état warning/critical expose un bouton "Renouveler/Mettre à jour" qui ouvre SetupWizardView.

### 4. ⚠️ C-94 — Création client offline non queueable (parcours 8)

`createClient` utilisait `post()` simple — échec brut en zone sans réseau, alors que `startSession`/`completeSession` étaient queueables. Brief explicite "création client offline". **Corrigé** : `queuedPost` + traitement de `QueuedError.enqueued` côté ClientFormView comme succès optimiste.

### 5. ⚠️ C-62 + C-63 — Saisie clinique + invoice generation (parcours 5, DÉFÉRÉES)

Deux gaps critiques **non corrigés** dans cette passe car ils requièrent une décision produit :
- **C-62** : aucune UI pour les vitals (pré/per/post), drip rate, alors que les champs existent dans le modèle backend. Bloque la conformité métier IV.
- **C-63** : la complétion d'une session ne génère pas d'invoice — le flow Stripe Connect du brief n'est pas câblé.

**Recommandation** : avant un test utilisateur réel, **traiter C-62 (Vitals UI minimal) en priorité**. C-63 peut être stubbé localement (Invoice.draft) en attendant Stripe.

## Bugs de production détectés et corrigés

| # | Bug | Découverte | Statut |
|---|---|---|---|
| 1 | `/compliance/standingOrders` (iOS camelCase) ≠ `/compliance/standing_orders` (backend snake_case) → 404 | Parcours 1 UI tests | ✅ Corrigé |
| 2 | `full_name = "Dr. Marie Dupont"` cached → split firstName="Dr." → greeting "Bonjour, Dr." sans nom | Parcours 9 (issue user direct) | ✅ Corrigé (strip honorifics) |
| 3 | Sessions seed sans timezone → affichées 21h/02h selon fuseau device | Patch initial Home | ✅ Corrigé |
| 4 | Re-tap "Commencer" offline → double mutation enqueueée → double POST | Parcours 8 dedupe | ✅ Corrigé |

## Tests automatisés ajoutés

| Type | Avant audit | Après audit |
|---|---|---|
| Unit tests iOS | 53 | 57 (+4 MutationQueueDedupe) |
| UI tests XCUITest passants | 0 | ~30 |
| UI tests XCUITest skipped (TODO documenté) | 0 | 6 |
| **Total iOS** | **53** | **~93** |

**Tests UI par parcours** :
- 01-onboarding : 4 (2 passent + 2 skipped UI-T1/T2)
- 02-home-dashboard : 5
- 03-client-form : 5 (4 + 1 skipped)
- 04-consent : 3 (2 + 1 skipped UI-T3 PencilKit)
- 05-session-lifecycle : 4 (state-dependent, self-skipping)
- 06-inventory-lot : 4
- 07-compliance : 3
- 08-offline-behavior : 3
- 09-profile-settings : 3
- 10-audit-logs : 3

## Limitations connues XCUI (tracking)

- **UI-T1** : TabView paginée rend les tests de transition fragiles. Mock APIService recommandé.
- **UI-T2** : `confirmationDialog` SwiftUI non queryable de façon fiable XCUI iOS 18+. Bascule vers `alert(...)` ou attendre patch Apple.
- **UI-T3** : PencilKit canvas signature non dessinable depuis XCUI standard. Hook debug requis.

## Estimation effort pour traiter les MOYENNE/BASSE différées

Lecture détaillée dans [TODO-improvements.md](TODO-improvements.md).

| Catégorie | Items | Effort total estimé |
|---|---|---|
| MOYENNE déférées | ~22 | ~12–18 h |
| BASSE déférées | ~15 | ~4–6 h |
| HAUTE déférées (architecturales) | ~5 | ~8–12 h (NWPathMonitor, en_route, vitals UI, invoice gen, MD editor) |
| **Total** | **~42** | **~24–36 h** |

## Recommandations stratégiques

### Avant un test utilisateur réel — bloqueurs

1. **~~C-62~~** ✅ **Résolu** ([6084153f](https://github.com/Grandkhan986/hcpilot/commit/6084153f)) — `VitalsEntryView` complète (3 sections horodatées Pré/Pendant/Post + validation anormale).
2. **~~C-63~~** ✅ **Résolu** ([44ced3c9](https://github.com/Grandkhan986/hcpilot/commit/44ced3c9)) — Génération PDF stub à la complétion de session, bouton "Voir la facture" sur SessionDetailView.
3. **~~C-01~~** ✅ **Résolu** ([767ae5b5](https://github.com/Grandkhan986/hcpilot/commit/767ae5b5)) — Gate first-launch combinant cache local + évaluation backend ; reprise step persistée en cas de force-close.
4. **~~H-104~~** ✅ **Résolu** ([87f3efaf](https://github.com/Grandkhan986/hcpilot/commit/87f3efaf)) — `MedicalDirectorEditView` + endpoint backend `PUT /v1/compliance/medical_directors/{id}` + désactivation soft delete.

**Rapport complet de cette série** : [`4-critiques-deferes-rapport.md`](../4-critiques-deferes-rapport.md).

### Avant la mise en production

5. **H-95** : `NWPathMonitor` pour détection offline passive — sinon les nurses en zone blanche restent dans un état "online" trompeur.
6. **H-97** : Messages d'erreur réseau user-friendly (centralisation dans `APIService.intercept`).
7. **G1 + G4** : décision FastAPI vs Supabase + BAA HIPAA Supabase (cf. audit précédent).

### Phase de polish (post-MVP)

8. Stabilisation des 6 UI tests skipped (UI-T1/T2/T3) → mock APIService + alert au lieu de confirmationDialog.
9. Toutes les MOYENNE — feedback toasts, validation temps réel, autocomplete adresse, etc.

## Conclusion

Sur 10 parcours critiques audités, **~48 issues** (dont 5/6 CRITIQUE) ont été corrigées in-place avec ~30 UI tests automatisés et **57 unit tests** verts. L'application est dans un état nettement plus robuste qu'au début de l'audit :
- Plus d'erreurs silencieuses (validations + confirms partout).
- Vocabulaire métier aligné (chips médical, états US, NAD+).
- Conformité HIPAA renforcée (signature minimale, audit detail view).
- Offline robuste (création client queueable, dédoublonnage).

Les 4 items critiques restants (**C-62 vitals, C-63 invoice, C-01 first-launch, H-104 MD editor**) sont identifiés et estimés. Aucun ne bloque l'expérience d'une démo ; tous bloquent une vraie utilisation production par une nurse réelle.
