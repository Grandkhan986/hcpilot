# Parcours 1 — Onboarding wizard

**Audité contre** : commit `d57415db` (état `main` au démarrage de l'audit).
**Brief de référence** : `Roadmap/brief-hcpilot.md` §"Onboarding nurse" + Sprint 1.

---

## Description du parcours

Le brief décrit la séquence cible :

> Welcome → création compte → setup pratique (licence) → setup Medical Director → premier standing order → arrivée Accueil

Cette séquence cible une nurse qui ouvre HCPilot pour la première fois et doit configurer sa pratique avant de pouvoir créer des sessions. Elle débloque trois choses :

1. Sa licence (RN/NP/LPN/MD/PA + État) — base de la conformité.
2. Son Medical Director — autorité réglementaire pour autoriser l'IV.
3. Sa première formulation autorisée (standing order) — pré-requis pour signer un consentement.

## Séquence nominale telle qu'implémentée

| # | Écran | Fichier | Action attendue |
|---|---|---|---|
| 0 | Login | [LoginView.swift](../ios/HCPilotApp/Views/LoginView.swift) | Saisir email + password (pré-rempli `doctor@hcpilot.com`) |
| 1 | AppMainView | [AppMainView.swift](../ios/HCPilotApp/Views/AppMainView.swift) | Aterrissage direct sur le dashboard (pas de gate) |
| 2 | (Manuel) Profil → "Configuration de la pratique" | [ProfileView.swift:48](../ios/HCPilotApp/Views/ProfileView.swift#L48) | Ouvre `SetupWizardView` en sheet |
| 3 | Step 1 — License | [SetupWizardView.swift:68-141](../ios/HCPilotApp/Views/SetupWizardView.swift#L68-L141) | Prénom, Nom, Téléphone, Practice name, License type, État, License #, Expiration, NPI |
| 4 | Step 2 — Medical Director | [SetupWizardView.swift:145-202](../ios/HCPilotApp/Views/SetupWizardView.swift#L145-L202) | Prénom MD, Nom MD, Email, License # MD, État (TextField), Contract start/end, Audit frequency |
| 5 | Step 3 — Standing Order | [SetupWizardView.swift:206-266](../ios/HCPilotApp/Views/SetupWizardView.swift#L206-L266) | Formulation (Myers/NAD+ 250/NAD+ 500), Expiration |
| 6 | Step 4 — Done | [SetupWizardView.swift:270-312](../ios/HCPilotApp/Views/SetupWizardView.swift#L270-L312) | Récap + bouton "Terminer" (dismiss) |

**Endpoints backend impliqués** :

- `PUT /v1/users/me/practice` ([main.py:995-1033](../backend/main.py#L995-L1033))
- `POST /v1/compliance/medical_directors`
- `POST /v1/compliance/standingOrders`

## Variantes testées

| Variante | État de l'app | Comportement attendu | Observé |
|---|---|---|---|
| Premier login (compte vide) | Pas de pratique configurée | Wizard auto-affiché | ❌ Non implémenté |
| Données partiellement saisies puis "Fermer" | Step 1 OK, Step 2 saisi partiellement | Confirmer avant fermeture | ❌ Perte silencieuse |
| Réseau coupé pendant submit Step 1 | Wizard ouvert, offline | Message clair + retry, ou queuing offline | ⚠️ Erreur générique seulement |
| License # vide | Step 1 | Bouton "Continuer" désactivé | ✅ OK |
| Email MD sans `@` | Step 2 | Bouton désactivé | ✅ OK (check `.contains("@")` mais naïf) |
| Contract end < Contract start | Step 2 | Validation refus | ❌ Pas de validation |

## Issues détectées par persona

### 🧑‍⚕️ Sarah (RN solo, 32 ans, technophile, va vite)

| Sév. | Issue |
|---|---|
| **HAUTE** | Pas de gate first-launch : Sarah doit deviner qu'il faut aller dans Profil → "Configuration de la pratique" — elle ne le trouvera probablement pas seule à la première utilisation. |
| **HAUTE** | Aucune validation format temps-réel sur licence #, téléphone — elle peut saisir `123` et passer. L'erreur viendra de l'API plus tard, démoralisant. |
| **MOYENNE** | Picker État avec 51 codes US — défaut "CA". Si elle est dans un autre État, scroll lent sans champ de recherche. |
| **BASSE** | Date d'expiration de licence par défaut `today+2y` — arbitraire. Elle modifiera de toute façon. |

### 🧑‍⚕️ Linda (NP prudente, 48 ans, lit chaque libellé)

| Sév. | Issue |
|---|---|
| **CRITIQUE** | Aucun écran de bienvenue : Linda veut savoir combien d'étapes, combien de temps, ce qu'on lui demandera. Le wizard la jette directement dans le formulaire. |
| **CRITIQUE** | Tapotage par erreur du bouton "Fermer" (toolbar) → données partiellement saisies en Step 2 perdues, sans confirmation. Step 1 ayant déjà été `PUT`-ée, l'état est incohérent (pratique partiellement configurée). |
| **HAUTE** | Pas de mention HIPAA / RGPD ni d'explication sur ce qui est stocké et où. Linda hésitera à donner son NPI. |
| **MOYENNE** | Pas de checklist préparatoire ("Vous aurez besoin de : votre licence active, le nom + email + licence de votre MD, l'expiration de son contrat"). Linda déteste devoir interrompre le flow pour aller chercher une info. |

### 🧑‍⚕️ Jessica (mini-clinique, 38 ans, interrompue souvent)

| Sév. | Issue |
|---|---|
| **CRITIQUE** | Aucune persistence des saisies entre relances d'app. Si Jessica est interrompue après la Step 1 (validée backend) et avant la Step 2, elle perd Step 2 partielle. Au retour, le wizard ne s'ouvre PAS automatiquement → elle se croit configurée. |
| **HAUTE** | Aucun indicateur "Pratique partiellement configurée" sur le dashboard si Jessica a complété Step 1 mais pas 2/3. Elle pourra créer une session sans standing order. |
| **MOYENNE** | Le wizard n'est pas relancable d'un seul tap depuis la home — il faut aller dans Profil → Configuration. Trois taps de friction. |

### 🧑‍⚕️ Maria (RN débutante, 27 ans, vocabulaire métier nouveau)

| Sév. | Issue |
|---|---|
| **CRITIQUE** | Aucune explication de ce qu'est un "Medical Director" ni pourquoi il faut le déclarer. Maria peut croire que c'est optionnel ou non-applicable à elle. |
| **CRITIQUE** | Aucune explication de "Standing Order" ni de pourquoi sans standing order elle ne peut pas administrer une IV (réglementation US par État). |
| **HAUTE** | Stepper "Audit tous les 30 j" range 7-90 sans help text — Maria n'a pas idée de la convention métier (généralement 30 j pour les nouvelles nurses). |
| **HAUTE** | `mdStateCode` est un `TextField` (taper "CA"), alors que `stateCode` (étape 1) est un `Picker`. Inconsistance qui désoriente. |
| **HAUTE** | "NPI" expliqué juridiquement (National Provider Identifier) mais sans dire pourquoi il est optionnel (utilisé pour facturer assurance, donc non requis en private pay). |
| **MOYENNE** | License types `RN, NP, LPN, MD, PA` sans descriptions. Maria sait probablement le sien mais une RN qui devient NP pourrait être incertaine pendant la transition. |
| **BASSE** | `Audit Frequency` — terme métier sans contexte. La nurse doit savoir que c'est la fréquence des entretiens contradictoires avec son MD. |

## Issues consolidées par sévérité

### CRITIQUE (4)

1. **C-01** Pas de gate first-launch : wizard non auto-déclenché après première connexion.
2. **C-02** Pas d'écran Welcome / checklist préparatoire avant la Step 1.
3. **C-03** "Fermer" perd les données saisies sans confirm + laisse la pratique partiellement configurée sans alerte.
4. **C-04** Vocabulaire métier (Medical Director, Standing Order) sans explication pour une utilisatrice débutante.

### HAUTE (6)

5. **H-05** Pas de validation format pre-submit (licence #, état code, email, téléphone).
6. **H-06** Pas de validation `contractEnd > contractStart` côté UI.
7. **H-07** `mdStateCode` en TextField alors que `stateCode` en Picker → inconsistance.
8. **H-08** Pas d'`accessibilityIdentifier` → impossible d'écrire des tests XCUITest robustes.
9. **H-09** Audit Frequency stepper sans help text.
10. **H-10** NPI sans explication "pourquoi optionnel".

### MOYENNE (5)

11. **M-11** Picker État sans recherche (51 entrées).
12. **M-12** Pas de mention HIPAA / lien doc dans le wizard.
13. **M-13** DoneView ne route pas explicitement vers Accueil (dismiss vers Profil).
14. **M-14** Pas d'indicateur "pratique partielle" sur la home après abandon Step 2/3.
15. **M-15** License types RN/NP/LPN/MD/PA sans desc inline.

### BASSE (3)

16. **B-16** Date par défaut licence = `today+2y` arbitraire.
17. **B-17** Swipe-to-dismiss du sheet n'invoque pas la confirm.
18. **B-18** Pas de "wizard relancable depuis la home" en un tap.

## Recommandations de correction (cette passe)

| Issue | Action |
|---|---|
| C-02 | Ajouter un `WelcomeStep` en step 0 du wizard (checklist + temps estimé). |
| C-03 | Confirm dialog sur "Fermer" si données partielles non envoyées. |
| C-04 | Help text inline (`.font(.caption2)`) sur MD et Standing Order. |
| H-05 | Plug `Validators.isValidLicenseNumber`, `isValidStateCode`, `isValidEmail`, `isValidPhoneUS` côté UI pré-submit. |
| H-06 | Guard `contractEnd >= contractStart` dans `mdStepValid`. |
| H-07 | `mdStateCode` → Picker (même liste d'États que step 1). |
| H-08 | Ajouter `.accessibilityIdentifier(...)` sur tous les contrôles. |
| H-09 | Help text `Stepper` sur audit frequency. |
| H-10 | Aide inline sur NPI. |

## Recommandations déférées (TODO-improvements.md)

C-01 (gate first-launch), M-11→M-15, B-16→B-18 : voir [TODO-improvements.md](TODO-improvements.md).

## Estimation effort

| Sévérité | Items | Effort |
|---|---|---|
| CRITIQUE | 3 traités cette passe (C-02 / C-03 / C-04) | ~45 min |
| HAUTE | 6 traités cette passe (H-05→H-10) | ~50 min |
| MOYENNE+BASSE | 8 déférés | TODO |
| Tests XCUITest | OnboardingUITests | ~30 min |

**Total cette passe** : ~2 h.

C-01 (gate first-launch) est décrit comme **différé** car il dépend d'une décision produit : faut-il forcer le wizard à chaque ouverture tant que `practice` n'est pas complète côté backend, ou utiliser un flag local `@AppStorage("hasCompletedOnboarding")` ? Voir TODO-improvements.md.
