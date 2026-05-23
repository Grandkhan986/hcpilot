# Parcours 4 — Consentement signature flow

**Audité contre** : commit `8582c557` (état `main` après parcours 3).
**Brief de référence** : `Roadmap/brief-hcpilot.md` §"Workflow consentement signature".

---

## Description du parcours

> Depuis une session → sélection formulation → ConsentFlowView checkpoints → SignatureCanvasView → confirmation → génération PDF → upload

Le consentement signé est la **trace HIPAA** de l'autorisation client. Sans ce document, la nurse n'a pas le droit d'administrer l'IV. C'est le flow le plus critique en termes de conformité réglementaire.

## Séquence nominale telle qu'implémentée

| # | Écran | Fichier | Action |
|---|---|---|---|
| 1 | SessionDetailView | [SessionsListView.swift:152](../ios/HCPilotApp/Views/SessionsListView.swift#L152) | Tap "Recueillir le consentement" |
| 2 | ConsentFlowView sheet | [ConsentFlowView.swift](../ios/HCPilotApp/Views/ConsentFlowView.swift) | s'ouvre |
| 3 | Step 0 — FormulationStep | [ConsentFlowView.swift:75](../ios/HCPilotApp/Views/ConsentFlowView.swift#L75) | Sélection standing order parmi les SO actives nurse |
| 4 | Step 1 — ConsentTextStep | [ConsentFlowView.swift:155](../ios/HCPilotApp/Views/ConsentFlowView.swift#L155) | Lecture du texte (snapshot SO) |
| 5 | Step 2 — CheckpointsStep | [ConsentFlowView.swift:187](../ios/HCPilotApp/Views/ConsentFlowView.swift#L187) | 4 Toggle obligatoires |
| 6 | Step 3 — SignatureStep | [ConsentFlowView.swift:229](../ios/HCPilotApp/Views/ConsentFlowView.swift#L229) | PKCanvasView signature |
| 7 | submit() | [ConsentFlowView.swift:364](../ios/HCPilotApp/Views/ConsentFlowView.swift#L364) | PNG → PDF (ConsentPDFBuilder) → POST /consents |
| 8 | Alert succès + dismiss | [ConsentFlowView.swift:61](../ios/HCPilotApp/Views/ConsentFlowView.swift#L61) | retour SessionDetailView avec status "Signé" |

## Variantes testées

| Variante | Observé |
|---|---|
| Nominal (SO active + 4 checkpoints + signature) | ✅ Génère PDF + POST |
| Aucune standing order active | ❌ ProgressView infini sans empty state |
| Checkpoints partiels | ✅ Bouton "Continuer" désactivé |
| Signature vide | ✅ Bouton "Confirmer" désactivé |
| Signature microscopique (point unique) | ❌ Accepté car drawing.bounds.isEmpty=false |
| Fermer après checkpoints validés | ❌ Perte silencieuse |

## Issues détectées par persona

### 🧑‍⚕️ Sarah (RN technophile)

| Sév. | Issue |
|---|---|
| **HAUTE** | Tap "Fermer" sans confirm si elle a fait des steps → perte du travail (et pire : si le client a signé, Sarah peut perdre la signature). |
| **MOYENNE** | Pas de prévisualisation du PDF avant POST — Sarah ne voit le rendu HIPAA qu'après envoi. |

### 🧑‍⚕️ Linda (NP prudente)

| Sév. | Issue |
|---|---|
| **HAUTE** | Le consent text est dans une ScrollView mais le bouton "J'ai lu, continuer" est actif sans avoir scrollé en bas. Pour un consentement éclairé, ça affaiblit la garantie HIPAA. |
| **MOYENNE** | Pas de mention claire que le PDF sera envoyé au client par email automatiquement (ou pas). |

### 🧑‍⚕️ Jessica (multitâche)

| Sév. | Issue |
|---|---|
| **HAUTE** | Aucun garde-fou si Jessica est interrompue. Le client peut signer puis Jessica ferme par réflexe → POST jamais fait → consentement perdu. |
| **MOYENNE** | Le client signe en partiel quand Jessica est appelée → pas de "pause/reprise" possible. |

### 🧑‍⚕️ Maria (RN débutante)

| Sév. | Issue |
|---|---|
| **CRITIQUE** | Si Maria n'a pas encore configuré de Standing Order (parcours 1 incomplet), elle voit un `ProgressView` infini sur le Step 0. Aucun empty state, aucun CTA "Aller configurer une SO". Bloquant total. |
| **HAUTE** | Une signature d'1 point microscopique passe la validation (drawing.bounds non vide) — Maria pourrait valider par erreur un consentement non-signé. |
| **MOYENNE** | "Standing order" — terme métier expliqué brièvement mais sans contexte juridique (qui le signe ? pourquoi ? sa validité ?). |

## Issues consolidées

### CRITIQUE (1)

- **C-50** Pas d'empty state si aucune standing order active → `ProgressView` infini → blocage complet.

### HAUTE (5)

- **H-51** "Fermer" sans confirm dans le wizard → perte de travail / signature.
- **H-52** `accessibilityIdentifier` absents partout.
- **H-53** Pas de hint visuel "Signer ici" sur le canvas (le client peut hésiter à toucher).
- **H-54** "J'ai lu, continuer" actif sans scroll-to-bottom du consent text.
- **H-55** Signature microscopique (1 point) acceptée — validation par bounds insuffisante.

### MOYENNE (4)

- **M-56** Pas de prévisualisation PDF avant POST.
- **M-57** ProgressView infini sans timeout sur loadFormulations.
- **M-58** ProgressDots non accessibles (juste visuel, pas de label VoiceOver).
- **M-60** Pas de comm explicite "Le PDF est conservé localement et chiffré + envoyé serveur HIPAA".

### BASSE (2)

- **B-59** Pas d'agrandissement canvas signature pour iPad.
- **B-61** Pas de bouton "Réinitialiser le wizard" si Maria veut tout recommencer.

## Corrections cette passe

| Issue | Action |
|---|---|
| **C-50** | Empty state visible si `standingOrders.isEmpty` après load : message + CTA vers Conformité. |
| **H-51** | confirmationDialog sur "Fermer" si `step > 0`. |
| **H-52** | `accessibilityIdentifier` sur tous les boutons / étapes / champs. |
| **H-55** | Validation longueur minimale : `drawing.bounds.width >= 40 && height >= 20`. |

## Déférés (TODO-improvements.md)

H-53 / H-54 / M-56 / M-57 / M-58 / M-60 / B-59 / B-61.

## Estimation

- CRITIQUE : 1 traitée
- HAUTE : 3 traitées (H-51/H-52/H-55), 2 différées (H-53/H-54)
- MOYENNE / BASSE : 6 différées
- Tests XCUI : ~30 min

**Total cette passe** : ~1 h 45.
