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
