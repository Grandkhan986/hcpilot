# Parcours 9 — Paramètres profil & sécurité

**Audité contre** : commit `51cf5377` (état `main` après parcours 8).
**Brief de référence** : `Roadmap/brief-hcpilot.md` §"Sécurité" + §"Notifications".

---

## Description du parcours

> Tab Profil → Sécurité → modification timeout auto-logout → toggle notifications → modification fréquence audit MD → persistance après relaunch

## Séquence nominale telle qu'implémentée

| # | Élément | Fichier | Détail |
|---|---|---|---|
| 1 | Tab Profil | tab.profil | ProfileView |
| 2 | Header (avatar + nom + role) | [ProfileView.swift:11-30](../ios/HCPilotApp/Views/ProfileView.swift#L11-L30) | Lit `authViewModel.user` |
| 3 | Menu : Mon profil / Notifications / Sécurité / Audit / Synchro / Fournisseur / Légal | [ProfileView.swift:33-86](../ios/HCPilotApp/Views/ProfileView.swift#L33-L86) | NavigationLinks |
| 4 | SecuritySettingsView | [SecuritySettingsView.swift](../ios/HCPilotApp/Views/SecuritySettingsView.swift) | Picker timeout 5/15/30/60 → UserDefaults |
| 5 | NotificationsView | [NotificationsView.swift](../ios/HCPilotApp/Views/NotificationsView.swift) | Permission + counts + test + tout annuler |
| 6 | Édition fréquence audit MD | **(manquante)** | SetupWizardView re-crée ; pas d'édition d'un MD existant |
| 7 | Persistance après relaunch | UserDefaults (timeout) + Keychain (session) | ✅ |

## Variantes testées

| Variante | Observé |
|---|---|
| Modif timeout 30 → 60 min | ✅ Persiste après kill + relaunch |
| Tap "Verrouiller maintenant" | ⚠️ Logout immédiat sans confirm |
| Tap "Tout annuler" notifications | ⚠️ Pas de confirm (mais reversible via refresh) |
| Notification permission notDetermined → demander | ✅ |
| Édition MD existant (audit frequency, dates contrat) | ❌ Pas d'UI |

## Issues détectées par persona

### 🧑‍⚕️ Sarah (RN technophile)

| Sév. | Issue |
|---|---|
| **HAUTE** | Pas de toggle granulaire par type de notification (compliance / sessions / inventaire). Bouton "Tout annuler" trop radical. |
| **HAUTE** | Pas d'UI pour modifier la fréquence d'audit MD (alors que c'est explicitement mentionné dans le parcours brief). SetupWizard re-crée le MD. |
| **MOYENNE** | Options timeout 5/15/30/60. Sarah voudrait 120 min car elle est souvent en tournée 8h. |

### 🧑‍⚕️ Linda (NP prudente)

| Sév. | Issue |
|---|---|
| **HAUTE** | "Verrouiller maintenant" sans confirm — Linda peut taper par erreur et se déconnecter. |
| **MOYENNE** | "Brief Sprint 6" section sur NotificationsView — jargon interne. Linda ne comprend pas "J-90" etc. |

### 🧑‍⚕️ Jessica (multitâche)

| Sév. | Issue |
|---|---|
| **MOYENNE** | Pas de bouton "Synchroniser maintenant" global (existe seulement dans MutationQueueView). |

### 🧑‍⚕️ Maria (débutante)

| Sév. | Issue |
|---|---|
| **MOYENNE** | Section "Brief Sprint 6" — Maria comprend rien. Devrait être caché en prod. |
| **HAUTE** | ProfileMenuItem (genre "Mon profil", "Messages", "Revenus") sont des `Button(action: {})` no-ops. Maria tape et rien ne se passe. |
| **MOYENNE** | Header avatar bleu sans photo — Maria voudrait personnaliser. |

## Issues consolidées

### CRITIQUE (0)

Aucune.

### HAUTE (5)

- **H-103** Pas de toggles granulaire par type de notification.
- **H-104** Pas d'UI éditable pour MD existant (modifier audit frequency + dates).
- **H-105** "Verrouiller maintenant" sans confirm.
- **H-106** `accessibilityIdentifier` absents (SecuritySettings, Notifications).
- **H-112** ProfileMenuItem no-op sur "Mon profil", "Messages", "Revenus", "Factures", "Paiements", "Paramètres". Maria tape → rien.

### MOYENNE (4)

- **M-107** "Brief Sprint 6" — jargon interne, à cacher en prod.
- **M-108** Options timeout limitées (5/15/30/60). Étendre à 120/240.
- **M-109** "Synchroniser maintenant" global manquant.
- **M-113** Pas de feedback visuel "Modifications enregistrées" sur SecuritySettings (Picker auto-save silencieux).

### BASSE (1)

- **B-110** Avatar uniforme — feature "upload photo" différée.

## Corrections cette passe

| Issue | Action |
|---|---|
| **H-103** | Toggles `@AppStorage` pour activer/désactiver chaque catégorie de notifications. NotificationService check le flag avant `scheduleAt`. |
| **H-105** | confirmationDialog sur "Verrouiller maintenant". |
| **H-106** | accessibilityIdentifier sur les contrôles. |
| **H-112** | ProfileMenuItem no-op → désactivés visuellement (.disabled) OU retirés. On désactive pour MVP. |
| **M-107** | Section "Brief Sprint 6" sous `#if DEBUG`. |
| **M-108** | Étendre options timeout à 5/15/30/60/120. |

## Déférés (TODO-improvements.md)

H-104 (édition MD), M-109 (sync global), M-113 (feedback save), B-110 (photo).

## Estimation

- HAUTE : 4 traitées (H-103/H-105/H-106/H-112), 1 différée
- MOYENNE : 2 traitées (M-107/M-108), 2 différées
- Tests XCUI : ~30 min

**Total cette passe** : ~1 h 30.
