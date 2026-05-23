# Parcours 5 — Démarrage et complétion d'une session

**Audité contre** : commit `a69fcd0c` (état `main` après parcours 4).
**Brief de référence** : `Roadmap/brief-hcpilot.md` §"Lifecycle session" + §"Facturation".

---

## Description du parcours

> Depuis Accueil → tap session → détails → marquer en_route → marquer in_progress → saisie clinique → marquer complete → invoice générée

C'est le flow le plus utilisé : une nurse l'enchaîne 3-6× par jour. La friction y a un impact direct sur la productivité, et les omissions cliniques (vitals, lot consommé) impactent la conformité.

## Séquence nominale telle qu'implémentée

| # | Étape brief | Implémenté ? | Fichier |
|---|---|---|---|
| 1 | Tap session depuis Accueil | ✅ Fix C-19 du parcours 2 | [HomeView.swift](../ios/HCPilotApp/Views/HomeView.swift) |
| 2 | Marquer en_route | ❌ Endpoint et bouton manquants | — |
| 3 | Marquer in_progress | ✅ Bouton "Commencer la session" → POST /start | [SessionsListView.swift:233](../ios/HCPilotApp/Views/SessionsListView.swift#L233) |
| 4 | Saisie clinique (vitals, drip rate, notes) | ⚠️ Partiel : champs en BDD, UI uniquement pour `clinicalNotes` via "Modifier" | [SessionFormView.swift](../ios/HCPilotApp/Views/SessionFormView.swift) |
| 5 | Marquer complete | ✅ "Terminer la session" → LotUsageSheet → recordUsage + POST /complete | [LotUsageSheet.swift](../ios/HCPilotApp/Views/LotUsageSheet.swift) |
| 6 | Invoice générée auto | ❌ Pas de génération automatique côté backend ni iOS | — |

## Variantes testées

| Variante | Observé |
|---|---|
| Status scheduled → tap "Commencer" | ✅ status devient in_progress |
| Status in_progress → tap "Terminer" → choisir lot → confirmer | ✅ recordUsage + complete OK |
| "Terminer sans enregistrer de lot" | ⚠️ Possible sans aucun confirm — perte traçabilité FDA |
| Fermer LotUsageSheet avec quantité saisie | ⚠️ Perte sans confirm |
| Annuler session via menu | ✅ Confirm alert présent |
| Modifier notes pendant in_progress | ✅ Possible via "Modifier" |

## Issues détectées par persona

### 🧑‍⚕️ Sarah (RN technophile)

| Sév. | Issue |
|---|---|
| **CRITIQUE** | Pas d'invoice générée à la complétion. Sarah s'attend à voir un montant + statut "À facturer" après "Terminer", mais aucun lien vers Factures. |
| **HAUTE** | "Commencer la session" sans confirm — Sarah peut taper par erreur sur le mauvais client. |
| **MOYENNE** | Pas de timer visible "Session en cours depuis HH:MM" sur SessionDetailView (uniquement sur Home). |

### 🧑‍⚕️ Linda (NP prudente)

| Sév. | Issue |
|---|---|
| **CRITIQUE** | Pas de saisie pré-/per-/post-vitals. Le brief explicite que c'est requis pour les sessions IV. Linda ne peut pas tracer ses observations cliniques. |
| **HAUTE** | Lifecycle `en_route` absent : Linda voudrait marquer "Je pars vers le client" distinctement de "Je commence l'IV". (déjà documenté H-20) |
| **MOYENNE** | "Annuler la session" — pas de champ "raison d'annulation" alors que le modèle backend a `cancellation_reason`. |

### 🧑‍⚕️ Jessica (multitâche)

| Sév. | Issue |
|---|---|
| **HAUTE** | LotUsageSheet fermé accidentellement (quantité saisie + lot sélectionné) → perte silencieuse. La session reste in_progress mais l'usage du lot n'est pas enregistré. |
| **MOYENNE** | Pas de raccourci "Reprendre session en cours" depuis la home (le contextual button existe mais ne pointe pas vers SessionDetailView, il ouvre directement la sheet de Lot). |

### 🧑‍⚕️ Maria (RN débutante)

| Sév. | Issue |
|---|---|
| **HAUTE** | "Terminer sans enregistrer de lot" présent au même niveau que "Confirmer la consommation" — Maria peut tapper par erreur et perdre la traçabilité FDA. Devrait être planqué (menu, confirm). |
| **MOYENNE** | Pas de hint "N'oubliez pas la saisie clinique avant de terminer" entre Commencer et Terminer. |
| **MOYENNE** | Pas d'indication explicite que "Commencer" déclenche un audit log irréversible. |

## Issues consolidées

### CRITIQUE (2)

- **C-62** Saisie clinique (vitals + drip rate) absente de l'UI alors que présente dans le modèle. Le brief explicite ce besoin. → Bloque la conformité métier IV.
- **C-63** Pas de génération d'invoice à la complétion. Le brief décrit "invoice générée". → Bloque le flow de facturation Stripe.

### HAUTE (5)

- **H-64** Pas de confirm sur "Commencer la session" (action irréversible côté audit).
- **H-65** "Terminer sans enregistrer de lot" trop visible — risque de zapper la traçabilité FDA.
- **H-66** `accessibilityIdentifier` absents sur start/complete/cancel/LotUsageSheet.
- **H-67** Pas de timer en cours sur SessionDetailView.
- **H-68** Fermer LotUsageSheet avec quantité saisie → perte sans confirm.

### MOYENNE (4)

- **M-70** `cancellationReason` non capturé en UI.
- **M-71** Pas de bouton "Marquer en_route" (couplé à H-69/H-20).
- **M-72** Raccourci "Reprendre session" depuis dashboard pour éviter la double nav.
- **M-73** Hint "saisie clinique avant Terminer".

### BASSE (1)

- **B-74** "Commencer" pourrait clarifier en "Démarrer l'IV" pour distinguer de "Commencer la journée".

## Corrections cette passe

| Issue | Action |
|---|---|
| **H-66** | accessibilityIdentifier sur tous les boutons lifecycle + LotUsageSheet |
| **H-65** | Renommer + dégrader visuellement "Terminer sans enregistrer de lot" + ajouter confirmationDialog |
| **H-68** | confirmationDialog sur "Annuler" du LotUsageSheet si lot sélectionné ou notes saisies |

## Déférés (TODO-improvements.md)

C-62 (saisie vitals UI complet), C-63 (génération invoice — bloque sur Stripe), H-64 (confirm Commencer), H-67 (timer SessionDetailView), H-69 (en_route, doublon H-20), M-70/71/72/73, B-74.

C-62 et C-63 sont des CRITIQUE qui requièrent une décision produit et un effort > 4h chacune. Documentées comme blockers Sprint suivant.

## Estimation

- HAUTE traitées : 3 × ~15 min = ~45 min
- Tests XCUI : ~30 min

**Total cette passe** : ~1 h 15.
