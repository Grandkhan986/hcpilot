# Parcours 10 — Audit logs & historique

**Audité contre** : commit `2c3fe65a` (état `main` après parcours 9).
**Brief de référence** : `Roadmap/brief-hcpilot.md` §"Audit logs HIPAA".

---

## Description du parcours

> Depuis Profil → consultation Audit logs → filtrage par entity_type → tap sur entrée → détails changes

## Séquence nominale telle qu'implémentée

| # | Élément | Fichier | Détail |
|---|---|---|---|
| 1 | Profil → "Journal d'audit (HIPAA)" | [ProfileView.swift:51-53](../ios/HCPilotApp/Views/ProfileView.swift#L51-L53) | NavigationLink → AuditLogView |
| 2 | Filter picker segmented | [AuditLogView.swift:22-30](../ios/HCPilotApp/Views/AuditLogView.swift#L22-L30) | Tous / Consentements / Clients / Sessions / Stock |
| 3 | Liste AuditRow | [AuditLogView.swift:48-53](../ios/HCPilotApp/Views/AuditLogView.swift#L48-L53) | entry.entityType + action + id + changes (lineLimit 2) + timestamp + IP |
| 4 | Tap sur entrée → détail | **(manquant)** | List sans NavigationLink |

## Variantes testées

| Variante | Observé |
|---|---|
| Filtre "Tous" | ✅ |
| Filtre "Sessions" | ✅ |
| Tap row pour détail | ❌ Aucun handler |
| Pull-to-refresh | ✅ |
| Liste vide | ✅ Empty state correct |
| Changes longues | ❌ Truncated à 2 lignes — peut perdre de l'info HIPAA |
| Export | ❌ Aucun |

## Issues détectées par persona

### 🧑‍⚕️ Sarah (RN technophile)

| Sév. | Issue |
|---|---|
| **HAUTE** | Tap sur entrée → pas de détail. Le brief explicite "tap sur entrée → détails changes". |
| **HAUTE** | Changes tronquées à 2 lignes → info HIPAA potentiellement perdue. |
| **MOYENNE** | Pas d'export CSV/PDF pour audit externe (auditeur RAC, HIPAA). |

### 🧑‍⚕️ Linda (NP prudente)

| Sév. | Issue |
|---|---|
| **HAUTE** | Pas de filtre par action (create / update / delete / export). Linda veut voir uniquement les "delete" suspects. |
| **MOYENNE** | Pas de recherche par entityId ou client_id. |

### 🧑‍⚕️ Jessica (multitâche)

| Sév. | Issue |
|---|---|
| **MOYENNE** | Pas de pagination — limite hardcodée 100, sans "Charger plus". |

### 🧑‍⚕️ Maria (débutante)

| Sév. | Issue |
|---|---|
| **MOYENNE** | "Stock (mvt)" — terme ambigu pour utilisateur novice. |
| **MOYENNE** | "IP: 192.168.1.42" — Maria ne sait pas pourquoi c'est important. |

## Issues consolidées

### CRITIQUE (0)

Aucune (la fonctionnalité existe mais incomplète).

### HAUTE (4)

- **H-114** Tap sur entrée → pas de détail (brief explicite).
- **H-115** Changes truncated à 2 lignes (perte info HIPAA).
- **H-116** Pas de bouton export (CSV/PDF).
- **H-117** `accessibilityIdentifier` absents.

### MOYENNE (4)

- **M-118** Pas de filtre par action.
- **M-119** Pas de recherche.
- **M-120** Pas de pagination.
- **M-121** "Stock (mvt)" terme ambigu.

### BASSE (1)

- **B-122** Pas de timeline visuelle.

## Corrections cette passe

| Issue | Action |
|---|---|
| **H-114** | `AuditLogDetailView` accessible au tap (NavigationLink) avec tous les champs détaillés. |
| **H-115** | Vue détail affiche `changes.displayString` sans truncation. |
| **H-117** | accessibilityIdentifier sur Picker + rows par entry.id. |
| **M-121** | "Stock (mvt)" → "Mouvement de stock". |

## Déférés (TODO-improvements.md)

H-116 (export), M-118 (filtre action), M-119 (recherche), M-120 (pagination), B-122.

## Estimation

- HAUTE : 3 traitées (H-114/H-115/H-117), 1 différée (H-116)
- MOYENNE : 1 traitée (M-121), 3 différées
- Tests XCUI : ~30 min

**Total cette passe** : ~1 h 15.
