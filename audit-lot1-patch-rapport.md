# Rapport — Patch Lot 1 (6 issues post-audit)

**Date** : 2026-05-24
**Branche** : `main`
**Référence audit** : Lot 1 (6 fichiers de la mission 4 critiques déférées)
**Estimation initiale** : 3–4 h
**Effort réel** : ~2 h (commits hygiène inclus)

---

## 1. Statut des 6 issues

| Issue | Sévérité | Statut | Commit | Tests ajoutés |
|---|---|---|---|---|
| **P-12** — InvoiceService idempotent | CRITIQUE | ✅ Résolu | [`f5144929`](https://github.com/Grandkhan986/hcpilot/commit/f5144929) | 5 |
| **P-16** — VitalsEntryView validation physiologique | MOYENNE | ✅ Résolu | [`35072043`](https://github.com/Grandkhan986/hcpilot/commit/35072043) | 7 |
| **P-17** — VitalsEntryView warnings accessibles | MOYENNE | ✅ Résolu | [`35072043`](https://github.com/Grandkhan986/hcpilot/commit/35072043) | (couvert par UI/non-régression) |
| **P-8** — Reset annuel compteur invoice | MOYENNE | ✅ Résolu | [`57b5bb46`](https://github.com/Grandkhan986/hcpilot/commit/57b5bb46) | 2 |
| **P-14** — PaymentMethod enum + displayName | BAS-MOYEN | ✅ Résolu | [`8d494aa5`](https://github.com/Grandkhan986/hcpilot/commit/8d494aa5) | 3 |
| **P-4** — InvoicePDFBuilder doc alignment | BAS-MOYEN | ✅ Résolu | [`c2ca44ea`](https://github.com/Grandkhan986/hcpilot/commit/c2ca44ea) | 0 (alignement code/doc + #if DEBUG guard) |

**Total tests ajoutés : 17** (15 nouveaux + 2 ajustés). Tous verts, aucune régression sur l'existant.

---

## 2. Détail par issue

### P-12 — InvoiceService idempotent (CRITIQUE)

**Cause** : le docstring annonçait l'idempotence mais le code régénérait une nouvelle Invoice à chaque appel — risque de doublons en cas de retry, double-tap, ou redémarrage app au milieu du flow complete.

**Fix** : extension `InvoiceLocalStore` avec deux nouvelles maps UserDefaults :
- `invoice.sessionMap` : `sessionId → invoiceId`
- `invoice.metadata` : `invoiceId → Invoice` (JSON sérialisé)

`InvoiceService.generateInvoiceForCompletedSession` court-circuite si `loadInvoice(forSession:)` retourne une Invoice. Sinon génération normale, puis `recordInvoice` AVANT le POST backend pour garantir l'idempotence côté client même en cas d'échec réseau.

**Choix technique** : sérialisation complète en JSON (vs simple stockage de `(invoiceId, invoiceNumber)`) pour éviter le recalcul depuis la Session — qui pourrait avoir muté entre les 2 appels (montant, date, formulation). Rebuild fidèle.

**Tests** ([InvoiceServiceIdempotenceTests.swift](ios/HCPilotAppTests/InvoiceServiceIdempotenceTests.swift)) :
1. Même session → même id + même numéro
2. Compteur non incrémenté sur le retry idempotent
3. Sessions distinctes → invoices distinctes avec numéros séquentiels
4. `loadInvoice(forSession:)` retrouve l'Invoice après génération
5. `loadInvoice` retourne `nil` si jamais générée

### P-16 + P-17 — VitalsEntryView (MOYEN, même fichier)

**P-16** — Validation physiologique stricte au save :
- Nouvelle property `VitalsViewModel.isPhysiologicallyValid`
- Plages volontairement larges (BP sys 50–250, dia 20–150, HR 20–250, SpO2 50–100) — refuse l'impossible, pas le cliniquement anormal
- Champ vide = valide (save partiel autorisé)
- Bouton Enregistrer disabled + message rouge explicite si invalide

**P-17** — Warnings accessibles :
- `.help(w)` n'a aucun effet sur iPhone → remplacé par un `Button` qui ouvre une `alert("Attention")` avec le texte du warning
- `accessibilityLabel` ajouté pour VoiceOver
- L'icône triangle orange devient tappable

**Tests** ([VitalsEntryViewTests.swift](ios/HCPilotAppTests/VitalsEntryViewTests.swift), 7 nouveaux) :
1. Tous champs vides → valide
2. Valeurs réalistes → valide
3. BP sys = 200 (warning clinique) → valide (pas bloquant)
4. BP sys = 999 → invalide
5. HR = 0 → invalide
6. Input non-numérique → invalide
7. SpO2 > 100 → invalide
+ test indépendance per timepoint (un seul invalide → invalide globalement)

### P-8 — Reset annuel compteur (MOYEN)

**Cause** : compteur séquentiel jamais reset → en janvier 2027, on aurait `INV-2027-00100` au lieu de `INV-2027-00001` (convention comptable US standard).

**Fix** : nouvelle clé UserDefaults `invoice.counter.year`. `nextInvoiceNumber` compare l'année courante à la stockée ; si différente, remet le compteur à 0 avant d'incrémenter.

**Tests** ([InvoicePDFBuilderTests.swift](ios/HCPilotAppTests/InvoicePDFBuilderTests.swift), 2 nouveaux) :
1. 2026 puis 2027 → `INV-2026-*` puis `INV-2027-00001`
2. Sanity régression d'année (retour en arrière reset aussi)

**Effet de bord** : un test P-12 hardcodait une date 2024 dans `nextInvoiceNumber(for:)` → cassait à cause du reset si la session était créée avec l'année actuelle. Test ajusté (utilise maintenant `nextInvoiceNumber()` sans paramètre).

### P-14 — PaymentMethod enum + displayName (BAS-MOYEN)

**Cause** : string `"Cash"` hardcodée dans le `pdfInput` alors que l'`Invoice` model utilisait l'enum `.cash`. Risque de divergence (typo, casse) entre PDF visible et invoice côté serveur.

**Fix** : extension `Invoice.PaymentMethod.displayName` dans [Invoice.swift](ios/HCPilotApp/Models/Invoice.swift). Une seule source de vérité pour l'affichage.

```swift
let paymentMethod: Invoice.PaymentMethod = .cash  // stub
// PDF :
paymentMethod: paymentMethod.displayName
// Model :
paymentMethod: paymentMethod
```

**Tests** ([InvoiceCodableTests.swift](ios/HCPilotAppTests/InvoiceCodableTests.swift), 3 nouveaux) :
1. Chaque cas de PaymentMethod a un `displayName` non vide
2. `.cash.displayName == "Cash"`
3. `.applePay.displayName == "Apple Pay"` (espace + casse précise)

### P-4 — InvoicePDFBuilder doc alignment (BAS-MOYEN)

**Cause** : le docstring annonçait "Pagination automatique" alors que le code n'a qu'un seul `ctx.beginPage()` et aucune gestion de débordement.

**Fix** :
- Docstring honnête : "Single-page only (1 prestation par invoice). La pagination sera ajoutée en Sprint 4 si nécessaire."
- Garde-fou `#if DEBUG` en fin de `drawTotalsTable` : log un warning si le contenu déborde de la page (sécurité minimale)

Pas de nouveau test (alignement code/doc).

---

## 3. Commits hygiène (avant P-XX)

Pour garantir "un commit séparé par issue", deux commits hygiène ont été réalisés avant P-12 sur la base des modifications non-commit accumulées dans la session précédente :

- **[`7881843f`](https://github.com/Grandkhan986/hcpilot/commit/7881843f)** `chore: cleanup code mort (iOS / backend / web) + fix tests auth périmés`
  - 19 fichiers : -1197 lignes
  - Cleanup : Package.swift orphelin, AdditionalViews.swift (8 lignes commentées), SecondaryButtonStyle inutilisé, endpoint `/reports/stock` stub, deps `pydantic-settings` + `email-validator`, 5 stores Zustand morts, 3 composants UI dead, `recharts` dep, duplicate `Roadmap/Guide_fees_HCPilot.ts`
  - Bonus : 3 tests auth pré-existants réparés (appelaient `/patients` au lieu de `/clients`, login en `params` au lieu de `json`)

- **[`e1141d64`](https://github.com/Grandkhan986/hcpilot/commit/e1141d64)** `fix: 3 bugs consent flow découverts en test manuel`
  - PKCanvasView tripwire pour le bouton "Confirmer la signature" (PKCanvasView est une class → mutation ne re-render pas SwiftUI)
  - `ConsentCheckpoint` Codable tolérant à l'absence d'`id` (backend ne renvoie que `label`+`accepted` → décodage échouait silencieusement → user voyait "non signé" + 409 au POST)
  - `.sheet(item:)` à la place de `.sheet(isPresented:)` + `if let` (PDF page blanche au visionnage)
  - Cadrage signature sur `drawing.bounds` (signature minuscule dans le PDF)

---

## 4. Tests : avant / après

| Suite | Avant | Après | Delta |
|---|---|---|---|
| InvoiceCodableTests | 3 | 6 | +3 (P-14) |
| InvoicePDFBuilderTests | 8 | 10 | +2 (P-8) |
| InvoiceServiceIdempotenceTests | — | 5 | +5 (nouveau fichier P-12) |
| VitalsEntryViewTests | 5 | 12 | +7 (P-16) |
| Backend tests | 51 | 54 | +3 (réparation tests auth) |
| **iOS unit tests Invoice + Vitals** | **16** | **33** | **+17** |

Build iOS final : `** BUILD SUCCEEDED **`.

---

## 5. Issues secondaires découvertes pendant le traitement

Aucune issue de fond. Deux frictions mineures :

1. **Test P-12 cassé par P-8** — le test `test_counter_not_incremented_on_idempotent_call` hardcodait `Date(timeIntervalSince1970: 1716393600)` (2024) après une génération qui utilisait `Date()` (2026). Le reset annuel P-8 a fait diverger l'année stockée vs demandée → reset → counter à 1 au lieu de 2. Fix : appel `nextInvoiceNumber()` sans paramètre dans le test (utilise `Date()` par défaut, année cohérente).

2. **Lint MD060 sur les tableaux du SUMMARY.md** — warnings cosmétiques sur le séparateur compact `|---|`. Style aligné avec le reste du fichier, warnings ignorés pour cohérence.

---

## 6. Issues différées (renvoyées dans TODO-improvements.md)

17 issues restantes documentées dans [`audit-parcours/TODO-improvements.md`](audit-parcours/TODO-improvements.md), section "Lot 1 audit — Issues différées" :

- **5 MOYENNES** : P-1, P-5, P-9, P-13, P-18 — effort estimé ~2 h
- **12 BASSES** : P-2, P-3, P-6, P-7, P-10, P-11, P-15, P-19–P-23 — effort estimé ~3 h

**Total effort différé estimé** : ~5 h.

---

## 7. Conclusion

| Métrique | Valeur |
|---|---|
| Issues traitées | 6 / 23 (26 %) |
| Issues critiques traitées | 1 / 1 (100 %) |
| Issues moyennes traitées | 3 / 8 (38 %) |
| Tests ajoutés | +17 unitaires verts |
| Régressions | 0 |
| Commits | 6 (P-XX) + 2 (hygiène) = 8 |
| Effort réel | ~2 h |
| Effort estimé | 3–4 h |

L'app est dans un état où :
- L'invoice ne peut plus se dédoubler (P-12).
- Les vitals ne peuvent plus être enregistrés avec des valeurs impossibles (P-16).
- La nurse peut accéder au texte des warnings sur iPhone (P-17).
- Le compteur de facture respecte la convention comptable US (P-8).
- Le mode de paiement a une source unique de vérité (P-14).
- La doc PDF n'annonce plus une feature absente (P-4).

Prêt pour les premiers tests utilisateurs sur cette portion du flow. Les issues restantes (P-1, P-5, P-9, P-13, P-18 et basses) sont non-bloquantes et tracées.
