# Parcours 2 — Accueil dashboard

**Audité contre** : commit `58829903` (état `main` après parcours 1).
**Brief de référence** : `Roadmap/brief-hcpilot.md` §"Écran d'accueil" + récente refonte (commit `dd5f059b`).

---

## Description du parcours

> Ouverture app → consultation KPIs → tap chaque tile → consultation sessions du jour → consultation alerte stock

C'est l'écran d'atterrissage post-login. Il doit donner en moins de 3 secondes :
- l'état du jour (revenu, sessions, conformité),
- la prochaine action attendue (bouton contextuel sous la carte),
- les alertes (stock bas, sync, conformité).

## Séquence nominale telle qu'implémentée

| # | Élément | Fichier | Comportement |
|---|---|---|---|
| 1 | Header greeting + date + sync badge | [HomeView.swift:53-72](../ios/HCPilotApp/Views/HomeView.swift#L53-L72) | "Bonjour, Marie" + date longue + badge sync 4 états |
| 2 | KPI tile Revenu | [HomeView.swift:81-89](../ios/HCPilotApp/Views/HomeView.swift#L81-L89) | NavigationLink → ReportsView |
| 3 | KPI tile Sessions | [HomeView.swift:91-99](../ios/HCPilotApp/Views/HomeView.swift#L91-L99) | NavigationLink → SessionsListView |
| 4 | KPI tile Conformité | [HomeView.swift:101-107](../ios/HCPilotApp/Views/HomeView.swift#L101-L107) | Button → navigateToCompliance state → ComplianceDashboardView |
| 5 | Carte "Ma Journée" | [HomeView.swift:115-160](../ios/HCPilotApp/Views/HomeView.swift#L115-L160) | NavigationLink → RouteMapView + ContextualStartButton sous |
| 6 | Section "Aujourd'hui" | [HomeView.swift:178-193](../ios/HCPilotApp/Views/HomeView.swift#L178-L193) | Liste de SessionListItem |
| 7 | Section "Sessions à venir" | [HomeView.swift:240-271](../ios/HCPilotApp/Views/HomeView.swift#L240-L271) | Liste limitée 5, empty state avec CTA |
| 8 | Statut du stock | [HomeView.swift:275-307](../ios/HCPilotApp/Views/HomeView.swift#L275-L307) | StockStatusCard cliquable → LowStockSheet |

## Variantes testées

| Variante | Observé |
|---|---|
| Pull-to-refresh | ✅ Trigger `viewModel.refresh()` |
| Auto-refresh 60s | ✅ Timer.publish |
| Tap KPI Revenu/Sessions/Conformité | ✅ Naviguent vers ReportsView / SessionsListView / ComplianceDashboardView |
| Tap carte | ✅ Navigation vers RouteMapView plein écran |
| **Tap SessionListItem** dans "Aujourd'hui" | ❌ **Rien ne se passe** (pas de NavigationLink) |
| Tap session "à venir" | ❌ Idem |
| Tap stock bas | ✅ Ouvre LowStockSheet |
| Pas de session du jour | ✅ Empty state "Aucune session aujourd'hui" + CTA |
| Pas de route stop (coords nil) | ✅ Bouton lifecycle seul |
| Offline | ✅ Badge sync + banner global |

## Issues détectées par persona

### 🧑‍⚕️ Sarah (RN solo, technophile)

| Sév. | Issue |
|---|---|
| **CRITIQUE** | Tap sur une session "Aujourd'hui" ne fait rien → Sarah ne peut pas accéder au détail d'une session depuis l'accueil, pourtant c'est le point d'entrée principal pour démarrer/terminer. |
| **HAUTE** | "Commencer la journée" → POST `/sessions/{id}/start` → status `in_progress` directement, sans passer par `en_route`. Le brief définit `en_route` comme étape valide ("nurse part vers client"). |
| **MOYENNE** | Le marker de carte numéroté n'a pas de tap individuel — la carte entière ouvre RouteMapView en plein écran. Sarah voudrait probablement avoir le détail d'un stop d'un tap. |

### 🧑‍⚕️ Linda (NP prudente)

| Sév. | Issue |
|---|---|
| **HAUTE** | Pas de légende sur la carte (qu'est-ce qu'un point bleu / orange ? la polyline rouge ?). Linda devine mais aimerait confirmer. |
| **MOYENNE** | Tap KPI Revenu → ReportsView : la valeur sur le dashboard ("4250 €") n'est pas re-clarifiée dans Reports. Linda veut savoir si c'est le revenu du mois en cours, l'année glissante, etc. |
| **BASSE** | "Conformité 3 urgents" en rouge : Linda veut savoir lesquels sont urgents avant de tapper. Tap : ouvre la dashboard. OK mais Linda apprécierait un tooltip. |

### 🧑‍⚕️ Jessica (multitâche)

| Sév. | Issue |
|---|---|
| **CRITIQUE** | Idem C-19 : Jessica est interrompue, revient sur l'app, tape la session en cours pour reprendre → rien. Doit aller dans tab Sessions → trouver la session → tap. Trois taps de friction. |
| **HAUTE** | Le badge sync montre "Sync il y a 3m" mais ne s'auto-update pas (seul un refresh recalcule). Jessica ne sait pas si l'app a vraiment lost connection ou pas. |
| **MOYENNE** | Pull-to-refresh disponible mais pas découvrable visuellement. Pas de spinner discret en haut. |

### 🧑‍⚕️ Maria (RN débutante)

| Sév. | Issue |
|---|---|
| **HAUTE** | "Conformité — 3 urgents" : Maria ne sait pas ce que ça veut dire concrètement. Aucune sous-info au survol. |
| **MOYENNE** | "Statut du stock" affiche "Gants nitrile M / 3 / Faible". Maria ne sait pas si elle peut commander en un tap depuis l'app. Tap → bottom sheet OK. Mais c'est un pari aveugle au début. |
| **MOYENNE** | Carte avec polyline rouge : Maria ne sait pas si c'est un trajet réel ou estimé. |
| **BASSE** | "Sessions" KPI : c'est compté pour aujourd'hui ? Pour le mois ? Pour la nurse ? Pas de précision. |

## Issues consolidées

### CRITIQUE (1)

- **C-19** SessionListItem dans "Aujourd'hui" et "Sessions à venir" n'est PAS un NavigationLink → l'utilisateur ne peut pas accéder au détail d'une session depuis l'accueil. Régression introduite par la refonte du commit `dd5f059b`.

### HAUTE (5)

- **H-20** `/sessions/{id}/start` → `in_progress` sans étape `en_route` intermédiaire. Le brief définit `en_route` comme étape distincte ("part vers le client"). Manque backend + bouton dédié sur Home / SessionDetail.
- **H-21** `accessibilityIdentifier` absents sur SessionListItem, route map, ContextualStartButton, stock cards.
- **H-23** Le badge "Sync il y a Xm" ne s'auto-met-à-jour pas entre les refreshes (relire la valeur lastSyncAt à intervalle).
- **H-29** Pas de légende sur la mini-carte (markers / polyline non explicités).
- **H-30** Pas de tooltip / aperçu sur "Conformité X urgents" — il faudrait voir lesquels.

### MOYENNE (5)

- **M-24** Tap individuel sur les markers de carte → ouverture détail stop / session.
- **M-25** Pull-to-refresh peu découvrable.
- **M-26** "Voir tous les lots" depuis LowStockSheet : la nav peut casser visuellement si le NavigationStack n'est pas wrapping.
- **M-31** KPI "Revenu" — préciser la période dans ReportsView.
- **M-32** KPI "Sessions" — préciser la période (jour).

### BASSE (3)

- **B-33** Date wrap sur petits écrans.
- **B-34** "Conformité 3 urgents" — tooltip / preview souhaitable.
- **B-35** Polyline rouge — UX clarification (trajet optimisé vs en cours).

## Corrections cette passe

| Issue | Action |
|---|---|
| **C-19** | Wrapper SessionListItem dans NavigationLink → SessionDetailView dans `todaySection` et `upcomingSection`. |
| **H-21** | Ajouter `accessibilityIdentifier` sur SessionListItem (par session.id), ContextualStartButton (par état), StockStatusCard (par productName), carte. |

## Déférés (TODO-improvements.md)

H-20 (en_route lifecycle), H-23 (badge auto-update), H-29/H-30 (légende/tooltip), M-24/M-25/M-26/M-31/M-32, B-33/B-34/B-35.

## Estimation

| Sév | Items | Effort |
|---|---|---|
| CRITIQUE | 1 traité (C-19) | 15 min |
| HAUTE | 1 traité (H-21), 4 déférés | 20 min |
| MOYENNE/BASSE | 8 déférés | TODO |
| Tests XCUITest | HomeDashboardUITests | ~30 min |

**Total cette passe** : ~1 h 30.
