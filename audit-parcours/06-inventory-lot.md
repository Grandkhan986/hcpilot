# Parcours 6 — Ajout d'un lot d'inventaire

**Audité contre** : commit `0c9c921f` (état `main` après parcours 5).
**Brief de référence** : `Roadmap/brief-hcpilot.md` §"Stock et scan".

---

## Description du parcours

> Tab Stock → CTA Scanner → BarcodeScannerView (mock barcode si simulateur) → LotEntryView saisie → ajout → vérification dans liste

Flow indispensable pour la traçabilité FDA : chaque lot reçu doit être scanné et tracé jusqu'à son utilisation. La nurse l'enchaîne lors d'une livraison.

## Séquence nominale telle qu'implémentée

| # | Étape | Fichier | Détail |
|---|---|---|---|
| 1 | Tab Stock | [AppMainView.swift](../ios/HCPilotApp/Views/AppMainView.swift) | tab.stock |
| 2 | CTA "Scanner" (toolbar) | [InventoryListView.swift:53-59](../ios/HCPilotApp/Views/InventoryListView.swift#L53-L59) | Sheet AddLotFlow |
| 3 | BarcodeScannerView | [BarcodeScannerView.swift](../ios/HCPilotApp/Views/BarcodeScannerView.swift) | Caméra AVFoundation OU saisie manuelle |
| 4 | Permission caméra denied / simu | [BarcodeScannerView.swift:70-95](../ios/HCPilotApp/Views/BarcodeScannerView.swift#L70-L95) | "Caméra indisponible" + fallback manuel |
| 5 | onDetected → checkExistingProduct | [AddLotFlow.swift:26-44](../ios/HCPilotApp/Views/AddLotFlow.swift#L26-L44) | findLotsByBarcode → pré-remplit si connu |
| 6 | LotEntryView form | [AddLotFlow.swift:47-127](../ios/HCPilotApp/Views/AddLotFlow.swift#L47-L127) | Produit, Lot, Acquisition |
| 7 | "Ajouter" | [AddLotFlow.swift:138-163](../ios/HCPilotApp/Views/AddLotFlow.swift#L138-L163) | POST /inventory/lots → onSaved → refresh liste |

## Variantes testées

| Variante | Observé |
|---|---|
| Simulateur (pas de caméra) | ✅ cameraDeniedView + saisie manuelle |
| Barcode déjà connu (lot_001) | ✅ Pré-remplit productName / category / supplier / unitCost |
| Barcode inconnu | ✅ Form vierge, à remplir |
| Quantité 0 | ⚠️ Stepper min=1 (jamais 0) — bon |
| Péremption dans le passé | ❌ Aucun warning |
| Péremption < 30 jours | ❌ Aucun warning |
| Annuler avec saisie en cours | ❌ Perte silencieuse |
| Plusieurs scans consécutifs | ❌ Doit fermer puis rouvrir |

## Issues détectées par persona

### 🧑‍⚕️ Sarah (RN technophile)

| Sév. | Issue |
|---|---|
| **HAUTE** | Annuler LotEntryView avec form rempli → perte sans confirm. Sarah qui scanne 10 lots à la suite peut perdre une saisie par tap accidentel. |
| **HAUTE** | Pas d'`accessibilityIdentifier` sur les champs / boutons. |
| **MOYENNE** | Pas de scan multiple consécutif. Sarah doit fermer + rouvrir le sheet entre chaque lot. |

### 🧑‍⚕️ Linda (NP prudente)

| Sév. | Issue |
|---|---|
| **HAUTE** | Catégorie picker affiche les raw values capitalized ("Nad", "Saline"). Linda ne reconnaît pas "Nad" comme "NAD+" — risque de mauvaise catégorisation. |
| **MOYENNE** | Aucun warning si péremption < 30j (le stepper accepte n'importe quoi). |
| **MOYENNE** | "Coût unitaire (€)" — Linda US pense en $. Brief : EUR pour cette itération, mais à terme à corriger. |
| **MOYENNE** | Pas de mention de la traçabilité FDA (à quoi sert ce lot ?). |

### 🧑‍⚕️ Jessica (interrompue)

| Sév. | Issue |
|---|---|
| **HAUTE** | Couplée à H-75 : Jessica scanne 5 lots, ferme accidentellement le sheet, perd la 5ᵉ saisie. |
| **MOYENNE** | Pas de scan en chaîne — re-friction (M-80). |

### 🧑‍⚕️ Maria (RN débutante)

| Sév. | Issue |
|---|---|
| **HAUTE** | "Catégorie" — Maria ne sait pas où classer un produit (NAD+ → "nad" ou "medication" ?). Pas de hint. |
| **MOYENNE** | "Numéro de lot" — pas de hint "Vous le trouverez sur l'étiquette du flacon". |
| **MOYENNE** | "Saisie manuelle" — TextField keyboardType `.numberPad`. Maria ne peut pas saisir les codes Code-128 qui ont des lettres (rare pharma, mais possible). |

## Issues consolidées

### CRITIQUE (0)

Aucune.

### HAUTE (4)

- **H-75** Annuler LotEntryView sans confirm si dirty.
- **H-76** `accessibilityIdentifier` absents.
- **H-77** Labels catégorie peu lisibles ("Nad" → "NAD+", "Saline" → "Sérum physiologique", etc.).
- **H-78** Saisie manuelle keyboardType `.numberPad` limitant — devrait être `.default` ou `.asciiCapable` pour Code-128.

### MOYENNE (4)

- **M-79** Pas de warning UX si péremption < 30j ou < J-0.
- **M-80** Pas de scan multiple consécutif (re-friction inutile pour livraison de stock).
- **M-81** CTA "Scanner" est un petit icône dans la toolbar — pas évident pour Maria.
- **M-82** Pas de filtre par catégorie sur InventoryListView.

### BASSE (2)

- **B-83** Devise EUR (différée passage anglais).
- **B-84** Cadre détection statique (cosmetic).

## Corrections cette passe

| Issue | Action |
|---|---|
| **H-75** | confirmationDialog sur "Annuler" du LotEntryView si dirty. |
| **H-76** | accessibilityIdentifier sur tous les contrôles. |
| **H-77** | Labels catégorie via fonction de mapping : nad → "NAD+", vitamins → "Vitamines", saline → "Sérum physiologique", medication → "Médicament", supplies → "Fournitures", other → "Autre". |
| **H-78** | Saisie manuelle keyboardType `.default` (autocapitalization off, no autocorrect). |

## Déférés (TODO-improvements.md)

M-79 / M-80 / M-81 / M-82, B-83 / B-84.

## Estimation

- HAUTE traitées : 4 × ~10 min = ~40 min
- Tests XCUI : ~30 min

**Total cette passe** : ~1 h 10.
