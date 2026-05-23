# Parcours 3 — Création d'un client

**Audité contre** : commit `cca7c192` (état `main` après parcours 2).
**Brief de référence** : `Roadmap/brief-hcpilot.md` §"Création client" (5 sous-étapes : Identité, Adresse, Médical, Urgence, Récap).

---

## Description du parcours

> Tab bar Clients → CTA + → ClientFormView → saisie complète (incl. allergies/conditions multi-select) → validation

C'est le 2ᵉ flow par fréquence d'usage (après création de session). Une nurse IV mobile gère typiquement 30-60 clients. La friction sur ce form impacte directement sa productivité.

## Séquence nominale telle qu'implémentée

| # | Élément | Fichier | Détail |
|---|---|---|---|
| 1 | Tab Clients | [AppMainView.swift](../ios/HCPilotApp/Views/AppMainView.swift) | tab.clients |
| 2 | Bouton `+` toolbar | [ClientsView.swift:80-83](../ios/HCPilotApp/Views/ClientsView.swift#L80-L83) | Ouvre sheet ClientFormView(mode: .create) |
| 3 | Section Identité | [ClientFormView.swift:52-62](../ios/HCPilotApp/Views/ClientFormView.swift#L52-L62) | Prénom, Nom, Genre (Picker H/F), DOB (TextField) |
| 4 | Section Contact | [ClientFormView.swift:64-70](../ios/HCPilotApp/Views/ClientFormView.swift#L64-L70) | Email, Téléphone |
| 5 | Section Adresse | [ClientFormView.swift:72-84](../ios/HCPilotApp/Views/ClientFormView.swift#L72-L84) | line1, line2, city, stateCode (TextField), postalCode, accessNotes |
| 6 | Section Médical | [ClientFormView.swift:86-105](../ios/HCPilotApp/Views/ClientFormView.swift#L86-L105) | Allergies/Conditions en chips (ChipMultiSelect), Médications en CSV |
| 7 | Section Contact urgence | [ClientFormView.swift:107-111](../ios/HCPilotApp/Views/ClientFormView.swift#L107-L111) | Name + Phone |
| 8 | Toolbar Enregistrer | [ClientFormView.swift:126-129](../ios/HCPilotApp/Views/ClientFormView.swift#L126-L129) | Disabled si firstName/lastName vides |

**Validation actuelle** : `firstName.isEmpty || lastName.isEmpty || isSaving` → bouton désactivé. Aucune autre validation client-side.

## Variantes testées

| Variante | Observé |
|---|---|
| Identité minimale (prénom + nom seulement) | ✅ Création possible |
| Date naissance invalide (`abc`) | ❌ Backend reçoit la string brute, peut accepter |
| Email malformé | ❌ Pas de validation |
| Phone non US | ❌ Pas de validation |
| State code en minuscules | ⚠️ TextField allCaps mais cohérence faible |
| "Annuler" avec saisie en cours | ❌ Perte silencieuse |
| Réseau coupé pendant save | ⚠️ Erreur générique |

## Issues détectées par persona

### 🧑‍⚕️ Sarah (RN solo, technophile)

| Sév. | Issue |
|---|---|
| **HAUTE** | DOB en `TextField "YYYY-MM-DD"` — Sarah tape vite et risque le typo ("198/03/15"). Pas de DatePicker comme dans le SetupWizard. |
| **HAUTE** | Pas de validation email/phone côté UI → erreur 422 silencieuse au save. |
| **MOYENNE** | Pas d'autocomplete d'adresse (Apple Maps) → 5 champs à taper manuellement. |

### 🧑‍⚕️ Linda (NP prudente)

| Sév. | Issue |
|---|---|
| **HAUTE** | Aucune mention HIPAA / stockage des PHI dans le form. Linda hésite à saisir DOB et adresse complète. |
| **MOYENNE** | "Code accès / étage / parking" — Linda lit le label, comprend mais aurait apprécié une indication "Pour vous aider à arriver chez le client, jamais partagé". |
| **MOYENNE** | Allergies/Conditions presets incomplets : pas de "Diabète type 1", "Hépatite", "VIH", "Cancer en rémission"... |

### 🧑‍⚕️ Jessica (multitâche)

| Sév. | Issue |
|---|---|
| **HAUTE** | "Annuler" sans confirm → si Jessica est interrompue après 4 sections saisies, tap "Annuler" par erreur perd tout. |
| **MOYENNE** | Pas de sauvegarde brouillon entre relances. |

### 🧑‍⚕️ Maria (RN débutante)

| Sév. | Issue |
|---|---|
| **HAUTE** | Gender Picker uniquement "Homme/Femme/—". Pas d'option "Non spécifié" / "Autre". Patient soucieux d'identité de genre ne pourra pas se reconnaître. |
| **HAUTE** | `stateCode` en TextField (autocapitalization allCharacters) alors que SetupWizard utilise Picker. Incohérence + Maria peut taper "Californie" au lieu de "CA". |
| **MOYENNE** | Médications en CSV ("Metformine 1000mg, Lisinopril 10mg") — Maria peut oublier la virgule. Idéalement chips/list. |
| **MOYENNE** | Champ Email/Phone facultatifs mais aucune indication explicite. |

## Issues consolidées

### CRITIQUE (0)

Aucune. Le form est fonctionnel sur le chemin nominal.

### HAUTE (7)

- **H-36** DOB en TextField → DatePicker.
- **H-37** Validation email format pré-submit.
- **H-38** Validation phone US format pré-submit.
- **H-39** Gender Picker : ajouter "Autre" / "Non spécifié".
- **H-40** stateCode en Picker (cohérence avec SetupWizard).
- **H-41** `accessibilityIdentifier` absents.
- **H-42** Confirm "Annuler" si dirty.

### MOYENNE (5)

- **M-43** Autocomplete d'adresse (Apple Maps / MKLocalSearchCompleter).
- **M-44** Médications en chips / list (au lieu de CSV).
- **M-45** Mention HIPAA / data storage inline.
- **M-46** Étoffer presets allergies/conditions.
- **M-48** Indication explicite "Email/Phone facultatifs".

### BASSE (2)

- **B-47** "Code accès / étage / parking" — micro-label rassurant.
- **B-49** Format DOB affiché plus naturel (medium style).

## Corrections cette passe (HAUTE en bloc)

| Issue | Action |
|---|---|
| H-36 | DOB → DatePicker (édit `Date?` → string ISO). Garder `accessNotes` et autres champs string. |
| H-37/H-38 | Validators dans `save()` + UI temps-réel sous champ. |
| H-39 | Picker Gender : ajouter "Autre" (`O`) et "Non spécifié" (`U`). |
| H-40 | stateCode → Picker (USStates.codes). |
| H-41 | accessibilityIdentifier sur tous les champs + boutons. |
| H-42 | confirmationDialog sur "Annuler" si form dirty. |

## Déférés (TODO-improvements.md)

M-43 (autocomplete adresse, MKLocalSearchCompleter), M-44 (médications chips), M-45 (HIPAA inline), M-46 (presets +), M-48 (labels facultatif), B-47/B-49.

## Estimation

- HAUTE traitées : 7 × ~10 min = ~70 min
- Tests XCUI : ~30 min
- **Total cette passe** : ~1 h 45.
