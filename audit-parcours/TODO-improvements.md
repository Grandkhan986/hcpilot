# TODO improvements — issues MOYENNES / BASSES différées

Ce fichier centralise les frictions UX et améliorations identifiées lors de
l'audit parcours (cf. `audit-parcours/`) mais qui n'ont pas été corrigées
dans la passe initiale parce qu'elles relèvent d'une décision produit
ou ne sont pas bloquantes.

Format : un item = un point d'action atomique, avec sévérité, parcours
d'origine, fichier(s) concerné(s), et la décision attendue côté fondateur.

---

## Parcours 1 — Onboarding wizard

### C-01 — Auto-trigger first-launch du wizard

- **Sévérité** : CRITIQUE (différé décision produit)
- **Problème** : aujourd'hui le wizard n'est jamais auto-affiché. Une nurse fraîchement inscrite peut utiliser l'app sans avoir configuré sa licence/MD/SO et créer des sessions invalides.
- **Décision attendue** :
  - **Option A** — flag local `@AppStorage("hasCompletedOnboarding")`. Simple mais réinitialisable en réinstallant.
  - **Option B** — détection backend : si `/users/me/practice` retourne un payload incomplet (pas de `license_number`, pas de standing order actif), forcer l'ouverture du wizard. Plus robuste mais demande une route et un état.
  - **Option C (recommandée)** — combinaison : flag local pour la vitesse de boot, vérification serveur asynchrone au premier login pour confirmer.
- **Effort** : 2 h (Option A) à 5 h (Option C).
- **Fichiers** : [ContentView.swift](../ios/HCPilotApp/ContentView.swift), [AuthViewModel.swift](../ios/HCPilotApp/ViewModels/AuthViewModel.swift), [SetupWizardView.swift](../ios/HCPilotApp/Views/SetupWizardView.swift).

### M-11 — Picker État sans recherche

- **Sévérité** : MOYENNE
- **Problème** : 51 entrées (50 États + DC), scroll long sans champ de filtre.
- **Solution proposée** : remplacer par un `Picker` `.menuStyle` avec recherche, ou par un `NavigationLink` vers une vue liste avec `searchable`.
- **Effort** : 1 h.

### M-12 — Mention HIPAA / lien doc dans le wizard

- **Sévérité** : MOYENNE
- **Problème** : aucune mention de la conformité HIPAA dans le wizard. Linda (NP prudente) hésite à donner son NPI sans contexte.
- **Solution proposée** : ajouter un footer discret "Données stockées de manière HIPAA-compliante" + lien vers `LegalDocsView` existante.
- **Effort** : 30 min.

### M-13 — DoneStep ne route pas vers Accueil

- **Sévérité** : MOYENNE
- **Problème** : à la fin du wizard, `dismiss()` ferme le sheet et revient sur Profil. Le brief demande "arrivée Accueil".
- **Solution proposée** : `onCompleted` callback dans `SetupWizardView` peut être étendu pour signaler à `AppMainView` de basculer sur `selectedTab = 0`.
- **Effort** : 30 min.

### M-14 — Indicateur "pratique partiellement configurée" sur la home

- **Sévérité** : MOYENNE
- **Problème** : si une nurse a complété Step 1 mais abandonné Step 2/3, rien sur le dashboard ne le signale.
- **Solution proposée** : tile Conformité (déjà présente) en orange "Setup incomplet" + CTA → ouvrir le wizard à l'étape concernée.
- **Effort** : 1 h.

### M-15 — License types RN/NP/LPN/MD/PA sans descriptions inline

- **Sévérité** : MOYENNE
- **Problème** : Maria peut hésiter sur son type de licence.
- **Solution proposée** : un sous-titre par item dans le picker (`Text("RN — Registered Nurse")`).
- **Effort** : 30 min.

### B-16 — Date par défaut licence = today+2y arbitraire

- **Sévérité** : BASSE
- **Solution** : changer à `today+1y` (plus courant pour première licence), ou laisser tel quel.

### B-17 — Swipe-to-dismiss du sheet n'invoque pas la confirm

- **Sévérité** : BASSE
- **Note** : déjà adressé partiellement via `interactiveDismissDisabled(vm.hasUnsavedWork)` — désactive le swipe si données en cours. À tester.

### B-18 — Wizard non relancable depuis la home

- **Sévérité** : BASSE
- **Solution proposée** : si compliance incomplète, afficher un raccourci "Compléter ma configuration" sur le dashboard.
- **Effort** : 1 h.

---

---

## Parcours 2 — Accueil dashboard

### H-20 — Lifecycle `en_route` manquant

- **Sévérité** : HAUTE
- **Problème** : `POST /sessions/{id}/start` passe directement de `scheduled` à `in_progress`. Le brief définit l'étape intermédiaire `en_route` ("nurse part vers le client"). Manque endpoint backend + bouton UI.
- **Solution proposée** : ajouter `POST /sessions/{id}/en_route` côté backend, ajouter un bouton "Je pars" dans SessionDetailView, et faire en sorte que la home "Commencer la journée" déclenche en_route.
- **Effort** : 2 h.

### H-23 — Badge sync ne s'auto-update pas entre les refreshes

- **Sévérité** : HAUTE
- **Problème** : Le label "Sync il y a Xm" est calculé au render. Sans déclencheur (refresh), il reste figé même si le temps passe.
- **Solution proposée** : ajouter un `Timer.publish(every: 60, ...)` dans `SyncStatusBadge` pour forcer un re-render.
- **Effort** : 15 min.

### H-29 — Pas de légende sur la mini-carte

- **Sévérité** : HAUTE
- **Problème** : Linda ne sait pas ce que représentent les markers numérotés et la polyline rouge.
- **Solution proposée** : petit footer texte sous la carte type "Trajet optimisé · 4 stops" et tap sur marker → label.
- **Effort** : 30 min.

### H-30 — Tooltip / aperçu sur "Conformité X urgents"

- **Sévérité** : HAUTE
- **Solution proposée** : sous le label "3 urgents", lister en très petit les 1-3 alertes les plus critiques (genre "Licence expire dans 12j · Standing order Myers expire dans 5j").
- **Effort** : 1 h.

### M-24, M-25, M-26 — Friction tap marker / pull-to-refresh / nav LowStockSheet

- **Sévérité** : MOYENNE
- Effort total : 1 h 30.

### M-31, M-32 — Période des KPI

- **Solution proposée** : préciser "Revenu du mois" / "Sessions du jour" sous le chiffre en très petit.
- **Effort** : 10 min. (note : déjà raccourci pour gagner de l'espace dans le patch précédent — à reconsidérer.)

### B-33, B-34, B-35 — Polish

- Wrap date, tooltip conformité, légende polyline.
- Effort total : 30 min.

---

---

## Parcours 3 — Création client

### M-43 — Autocomplete d'adresse

- **Sévérité** : MOYENNE
- **Solution proposée** : `MKLocalSearchCompleter` côté line1, suggestions filtre par USA, remplit auto city/state/zip.
- **Effort** : 2 h.

### M-44 — Médications en chips/list au lieu de CSV

- **Sévérité** : MOYENNE
- **Solution proposée** : composant similaire à `ChipMultiSelect` mais sans presets (saisie libre + chips dynamiques).
- **Effort** : 1 h 30.

### M-45 — Mention HIPAA / data storage inline

- **Sévérité** : MOYENNE
- **Solution proposée** : footer discret dans le form, "Vos saisies sont stockées de manière HIPAA-compliant" + lien LegalDocsView.
- **Effort** : 15 min.

### M-46 — Étoffer presets allergies/conditions

- **Sévérité** : MOYENNE
- **Solution proposée** : ajouter "Diabète type 1", "Hépatite B/C", "VIH", "Cancer en rémission", "MICI", "Lupus", etc. à `ChipPresets`.
- **Effort** : 15 min.

### M-48 — Indication "facultatif" sur champs

- **Sévérité** : MOYENNE
- **Note** : déjà adressé partiellement (Section footer "Email et téléphone facultatifs"). À étendre.

### B-47 / B-49 — Polish labels et format DOB affiché

- **Effort** : 15 min.

---

---

## Parcours 4 — Consentement signature flow

### H-53 — Hint visuel "Signer ici" sur le canvas

- **Sévérité** : HAUTE
- **Solution proposée** : ligne de signature en pointillé + texte "Signer ici" en placeholder qui disparaît au 1ᵉʳ trait.
- **Effort** : 30 min.

### H-54 — Scroll-to-bottom requis sur consent text

- **Sévérité** : HAUTE
- **Problème** : conformité HIPAA — "J'ai lu" devrait être validable uniquement après lecture complète.
- **Solution proposée** : tracker `GeometryReader` sur la ScrollView, activer le bouton "Continuer" seulement après reached-bottom.
- **Effort** : 1 h.

### M-56 — Prévisualisation PDF avant POST

- **Sévérité** : MOYENNE
- **Solution proposée** : ajouter une step 4 (Aperçu) avec `PDFKit.PDFView` rendant `ConsentPDFBuilder.build(...)` localement. Confirmation explicite avant POST.
- **Effort** : 1 h 30.

### M-57 — Timeout sur loadFormulations

- **Sévérité** : MOYENNE
- **Solution proposée** : timeout 10 s sur l'appel + retry button visible. (Déjà partiellement adressé via `isLoadingStandingOrders` flag.)
- **Effort** : 30 min.

### M-58 — Accessibilité ProgressDots

- **Sévérité** : MOYENNE
- **Solution proposée** : ajouter `accessibilityLabel("Étape X sur 4")` sur ProgressDots.
- **Effort** : 10 min.

### M-60 — Communication HIPAA inline

- **Sévérité** : MOYENNE
- **Solution proposée** : ajouter sous le canvas signature "Le PDF est chiffré localement et envoyé sur un serveur HIPAA-compliant."
- **Effort** : 15 min.

### B-59 / B-61 — Polish iPad canvas / bouton reset wizard

- **Effort** : 30 min.

### UI-T3 — Tester la signature PencilKit en XCUI

- **Problème** : XCUI ne sait pas dessiner sur PKCanvasView (pas d'API gestes graphiques pour le hit-testing custom).
- **Pistes** :
  1. Faire un mock `PKCanvasView` via flag d'environnement qui pré-remplit `drawing`.
  2. Ajouter un bouton de debug "Signature de test" derrière un launchArgument `-uitest`.
- **Effort** : 1 h pour la solution flag debug.

---

---

## Parcours 5 — Session lifecycle

### C-62 — Saisie clinique (vitals, drip rate) absente UI

- **Sévérité** : CRITIQUE (déférée)
- **Problème** : modèle backend a `pre_vitals`, `during_vitals`, `post_vitals`, `drip_rate` (jsonb libre) mais aucune UI pour les saisir. Le brief explicite cette saisie comme requise pour les sessions IV.
- **Solution proposée** :
  1. Vue dédiée `SessionVitalsView` accessible depuis SessionDetailView pendant in_progress
  2. 3 sections (Pré / Pendant / Post) avec champs BP / HR / Sat O2 / Temp + champ libre
  3. Save patche la session via `SessionPatch.preVitals` etc.
- **Effort** : 4 h.

### C-63 — Pas de génération d'invoice à la complétion

- **Sévérité** : CRITIQUE (déférée — bloque Stripe)
- **Problème** : `/sessions/{id}/complete` ne crée pas d'invoice. Le brief décrit le flow complet : complete → invoice.draft → paiement Stripe.
- **Décision attendue** : intégrer Stripe Connect ou stub local en attendant ?
- **Effort** : 6 h (avec Stripe) ou 1 h (stub local créant Invoice.draft).

### H-64 — Confirm sur "Commencer la session"

- **Sévérité** : HAUTE (déférée)
- **Solution proposée** : confirmationDialog avant POST /start. Petit, 15 min.

### H-67 — Timer en cours sur SessionDetailView

- **Sévérité** : HAUTE (déférée)
- **Solution proposée** : Si `session.startedAt != nil && status == .inProgress`, afficher `Text(startedAt, style: .timer)` sous le statut.
- **Effort** : 15 min.

### M-70 — Capturer cancellation_reason

- **Solution proposée** : ajouter un TextField "Raison" dans le dialog d'annulation.
- **Effort** : 30 min.

### M-71 / M-72 / M-73 / B-74

- Voir audit-parcours/05-session-lifecycle.md.

---

---

## Parcours 6 — Ajout lot inventaire

### M-79 — Warning péremption proche / passée

- **Sévérité** : MOYENNE
- **Solution proposée** : sous le DatePicker, afficher un Label rouge si la date est < J+30 (warning orange) ou < J0 (rouge "Lot déjà périmé").
- **Effort** : 15 min.

### M-80 — Scan multiple consécutif

- **Sévérité** : MOYENNE
- **Solution proposée** : après "Ajouter", proposer "Scanner un autre lot" en plus de "Terminer" pour rester dans le flow.
- **Effort** : 30 min.

### M-81 — CTA Scanner plus proéminent

- **Sévérité** : MOYENNE
- **Solution proposée** : remplacer le toolbar icon par un FAB ou un large bouton dans la zone d'en-tête de InventoryListView.
- **Effort** : 20 min.

### M-82 — Filtre par catégorie

- **Sévérité** : MOYENNE
- **Solution proposée** : segmented picker NAD / Vitamines / Sérum / Autres sous la SearchBar.
- **Effort** : 30 min.

### B-83 / B-84 — Devise et UI scanner

- B-83 différée passage anglais (cf. brief).
- B-84 cosmétique.

---

---

## Parcours 7 — Compliance dashboard

### H-88 — Loading state sur "Vu" (acknowledge alerte)

- **Sévérité** : HAUTE (déférée)
- **Solution proposée** : while acknowledging, le bouton affiche un ProgressView ; en cas d'erreur, restaurer + toast.
- **Effort** : 20 min.

### M-90 — Historique des alertes acknowledged

- **Sévérité** : MOYENNE
- **Solution proposée** : disclosure "Voir les alertes résolues" sous AlertsCard, montrant les 10 dernières.
- **Effort** : 30 min.

### M-91 — "Notifier mon MD par email" sur contrat critical

- **Sévérité** : MOYENNE
- **Solution proposée** : ajouter un secondary button "Envoyer un rappel au MD" → mailto: ou backend `/compliance/medical_directors/{id}/remind`.
- **Effort** : 1 h (avec endpoint backend).

### M-92 — Tooltip "Qu'est-ce que l'audit MD ?"

- **Sévérité** : MOYENNE
- **Solution proposée** : icon `.info.circle` cliquable ouvrant une sheet explicative.
- **Effort** : 20 min.

### B-93 — Spinner pull-to-refresh

- **Sévérité** : BASSE
- **Note** : `.refreshable` SwiftUI inclut déjà le spinner natif, peut-être suffisant.

---

---

## Parcours 8 — Offline behavior

### H-95 — Detection offline passive (NWPathMonitor)

- **Sévérité** : HAUTE
- **Problème** : actuellement, l'app détecte l'offline uniquement quand un appel échoue. Si l'utilisatrice ne fait rien pendant 30 min en zone blanche, l'app croit toujours être en ligne.
- **Solution proposée** : `NWPathMonitor` qui met à jour `ConnectivityState.isOffline` en temps réel + déclenche un drain automatique au retour de connexion.
- **Effort** : 1 h.

### H-97 — Errors réseau user-friendly

- **Sévérité** : HAUTE
- **Problème** : "NSURLErrorDomain Code=-1009" affiché à l'utilisateur.
- **Solution proposée** : centraliser dans `APIService.intercept` la conversion `URLError → APIError` avec messages français explicites.
- **Effort** : 30 min.

### M-99 — Glossaire / aide MutationQueueView

- **Sévérité** : MOYENNE
- **Solution proposée** : déjà présent via la section "Comportement" qui explique. Peut être enrichi avec un FAQ.
- **Effort** : 30 min.

### M-102 — Persistance banner offline

- **Sévérité** : MOYENNE
- **Solution proposée** : conserver le banner 2-3 secondes après le retour online pour indiquer "Reconnecté · X actions synchronisées".
- **Effort** : 20 min.

---

---

## Parcours 9 — Profil & sécurité

### H-104 — Édition MD existant (audit frequency, dates contrat)

- **Sévérité** : HAUTE
- **Problème** : SetupWizardView re-crée un MD. Pas de vue pour modifier un MD actif (juste re-create).
- **Solution proposée** : `MedicalDirectorEditView` + endpoint `PUT /compliance/medical_directors/{id}` backend.
- **Effort** : 2 h (UI + backend).

### M-109 — "Synchroniser maintenant" global

- **Sévérité** : MOYENNE
- **Solution proposée** : bouton dans ProfileView qui appelle `MutationQueue.drain` + invalide les caches GET. Indicateur de progression.
- **Effort** : 30 min.

### M-113 — Feedback save SecuritySettings

- **Sévérité** : MOYENNE
- **Solution proposée** : Toast "Modifications enregistrées" qui s'affiche 2s après changement du picker.
- **Effort** : 20 min.

### B-110 — Photo de profil

- **Sévérité** : BASSE (future feature).

---

---

## Parcours 10 — Audit logs

### H-116 — Export CSV / PDF du journal d'audit

- **Sévérité** : HAUTE
- **Problème** : auditeur externe HIPAA / RAC peut demander l'export complet. Pas d'UI ni d'endpoint.
- **Solution proposée** : endpoint `GET /audit_logs/export.csv` (backend) + bouton "Exporter" dans la nav bar de AuditLogView. Stripe est un blocker pour le PDF avec signature.
- **Effort** : 1 h.

### M-118 — Filtre par action (create / update / delete)

- **Sévérité** : MOYENNE
- **Solution proposée** : 2ᵉ Picker segmented sous le filter entity, options "Toutes / Création / Modification / Suppression".
- **Effort** : 20 min.

### M-119 — Recherche par entityId

- **Sévérité** : MOYENNE
- **Solution proposée** : SearchBar au-dessus du Picker, filtre `entries.filter { $0.entityId.contains(searchTerm) }`.
- **Effort** : 15 min.

### M-120 — Pagination

- **Sévérité** : MOYENNE
- **Solution proposée** : trigger `loadMore` au scroll-end. Bouton "Charger plus" si limite atteinte.
- **Effort** : 45 min.

### B-122 — Timeline visuelle

- **Sévérité** : BASSE — alternative visuelle à la liste plate.

---

## Tests UI fragiles à stabiliser

### UI-T1 — `test_onboarding_nominal_flow_reaches_done` (skip)

- **Symptôme** : la 3ᵉ step (Standing Order) n'apparaît pas dans les 10 s après le POST MD, malgré que le backend retourne 201 < 200 ms.
- **Hypothèse** : `TabView(.page)` rend toutes les pages lazy et XCUI peine à distinguer la step courante quand plusieurs « Continuer » coexistent dans la hierarchy.
- **Pistes** :
  1. Mock APIService via flag d'environnement → réponses instantanées + déterministes.
  2. Remplacer `TabView(.page)` par un `Group + switch step` (chaque step démontée à la transition → XCUI ne voit qu'un seul bouton à la fois).
- **Effort** : 1 h pour pivoter de TabView vers switch, ou 2 h pour mock API + flag.

### UI-T2 — `test_close_with_unsaved_work_shows_confirm` (skip)

- **Symptôme** : le `confirmationDialog` SwiftUI n'expose pas ses boutons (« Continuer la configuration », « Quitter, j'y reviendrai ») à `app.sheets.buttons` ni `app.alerts.buttons` ni `app.buttons` global.
- **Hypothèse** : sur iOS 18+, `confirmationDialog` est présenté comme un menu système (UIMenuPresentationController) qui n'est pas dans la hiérarchie d'accessibilité XCUI.
- **Pistes** :
  1. Remplacer `confirmationDialog` par `alert(...)` (mieux supporté par XCUI).
  2. Ajouter `accessibilityIdentifier` aux boutons du dialog (SwiftUI ne supporte pas directement, mais on peut wrapper).
- **Effort** : 30 min pour pivoter vers `alert`.

## Synthèse parcours 1

| Sév | Items | Effort total estimé |
|---|---|---|
| CRITIQUE (différée) | 1 (C-01) | 2–5 h |
| MOYENNE | 5 (M-11 à M-15) | 3 h 30 |
| BASSE | 3 (B-16 à B-18) | 1 h 30 |
| **Total** | **9** | **~7–10 h** |

---

## Lot 1 audit — Issues différées (mai 2026)

Audit Lot 1 (6 fichiers de la mission 4 critiques déférées) — 6/23 issues
traitées immédiatement (P-12, P-16, P-17, P-8, P-14, P-4 — cf.
`audit-lot1-patch-rapport.md`). 17 restantes différées :

### Moyennes

- [ ] **P-1** OnboardingState : race condition possible si `evaluate()` annule un `markComplete()` récent. Ajouter une protection 30 s. (~30 min)
- [ ] **P-5** InvoicePDFBuilder : footer right potentiellement coupé en bas de page (texte long de practiceName). (~15 min)
- [ ] **P-9** InvoiceLocalStore : reconsidérer `.completeFileProtection` (au lieu de `afterFirstUserAuthentication`) pour HIPAA strict — données PHI inaccessibles écran verrouillé. (~30 min + tests)
- [ ] **P-13** InvoiceService : remplacer le préfixe `"stub-"` dans les invoice IDs par `"inv-"` ou un format aligné Stripe Sprint 4. (~10 min)
- [ ] **P-18** VitalsEntryView : check cohérence temporelle pre < during < post (warning si l'ordre est incohérent). (~20 min)

### Basses

- [ ] **P-2** OnboardingState : catch silencieux (errors ignorées dans evaluate)
- [ ] **P-3** OnboardingState : pas de logging des transitions d'état
- [ ] **P-6** InvoicePDFBuilder : pas de localisation (FR hardcodé) — bloquant si on passe à l'EN
- [ ] **P-7** InvoicePDFBuilder : devise EUR hardcodée — bloquant pour US (USD)
- [ ] **P-10** InvoiceLocalStore : pas de purge des PDFs orphelins (invoiceId supprimé mais PDF resté sur disque)
- [ ] **P-11** InvoiceLocalStore : pas de migration de schema (si on change le format de la map UserDefaults)
- [ ] **P-15** InvoiceService : `clientFullName ?? session.clientName ?? "Client"` — fallback "Client" anonyme un peu pauvre
- [ ] **P-19** VitalsEntryView : pas de keyboard.done pour fermer (la nurse doit tap ailleurs)
- [ ] **P-20** VitalsEntryView : pas d'unité affichée dans le placeholder (juste "120" pas "120 mmHg")
- [ ] **P-21** MedicalDirectorEditView : pas de validation NPI format (10 digits + Luhn check)
- [ ] **P-22** MedicalDirectorEditView : pas d'undo si on annule par erreur après modification
- [ ] **P-23** MedicalDirectorEditView : pas de feedback de save (juste dismiss)

### Synthèse Lot 1

| Sév | Items traités | Items différés | Effort différé estimé |
|---|---|---|---|
| CRITIQUE | 1 (P-12) | 0 | — |
| MOYENNE | 3 (P-16, P-17, P-8) | 5 | ~2 h |
| BAS-MOYEN | 2 (P-14, P-4) | 0 | — |
| BASSE | 0 | 12 | ~3 h |
| **Total** | **6** | **17** | **~5 h** |
