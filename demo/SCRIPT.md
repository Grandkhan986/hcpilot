# Script de démo HCPilot — bout-en-bout

Scénario à enregistrer sur simulateur iPhone 17 (iOS 18+). Backend FastAPI sur `localhost:8000`. Durée cible : **3 à 4 minutes**.

## Préparation

```bash
# 1. Démarrer le backend
cd backend && uvicorn main:app --host 0.0.0.0 --port 8000 --log-level warning &

# 2. Démarrer le simulateur
open -a Simulator
xcrun simctl boot 1237C1B9-36A9-46BE-8C8A-23B45578E380 2>/dev/null

# 3. Construire et installer l'app
xcodebuild -project ios/HCPilot.xcodeproj -scheme HCPilotApp \
  -destination 'id=1237C1B9-36A9-46BE-8C8A-23B45578E380' \
  -derivedDataPath /tmp/hcpilot-build build
xcrun simctl install booted /tmp/hcpilot-build/Build/Products/Debug-iphonesimulator/HCPilotApp.app

# 4. Reset les UserDefaults pour partir d'un état propre (démontre le gate)
xcrun simctl spawn booted defaults delete com.hcpilot.app 2>/dev/null

# 5. Démarrer l'enregistrement
xcrun simctl io booted recordVideo demo/hcpilot-demo-raw.mov
# (Ctrl+C pour stop quand la démo est finie)
```

## Scénario à jouer (3-4 min)

### 0:00 — Login
1. Lancer l'app. Écran login avec `doctor@hcpilot.com` / `password123` pré-rempli.
2. Tap **Connexion**. ~1s.

### 0:05 — Gate first-launch (si state vierge)
Si le compte démo n'a pas encore complété l'onboarding :
3. WelcomeStep s'affiche en plein écran. Lire "Configurons votre pratique en 3 étapes — environ 5 minutes."
4. Mentionner la checklist (licence / MD / standing order).
5. Tap **Commencer la configuration**.
6. **LicenseStep** : "Sarah" / "Johnson" / téléphone / Picker RN / Picker CA / "RN-CA-2024-99887" / DatePicker → **Continuer**.
7. **MDStep** : "James" / "Patterson" / "md@example.com" / "MD-CA-2022-A1234" / Picker CA / dates → **Continuer**.
8. **StandingOrderStep** : sélectionner "Myers Cocktail" (déjà coché) → **Continuer**.
9. **DoneStep** : récap avec checkmark vert → **Terminer**.

*Si l'onboarding est déjà complet, ces étapes sont skippées — passer directement à 0:30.*

### 0:30 — Accueil (cockpit)
10. **Header** : "Bonjour, Marie" + date + badge sync vert "À jour".
11. **3 KPI tiles** : pointer "Revenu", "Sessions", "Conformité OK" en vert.
12. **Carte "Ma Journée"** : zoom sur la polyline reliant les 4 stops numérotés (Paris seed). Mentionner la légende "Trajet optimisé · 4 stops".
13. Tap KPI **Conformité** → ComplianceDashboardView : 4 cards (Licence, MD, Standing Orders, Alertes). Tap **Modifier** sur MD card → MedicalDirectorEditView → **Renouveler le contrat (+12 mois)** → la date avance → **Enregistrer**.
14. Retour Accueil via back.

### 1:00 — Créer un client (démontrer autocomplete + chips)
15. Tab **Clients** → bouton **+** → ClientFormView.
16. Saisir "Camille" / "Rousseau" / genre "Femme" / DatePicker DOB 1990.
17. Email "camille.rousseau@gmail.com" (format validé temps réel).
18. Téléphone "5551234567" (validé).
19. **Adresse** : taper "10 main street san fr" → suggestions Apple Maps apparaissent → tap "10 Main Street, San Francisco, CA, USA" → city/state/zip remplis automatiquement. **Ceci est le moment fort de la démo M-43**.
20. **Médical** : chips allergies (tap "Pénicilline" + "Latex"), chips antécédents (tap "Hypertension"), chips médications (tap +, saisir "Magnésium 300mg" → ajouter).
21. **Contact urgence** : "Thomas Rousseau" / "5552223333".
22. Tap **Enregistrer** → retour liste avec Camille en haut.

### 1:45 — Démarrer une session
23. Tab **Accueil** → tap la première session du jour (Myers Cocktail à 9h).
24. SessionDetailView : voir le client, la formulation, l'adresse, le total.
25. Section **Consentement** orange "Non signé" → tap **Recueillir le consentement**.

### 2:00 — Consent flow (signature)
26. **Step 0** — Sélection SO : tap "Myers Cocktail" → step 1.
27. **Step 1** — Lecture consent text → **J'ai lu, continuer**.
28. **Step 2** — Cocher les 4 checkpoints (toggles vert) → **Continuer vers la signature**.
29. **Step 3** — Signature : utiliser le doigt sur le simulateur (tracer une diagonale) → **Confirmer la signature** → alert "Consentement enregistré" → **OK**.

### 2:30 — Vitals (Pré-IV)
30. De retour sur SessionDetailView : tap **Commencer la session** → status passe à "En cours" + timer démarre (H-67 visible).
31. Tap **Saisir les vitals** (rose) → VitalsEntryView.
32. **Avant l'IV** : TA sys 120 / dia 80 / Pouls 72 / SpO₂ 98 → **Capturer maintenant** (horodate). Mentionner que les valeurs anormales déclenchent un warning orange.
33. **Pendant l'IV** : TA sys 118 / dia 78 / Pouls 70 / SpO₂ 99 → capturer.
34. **Après l'IV** : TA sys 122 / dia 82 / Pouls 75 → capturer.
35. **Enregistrer** → retour SessionDetailView.

### 3:00 — Terminer + invoice
36. Tap **Terminer la session** → LotUsageSheet.
37. Sélectionner un lot Myers (lot_001) → **Confirmer la consommation et terminer**.
38. Retour SessionDetailView : status "Terminée" + bouton violet **Voir la facture (INV-2026-00001)** apparaît.
39. Tap → PDF preview : voir le rendu (FACTURE / Marie Dupont / Camille Rousseau / Myers Cocktail / 175 € / Cash).
40. Swipe down pour fermer.

### 3:30 — Offline (optionnel)
41. Couper le wifi du Mac (Control Center).
42. Refresh sur l'Accueil → bandeau orange "Mode hors-ligne · 0 action en attente".
43. Créer un client offline → la confirmation indique "Hors-ligne. Le client sera créé à la reconnexion."
44. Rallumer le wifi → bandeau disparaît, sync draine automatiquement.

### 3:45 — Fin
45. Retour Accueil. KPIs mis à jour. Pause sur le cockpit.

## Stop l'enregistrement

```bash
# Ctrl+C dans le terminal où simctl recordVideo tourne
# Le fichier est demo/hcpilot-demo-raw.mov

# Conversion optionnelle en MP4 (plus léger)
ffmpeg -i demo/hcpilot-demo-raw.mov -c:v libx264 -crf 23 -preset slow demo/hcpilot-demo.mp4
```

## Découpage suggéré (clips 30s pour pitch)

| Clip | Contenu | Timing |
|---|---|---|
| 01-onboarding | Login + wizard | 0:00–0:30 |
| 02-accueil | Cockpit + KPIs + carte + compliance | 0:30–1:00 |
| 03-client | Création client + autocomplete | 1:00–1:45 |
| 04-consent | Flow consent + signature | 1:45–2:30 |
| 05-vitals | Saisie vitals 3 sections | 2:30–3:00 |
| 06-invoice | Complétion + PDF facture | 3:00–3:30 |
| 07-offline | Mode offline + sync | 3:30–4:00 |

## Notes pour le présentateur

- **Insister sur l'autocomplete adresse** (M-43) : c'est l'élément qui fait dire "wow" en démo. Apple Maps natif = perception "pro" immédiate.
- **Le timer "En cours depuis X"** (H-67) sur la session in_progress donne vie au flow — bien le pointer.
- **Le badge sync** (H-23) qui s'auto-update toutes les 30s : si la démo dure assez, le label "Sync il y a 1m" devrait apparaître.
- **L'invoice PDF stub** est SANS Stripe — le mentionner explicitement à l'audience ("le paiement Stripe Connect arrive en Sprint 4").
- **Le gate first-launch** (C-01) : si le compte démo est déjà configuré, démontrer la complétion en passant par Profil → Configuration de la pratique (mode éditFromProfile).

## Reset complet (pour replay propre)

```bash
# Reset UserDefaults
xcrun simctl spawn booted defaults delete com.hcpilot.app

# Reset Keychain (force re-login)
xcrun simctl spawn booted security -h | head -3  # ne supprime pas via simctl, faire dans Réglages iOS du simu

# Redémarrer le backend (reset MOCK seed)
lsof -iTCP:8000 -sTCP:LISTEN -t | xargs kill
cd backend && uvicorn main:app --host 0.0.0.0 --port 8000 --log-level warning &
```
