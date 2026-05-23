# Parcours 7 — Dashboard compliance

**Audité contre** : commit `cd541df9` (état `main` après parcours 6).
**Brief de référence** : `Roadmap/brief-hcpilot.md` §"Conformité".

---

## Description du parcours

> Tab Conformité → consultation licence/MD/standing orders → tap sur élément warning ou critical → action de correction

## Séquence nominale telle qu'implémentée

| # | Élément | Fichier | Détail |
|---|---|---|---|
| 1 | Tab Conformité | tab.conformite | NavigationStack { ComplianceDashboardView() } |
| 2 | LicenseCard | [ComplianceDashboardView.swift:44-94](../ios/HCPilotApp/Views/ComplianceDashboardView.swift#L44-L94) | License # / Type / État / Expiration / Status |
| 3 | MedicalDirectorCard | [ComplianceDashboardView.swift:96-141](../ios/HCPilotApp/Views/ComplianceDashboardView.swift#L96-L141) | Nom / Email / Contrat / Audit |
| 4 | StandingOrdersCard | [ComplianceDashboardView.swift:143-186](../ios/HCPilotApp/Views/ComplianceDashboardView.swift#L143-L186) | Liste formulations + expirations |
| 5 | AlertsCard | [ComplianceDashboardView.swift:188-233](../ios/HCPilotApp/Views/ComplianceDashboardView.swift#L188-L233) | Liste alertes + bouton "Vu" |

## Variantes testées

| Variante | Observé |
|---|---|
| Licence OK (vert) | ✅ Affiche tag vert |
| Licence warning (<90j) | ✅ Tag orange |
| Licence critical (<30j) | ✅ Tag rouge — mais pas tappable ❌ |
| Standing Order expired | ✅ Affiche point rouge — pas tappable ❌ |
| Aucun MD configuré | ✅ Empty state texte — pas de CTA ❌ |
| Tap "Vu" sur alerte | ✅ Acknowledge + refresh |
| Pull-to-refresh | ✅ Refresh OK |

## Issues détectées par persona

### 🧑‍⚕️ Sarah (RN technophile)

| Sév. | Issue |
|---|---|
| **CRITIQUE** | Aucune action de correction : Sarah voit "Licence expire dans 12 j" en rouge mais tap = rien. Brief explicite "action de correction". |
| **HAUTE** | Bouton "Vu" sur alerte sans loading state — Sarah ne sait pas si le tap a passé. |
| **MOYENNE** | Pas d'historique des alertes acknowledged (où sont allées les notif que j'ai vues ?). |

### 🧑‍⚕️ Linda (NP prudente)

| Sév. | Issue |
|---|---|
| **HAUTE** | "Contrat jusqu'au {Date}" affiché avec interpolation directe → format ISO `2026-06-15T00:00:00`. Linda lit ça mal. |
| **HAUTE** | "Prochain audit : {Date}" même problème. |
| **MOYENNE** | Pas de bouton "Notifier mon MD par email" sur un contrat critical (alors qu'on a son email en BDD). |

### 🧑‍⚕️ Jessica (multitâche)

| Sév. | Issue |
|---|---|
| **CRITIQUE** | Jessica tape la notif "J-30 standing order" → arrive ici → ne sait pas où agir. Friction maximale. |
| **MOYENNE** | Pull-to-refresh sans spinner explicite. |

### 🧑‍⚕️ Maria (débutante)

| Sév. | Issue |
|---|---|
| **HAUTE** | "Aucune licence configurée" / "Aucun Medical Director" → empty state sans CTA "Configurer". Maria reste perdue. |
| **MOYENNE** | "Audit MD : 2026-06-15" — pour Maria, ne sait pas ce qu'est cet audit. Pas de tooltip. |

## Issues consolidées

### CRITIQUE (1)

- **C-85** Cards non-tappables → aucune action de correction depuis le dashboard. Brief explicite. Bloque l'utilisabilité quand il y a une alerte.

### HAUTE (4)

- **H-86** Empty state cards sans CTA "Configurer" → utilisateur bloqué.
- **H-87** Aucun `accessibilityIdentifier`.
- **H-88** Bouton "Vu" sans loading state.
- **H-89** Dates `endDate` / `nextAuditDate` affichées en format ISO via String interpolation (pas DateFormatter).

### MOYENNE (3)

- **M-90** Pas d'historique des alertes acknowledged.
- **M-91** Pas de "Notifier MD par email" sur contrat critical.
- **M-92** Pas de tooltip "Qu'est-ce que l'audit MD ?".

### BASSE (1)

- **B-93** Spinner pull-to-refresh.

## Corrections cette passe

| Issue | Action |
|---|---|
| **C-85** | Tap LicenseCard / MedicalDirectorCard quand status != ok → ouvre `SetupWizardView` (déjà existant) en sheet. |
| **H-86** | Empty state cards : ajouter bouton "Configurer" → SetupWizardView. |
| **H-87** | accessibilityIdentifier sur cards + alerts + boutons. |
| **H-89** | DateFormatter pour `endDate` et `nextAuditDate`. |

## Déférés (TODO-improvements.md)

H-88 (loading "Vu"), M-90 à M-92, B-93.

## Estimation

- CRITIQUE : 1 (C-85) — ~30 min
- HAUTE : 3 traitées (H-86/H-87/H-89), 1 différée
- MOYENNE / BASSE : 4 différées
- Tests XCUI : ~30 min

**Total cette passe** : ~1 h 30.
