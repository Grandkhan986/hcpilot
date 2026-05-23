# Parcours 8 — Comportement offline

**Audité contre** : commit `5b1ea8eb` (état `main` après parcours 7).
**Brief de référence** : `Roadmap/brief-hcpilot.md` §"Gestion offline".

---

## Description du parcours

> Couper réseau → action mutation (création client, démarrage session) → vérification queue → reconnecter → vérification drain et resync

## Architecture en place

| Composant | Fichier | Rôle |
|---|---|---|
| ConnectivityState | [ConnectivityState.swift](../ios/HCPilotApp/Utils/ConnectivityState.swift) | `isOffline`, `lastSyncAt`, `oldestCachedAt` (singleton MainActor) |
| MutationQueue | [MutationQueue.swift](../ios/HCPilotApp/Utils/MutationQueue.swift) | File de PendingMutation persistée (JSON) |
| OfflineCache | [OfflineCache.swift](../ios/HCPilotApp/Utils/OfflineCache.swift) | Cache GET responses |
| APIService.queuedPost(Action/Delete) | [APIService.swift](../ios/HCPilotApp/Services/APIService.swift) | Catch network errors → enqueue + throw QueuedError.enqueued |
| ContentView offline banner | [ContentView.swift](../ios/HCPilotApp/ContentView.swift) | Affiché si `isOffline && isAuthenticated` |
| SyncStatusBadge (Home) | [SyncStatusBadge.swift](../ios/HCPilotApp/Views/Components/SyncStatusBadge.swift) | 4 états sync |
| MutationQueueView (Profil) | [MutationQueueView.swift](../ios/HCPilotApp/Views/MutationQueueView.swift) | Inspection + force sync + clear |

## Variantes testées

| Variante | Observé |
|---|---|
| GET offline (cache OK) | ✅ Sert depuis OfflineCache, banner affiché |
| GET offline (pas de cache) | ⚠️ Erreur opaque propagée |
| `startSession` offline (queuedPostAction) | ✅ Enqueue + retour QueuedError.enqueued |
| `recordUsage` offline (queuedPost) | ✅ Enqueue |
| `deleteSession` offline (queuedDelete) | ✅ Enqueue |
| **`createClient` offline (post)** | ❌ Échec brut — PAS enqueue |
| **`updateClient` offline (put)** | ❌ Échec brut — PAS enqueue |
| Acknowledge alerte offline | ⚠️ Échec — pas dans la liste des queueables |
| Reconnexion + GET réussi | ✅ Drain auto (Task in cachedGet) |
| Re-tap Start sur session déjà queueed | ❌ Double mutation enqueuee (pas de dédoublonnage) |

## Issues détectées par persona

### 🧑‍⚕️ Sarah (RN technophile)

| Sév. | Issue |
|---|---|
| **CRITIQUE** | Création client en zone sans réseau → erreur opaque. Brief explicite "création client" comme cas offline. |
| **HAUTE** | Detection offline passive absente : tant qu'aucun appel n'échoue, l'app croit être en ligne (même 30 min plus tard dans le métro). Pas de `NWPathMonitor`. |
| **MOYENNE** | "Forcer la synchronisation" dans MutationQueueView sans loading state. |

### 🧑‍⚕️ Linda (NP prudente)

| Sév. | Issue |
|---|---|
| **HAUTE** | Quand offline + tap Modifier client → erreur "NSURLErrorDomain -1009". Pas explicable pour Linda. Devrait dire "Vous êtes hors-ligne. La modification sera enregistrée à la reconnexion." |
| **MOYENNE** | "Vider la file (sans sync)" sans confirm → risque perte data. |

### 🧑‍⚕️ Jessica (multitâche)

| Sév. | Issue |
|---|---|
| **HAUTE** | Re-tap "Commencer" sur une session pendant offline → 2 mutations enqueuees pour le même endpoint. Au drain, 2 POST → backend idempotent OK mais log audit dupliqué. |
| **MOYENNE** | Banner offline disparaît au 1ᵉʳ GET réussi mais Jessica peut louper la transition (banner visible 0.3s). |

### 🧑‍⚕️ Maria (débutante)

| Sév. | Issue |
|---|---|
| **HAUTE** | "X actions en attente" sur SyncStatusBadge / Profil — Maria ne comprend pas ce que c'est. Pas d'aide contextuelle. |
| **MOYENNE** | Banner orange "Mode hors-ligne · 3 actions en attente" — Maria pense qu'il faut faire qqch (alors que la sync se fait auto). |

## Issues consolidées

### CRITIQUE (1)

- **C-94** Création client / modif client offline non queueable → erreur brute. Brief explicite ce besoin.

### HAUTE (4)

- **H-95** Pas de detection offline passive (NWPathMonitor). On découvre l'offline uniquement à l'échec.
- **H-96** Pas de dédoublonnage queue : mutations identiques s'accumulent.
- **H-97** Erreurs réseau opaques pour les méthodes non-queue.
- **H-98** `accessibilityIdentifier` absents (MutationQueueView, banner).

### MOYENNE (4)

- **M-99** Glossaire / aide contextuelle absent sur MutationQueueView pour utilisateurs néophytes.
- **M-100** "Forcer la synchronisation" sans feedback de progression.
- **M-101** "Vider la file" sans confirmationDialog.
- **M-102** Banner transient mal perçu (apparaît / disparaît trop vite).

### BASSE (0)

## Corrections cette passe

| Issue | Action |
|---|---|
| **C-94** | `createClient` passé en `queuedPost` → enqueue si réseau down. |
| **H-96** | Dédoublonnage dans MutationQueue.enqueue : si (endpoint, method) identique dans les 5 dernières secondes, skip. |
| **H-98** | accessibilityIdentifier sur MutationQueueView (cards, boutons). |
| **M-101** | confirmationDialog sur "Vider la file (sans sync)". |
| **M-100** | Loading state sur "Forcer la synchronisation". |

## Déférés (TODO-improvements.md)

H-95 (NWPathMonitor), H-97 (errors user-friendly), M-99 (glossaire), M-102 (banner persistence).

## Estimation

- CRITIQUE : 1 traitée (~15 min)
- HAUTE : 2 traitées (H-96 + H-98), 2 différées
- MOYENNE : 2 traitées (M-100 + M-101), 2 différées
- Tests XCUI : limité (offline difficile à tester en XCUI sans tooling) ~30 min

**Total cette passe** : ~1 h 30.
