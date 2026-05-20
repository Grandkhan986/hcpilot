OK, je te livre un brief technique complet et exploitable par Claude Code. C'est long parce que ça doit l'être — un brief partiel = code partiel = retours en arrière. Si Claude Code a tout dès le départ, il livre cohérent du premier coup.

Je vais le structurer en blocs que tu pourras donner soit d'un coup, soit par sprints. À toi de voir selon ta méthode de travail.

---

# Brief technique HCPilot MVP — pour Claude Code

## Vue d'ensemble du projet

HCPilot est une application iOS native (SwiftUI) pour infirmières IV mobiles indépendantes aux USA. Elle gère leur pratique quotidienne : planning, dossiers clients, paiements, conformité réglementaire et inventaire. Backend Supabase avec add-on HIPAA. Paiements Stripe Connect. Cible : 1-3 utilisatrices par compte (mode solo ou mini-clinique).

**Périmètre MVP : 5 écrans cœur traitant 3 douleurs clients : documentation HIPAA, compliance par État, gestion d'inventaire.**

## Stack technique

**Frontend iOS**
- SwiftUI (iOS 17+ minimum, vu que la base utilisatrice est urbaine premium)
- Xcode 15+
- Architecture MVVM
- Combine pour la gestion réactive
- SwiftData ou Core Data pour cache local
- Google ML Kit (via Cocoapods ou SPM) pour scan code-barres
- PDFKit (natif iOS) pour génération PDF
- PencilKit ou Canvas natif pour signature électronique

**Backend**
- Supabase avec add-on HIPAA activé (BAA signé en parallèle du dev)
- PostgreSQL avec Row Level Security (RLS) sur toutes les tables
- Supabase Auth (email + magic link)
- Supabase Storage pour PDFs et photos (HIPAA-compliant via BAA)
- Supabase Realtime pour sync multi-device si besoin

**Paiements**
- Stripe Connect (configuration Express ou Custom selon onboarding flow)
- Stripe iOS SDK
- Webhooks Stripe pour gérer les events de paiement
- Stripe Identity pour KYC des nurses

**Infrastructure**
- GitHub pour versioning
- TestFlight pour beta
- App Store Connect pour distribution

**Outils de support**
- Sentry pour error tracking
- PostHog ou Mixpanel pour analytics produit
- Resend ou Postmark pour emails transactionnels

## Architecture de données

### Tables principales et schéma

```sql
-- Table: nurses (utilisatrices principales)
create table nurses (
  id uuid primary key default uuid_generate_v4(),
  email text unique not null,
  first_name text not null,
  last_name text not null,
  phone text,
  state_code char(2) not null, -- ex: 'CA', 'TX', 'FL'
  license_number text not null,
  license_expiration_date date not null,
  license_type text check (license_type in ('RN', 'NP', 'LPN', 'MD', 'PA')),
  npi_number text, -- National Provider Identifier US
  practice_name text,
  stripe_connect_account_id text unique,
  stripe_onboarding_completed boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Table: medical_directors
create table medical_directors (
  id uuid primary key default uuid_generate_v4(),
  nurse_id uuid references nurses(id) on delete cascade,
  first_name text not null,
  last_name text not null,
  email text not null,
  license_number text not null,
  state_code char(2) not null,
  contract_start_date date not null,
  contract_end_date date,
  contract_pdf_path text, -- path Supabase Storage
  audit_frequency_days int default 30,
  next_audit_date date,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- Table: standing_orders
create table standing_orders (
  id uuid primary key default uuid_generate_v4(),
  nurse_id uuid references nurses(id) on delete cascade,
  medical_director_id uuid references medical_directors(id),
  formulation_name text not null,
  formulation_details jsonb, -- composition, dosage, contre-indications
  version int default 1,
  signed_at timestamptz,
  expires_at timestamptz,
  signed_pdf_path text,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- Table: clients (patients des nurses)
create table clients (
  id uuid primary key default uuid_generate_v4(),
  nurse_id uuid references nurses(id) on delete cascade,
  first_name text not null,
  last_name text not null,
  email text,
  phone text not null,
  date_of_birth date not null,
  address_line1 text,
  address_line2 text,
  city text,
  state_code char(2),
  postal_code text,
  access_notes text, -- code accès, étage, etc.
  allergies jsonb default '[]'::jsonb,
  medications jsonb default '[]'::jsonb,
  medical_conditions jsonb default '[]'::jsonb,
  emergency_contact_name text,
  emergency_contact_phone text,
  id_document_path text, -- photo ID stockée
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Table: consents (consentements signés)
create table consents (
  id uuid primary key default uuid_generate_v4(),
  client_id uuid references clients(id) on delete cascade,
  nurse_id uuid references nurses(id) on delete cascade,
  session_id uuid, -- nullable, lié plus tard
  standing_order_id uuid references standing_orders(id),
  consent_text text not null, -- snapshot du texte au moment de la signature
  checkpoints jsonb not null, -- liste des points cochés
  signature_image_path text not null, -- image PNG de la signature
  signed_at timestamptz default now(),
  signed_latitude decimal(10, 7),
  signed_longitude decimal(10, 7),
  pdf_path text, -- PDF complet du consentement signé
  ip_address inet,
  device_info jsonb,
  created_at timestamptz default now()
);

-- Table: sessions (interventions IV)
create table sessions (
  id uuid primary key default uuid_generate_v4(),
  nurse_id uuid references nurses(id) on delete cascade,
  client_id uuid references clients(id) on delete cascade,
  scheduled_at timestamptz not null,
  status text check (status in ('scheduled', 'en_route', 'in_progress', 'completed', 'cancelled', 'no_show')) default 'scheduled',
  formulation_name text not null,
  formulation_inventory_id uuid, -- lié au lot utilisé
  iv_start_time timestamptz,
  iv_end_time timestamptz,
  pre_vitals jsonb, -- pression, pouls, etc.
  during_vitals jsonb,
  post_vitals jsonb,
  drip_rate text,
  clinical_notes text,
  photos_paths text[], -- array de paths
  client_signature_path text, -- signature post-session
  amount_charged decimal(10, 2),
  amount_tip decimal(10, 2) default 0,
  travel_fee decimal(10, 2) default 0,
  stripe_payment_intent_id text,
  invoice_pdf_path text,
  cancelled_at timestamptz,
  cancellation_reason text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Table: inventory_lots (lots de produits scannés)
create table inventory_lots (
  id uuid primary key default uuid_generate_v4(),
  nurse_id uuid references nurses(id) on delete cascade,
  product_name text not null, -- "NAD+ 500mg", "Myers Cocktail", etc.
  product_category text check (product_category in ('nad', 'vitamins', 'saline', 'medication', 'supplies', 'other')),
  barcode text,
  lot_number text not null,
  expiration_date date not null,
  quantity_initial int not null default 1,
  quantity_remaining int not null default 1,
  unit_cost decimal(10, 2),
  supplier text,
  received_at timestamptz default now(),
  scanned_image_path text,
  notes text,
  created_at timestamptz default now()
);

-- Table: inventory_transactions (mouvements de stock)
create table inventory_transactions (
  id uuid primary key default uuid_generate_v4(),
  inventory_lot_id uuid references inventory_lots(id),
  session_id uuid references sessions(id),
  transaction_type text check (transaction_type in ('reception', 'usage', 'adjustment', 'expired_disposal', 'recall')) not null,
  quantity_change int not null,
  notes text,
  created_at timestamptz default now()
);

-- Table: state_compliance_rules (base de données réglementaire)
create table state_compliance_rules (
  id uuid primary key default uuid_generate_v4(),
  state_code char(2) not null,
  rule_category text check (rule_category in ('scope_of_practice', 'medical_director', 'standing_orders', 'good_faith_exam', 'mobile_license', 'other')),
  rule_title text not null,
  rule_description text not null,
  source_url text,
  effective_date date,
  last_updated date,
  created_at timestamptz default now()
);

-- Table: compliance_alerts (alertes personnalisées pour chaque nurse)
create table compliance_alerts (
  id uuid primary key default uuid_generate_v4(),
  nurse_id uuid references nurses(id) on delete cascade,
  alert_type text check (alert_type in ('license_expiration', 'md_contract_expiration', 'standing_order_expiration', 'regulatory_change', 'audit_due')),
  severity text check (severity in ('info', 'warning', 'critical')),
  title text not null,
  description text not null,
  related_entity_id uuid, -- id de la licence/MD/order concerné
  action_url text,
  triggered_at timestamptz default now(),
  acknowledged_at timestamptz,
  resolved_at timestamptz
);

-- Table: audit_logs (immuables, pour conformité HIPAA)
create table audit_logs (
  id uuid primary key default uuid_generate_v4(),
  nurse_id uuid references nurses(id),
  entity_type text not null,
  entity_id uuid not null,
  action text check (action in ('create', 'read', 'update', 'delete', 'export')) not null,
  changes jsonb,
  ip_address inet,
  user_agent text,
  occurred_at timestamptz default now()
);
```

### Row Level Security (RLS)

Toutes les tables sont en RLS strict. Une nurse n'accède qu'à ses propres données.

```sql
-- Exemple pour la table clients
alter table clients enable row level security;

create policy "Nurses can only view their own clients"
  on clients for select
  using (auth.uid() = nurse_id);

create policy "Nurses can only insert clients linked to themselves"
  on clients for insert
  with check (auth.uid() = nurse_id);

create policy "Nurses can only update their own clients"
  on clients for update
  using (auth.uid() = nurse_id);

-- Pas de delete autorisé en RLS (conformité HIPAA = soft delete via colonne deleted_at)
```

À répliquer pour toutes les tables avec ajustement de la logique selon la table.

### Audit logs automatiques

Triggers PostgreSQL sur les tables critiques (clients, consents, sessions) pour logger toute modification dans audit_logs.

```sql
create or replace function log_audit_changes()
returns trigger as $$
begin
  insert into audit_logs (nurse_id, entity_type, entity_id, action, changes)
  values (
    coalesce(NEW.nurse_id, OLD.nurse_id),
    TG_TABLE_NAME,
    coalesce(NEW.id, OLD.id),
    lower(TG_OP),
    case
      when TG_OP = 'DELETE' then row_to_json(OLD)::jsonb
      when TG_OP = 'UPDATE' then jsonb_build_object('before', row_to_json(OLD)::jsonb, 'after', row_to_json(NEW)::jsonb)
      else row_to_json(NEW)::jsonb
    end
  );
  return coalesce(NEW, OLD);
end;
$$ language plpgsql;

create trigger clients_audit
after insert or update or delete on clients
for each row execute function log_audit_changes();
```

## Architecture iOS — Structure du projet

```
HCPilot/
├── App/
│   ├── HCPilotApp.swift (entry point)
│   └── AppCoordinator.swift
├── Core/
│   ├── Networking/
│   │   ├── SupabaseClient.swift
│   │   └── StripeClient.swift
│   ├── Storage/
│   │   ├── LocalStorage.swift (SwiftData)
│   │   └── SecureStorage.swift (Keychain)
│   ├── Auth/
│   │   └── AuthManager.swift
│   └── Utilities/
│       ├── DateFormatters.swift
│       ├── Validators.swift
│       └── PDFGenerator.swift
├── Features/
│   ├── Authentication/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Models/
│   ├── Dashboard/ (Ma Journée)
│   ├── Clients/
│   ├── Sessions/
│   ├── Payment/
│   ├── Compliance/
│   ├── Inventory/
│   └── Settings/
├── Shared/
│   ├── Components/ (composants UI réutilisables)
│   ├── Modifiers/
│   └── Extensions/
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

## Spécifications détaillées des 5 écrans

### Écran 1 — Ma Journée (Dashboard)

**Fichiers à créer**
- `Features/Dashboard/Views/DashboardView.swift`
- `Features/Dashboard/Views/SessionCardView.swift`
- `Features/Dashboard/ViewModels/DashboardViewModel.swift`
- `Features/Dashboard/Models/DashboardModels.swift`

**Comportement**
- Charge automatiquement les sessions du jour au launch
- Auto-refresh toutes les 60 secondes en foreground
- Pull to refresh manuel
- Cache local SwiftData pour mode offline
- Navigation par swipe horizontal entre jours

**État de chargement**
Skeleton loader avec 3 cards placeholder.

**État vide**
Illustration + texte « Aucun rendez-vous aujourd'hui » + bouton « Ajouter un rendez-vous ».

**État erreur**
Bannière en haut « Connexion impossible, affichage des données locales » + tentative auto retry.

**Cards de session**
Composant `SessionCardView` qui affiche :
- Heure de début (taille 24pt, bold)
- Nom client (taille 17pt, medium)
- Adresse abrégée (taille 14pt, gray)
- Service prévu (taille 14pt, medium)
- Badge statut (couleur selon statut)
- Distance et temps depuis session précédente

**Actions par session**
- Tap card → ouvre `SessionDetailView`
- Swipe gauche → menu avec : Appeler / Itinéraire / Annuler / Marquer comme terminé
- Long press → preview de la fiche client

**Tab bar (présente sur tout l'app)**
4 onglets : Ma Journée / Clients / Stock / Paramètres
+ bouton flottant central « + » qui ouvre menu : Nouveau RDV / Nouveau Client / Scanner Stock

### Écran 2 — Fiche client + consentement

**Fichiers à créer**
- `Features/Clients/Views/ClientListView.swift`
- `Features/Clients/Views/ClientDetailView.swift`
- `Features/Clients/Views/ClientFormView.swift`
- `Features/Clients/Views/ConsentFlowView.swift`
- `Features/Clients/Views/SignatureCanvasView.swift`
- `Features/Clients/ViewModels/ClientViewModel.swift`
- `Features/Clients/ViewModels/ConsentViewModel.swift`
- `Features/Clients/Models/ClientModels.swift`

**Flow création client**

Multi-step form en 4 étapes avec progress bar en haut :

Étape 1 — Identité :
- TextField prénom (required, validation : 2+ caractères)
- TextField nom (required)
- TextField email (validation regex)
- TextField téléphone (formatage automatique format US)
- DatePicker date de naissance (required, refuser <18 ans)
- Bouton « Scanner ID » qui ouvre la caméra (optionnel)

Étape 2 — Adresse :
- TextField adresse avec autocomplétion (Mapbox Places API ou Apple Maps)
- TextField complément adresse
- TextField code accès
- Auto-extraction ville/État/code postal depuis autocomplétion

Étape 3 — Antécédents médicaux :
- Multi-select Allergies (chips prédéfinies : pénicilline, latex, iode, etc. + champ libre)
- Multi-select Conditions médicales (hypertension, diabète, grossesse, etc.)
- TextEditor Médications actuelles
- TextField Contact d'urgence + téléphone

Étape 4 — Validation et création :
- Récap de toutes les infos saisies
- Bouton « Créer le client » qui submit vers Supabase

**Flow consentement (depuis la fiche d'une session)**

Écran 1 — Sélection formulation :
- Liste des formulations actives (standing orders)
- Tap pour sélectionner

Écran 2 — Affichage du consentement :
- ScrollView avec le texte du consentement (chargé depuis le standing order)
- Texte non-modifiable, mais lisible et clair

Écran 3 — Checkpoints :
- Liste de checkboxes :
  - « Je comprends les risques généraux de l'IV »
  - « Je comprends les risques spécifiques de [formulation] »
  - « J'autorise le partage avec mon medical director »
  - « J'accepte la politique d'annulation »
- Bouton « Continuer » désactivé tant que tout n'est pas coché

Écran 4 — Signature :
- Canvas avec PencilKit
- Espace vide pour signer au doigt
- Bouton « Effacer » pour recommencer
- Bouton « Confirmer la signature » qui :
  - Capture la signature en PNG
  - Capture timestamp + géolocalisation + IP + device info
  - Génère le PDF complet du consentement signé
  - Upload vers Supabase Storage
  - Crée l'entrée dans la table `consents`
  - Retour à la session

**Génération du PDF du consentement**

PDF auto-généré avec :
- En-tête HCPilot + nom de la nurse
- Identité complète du client
- Texte intégral du consentement
- Liste des checkpoints cochés
- Image de la signature
- Métadonnées (date, heure, lieu, lat/lng)
- Footer avec ID unique du document

Stockage dans Supabase Storage à `nurses/{nurse_id}/consents/{consent_id}.pdf`.

### Écran 3 — Paiement Stripe Connect

**Fichiers à créer**
- `Features/Payment/Views/PaymentView.swift`
- `Features/Payment/Views/PaymentMethodSelectionView.swift`
- `Features/Payment/Views/PaymentProcessingView.swift`
- `Features/Payment/Views/PaymentSuccessView.swift`
- `Features/Payment/ViewModels/PaymentViewModel.swift`
- `Features/Payment/Services/StripeConnectService.swift`

**Setup Stripe Connect**

Type de compte : **Stripe Connect Express** (recommandé pour MVP, moins de KYC à gérer).

Configuration côté backend (Supabase Edge Functions ou serveur séparé) :
- Endpoint pour créer un compte Connect : `POST /stripe/accounts`
- Endpoint pour générer onboarding link : `POST /stripe/account_links`
- Endpoint pour créer payment intent avec destination charge : `POST /stripe/payment_intents`
- Webhook handler pour events Stripe : `POST /stripe/webhooks`

**Flow paiement à la fin d'une session**

Écran 1 — Récap et montant :
- Affichage récap session (client, formulation, heure)
- Champ Prix (pré-rempli depuis catalogue, modifiable)
- Champ Frais de déplacement (optionnel)
- Sélecteur Pourboire (boutons 15/20/25% ou custom)
- Calcul automatique du total
- Calcul automatique de la taxe selon État (intégration Stripe Tax recommandée)

Écran 2 — Choix méthode :
- 4 options visuelles :
  - Carte en NFC (« Tap to Pay sur iPhone » natif Apple)
  - Lien de paiement (génère URL Stripe à envoyer au client)
  - Apple Pay (si client a Apple Pay sur son téléphone)
  - Cash (marquage manuel, pas de transaction Stripe)

Écran 3 — Processing :
- Loader full screen avec message « Traitement en cours… »
- Important : empêcher le tap-out de l'app pendant cette étape
- Timeout 30 secondes max, sinon retry ou erreur

Écran 4 — Succès :
- Animation de confirmation
- Récap montant encaissé
- Détails : net pour la nurse / commission HCPilot (0,99 $)
- Boutons d'action :
  - « Envoyer facture par email »
  - « Envoyer reçu par SMS »
  - « Programmer prochain RDV »
- Bouton « Retour à Ma Journée »

**Logique du split payment**

Sur chaque transaction, Stripe Connect prélève automatiquement :
- 0,99 $ vers le compte plateforme HCPilot (`application_fee_amount: 99` en cents)
- Le reste vers le compte Connect de la nurse

Configuration côté serveur :
```javascript
const paymentIntent = await stripe.paymentIntents.create({
  amount: totalAmountInCents,
  currency: 'usd',
  payment_method_types: ['card'],
  application_fee_amount: 99, // 0.99 USD
  transfer_data: {
    destination: nurseStripeConnectAccountId,
  },
});
```

**Génération de facture**

PDF auto-généré après chaque paiement réussi :
- En-tête : logo HCPilot + nom de la pratique de la nurse
- Numéro de facture séquentiel (auto-incrémenté en DB)
- Date d'émission
- Identité du client
- Liste détaillée : formulation + frais déplacement + pourboire
- Sous-total, taxe, total
- Méthode de paiement utilisée
- Footer avec mentions légales US (state-specific si possible)

Stockage à `nurses/{nurse_id}/invoices/{session_id}.pdf`.

### Écran 4 — Compliance

**Fichiers à créer**
- `Features/Compliance/Views/ComplianceDashboardView.swift`
- `Features/Compliance/Views/LicenseDetailView.swift`
- `Features/Compliance/Views/MedicalDirectorView.swift`
- `Features/Compliance/Views/StandingOrdersListView.swift`
- `Features/Compliance/Views/StandingOrderDetailView.swift`
- `Features/Compliance/ViewModels/ComplianceViewModel.swift`
- `Features/Compliance/Models/ComplianceModels.swift`

**Dashboard layout**

ScrollView verticale avec 4 sections cards :

Card 1 — Ma Licence :
- Numéro de licence + État
- Date d'expiration
- Badge couleur :
  - Vert : >90 jours
  - Orange : 30-90 jours
  - Rouge : <30 jours
- Bouton « Renouveler » qui ouvre une page externe vers le board d'État
- Bouton « Modifier » pour mise à jour

Card 2 — Medical Director :
- Identité MD
- Statut contrat (actif/expirant/expiré)
- Date prochain audit
- Bouton « Voir détails »

Card 3 — Standing Orders :
- Nombre de standing orders actifs
- Alerte si un ou plusieurs expirent dans <30 jours
- Bouton « Voir tous »

Card 4 — Alertes réglementaires :
- Liste des dernières alertes
- Filtre par criticité
- Tap pour marquer comme lue

**Setup initial (onboarding)**

Premier launch après création de compte, la nurse passe par un wizard guidé :
- Saisie infos licence
- Setup Medical Director (saisie identité, upload contrat PDF)
- Création des premiers standing orders (au moins 1)

Sans cet onboarding complété, certaines fonctions sont bloquées (notamment création de session avec consentement).

**Notifications**

Notifications push iOS automatiques pour :
- Licence expirant : J-90, J-30, J-7, J-1
- Standing order expirant : J-30, J-7
- Contrat MD expirant : J-60, J-30, J-7
- Audit MD à venir : J-7 et le jour J

Géré via Apple Push Notification Service + service notification programmé côté serveur (Supabase Edge Functions avec cron).

### Écran 5 — Stock et scan

**Fichiers à créer**
- `Features/Inventory/Views/InventoryListView.swift`
- `Features/Inventory/Views/InventoryDetailView.swift`
- `Features/Inventory/Views/BarcodeScannerView.swift`
- `Features/Inventory/Views/LotEntryView.swift`
- `Features/Inventory/ViewModels/InventoryViewModel.swift`
- `Features/Inventory/Services/BarcodeService.swift`

**Vue liste**

Header avec :
- Nombre total de références
- Valeur totale du stock
- Badge alerte si péremptions proches
- Bouton « Scanner » bien visible

SearchBar + filtres (catégorie, urgence).

Liste de cards groupées par référence (ex. tous les flacons NAD+ 500mg regroupés) :
- Nom du produit
- Quantité totale (somme de tous les lots)
- Date d'expiration la plus proche
- Badge couleur péremption

**Détail d'une référence**

Liste de tous les lots de cette référence :
- Numéro de lot
- Quantité restante / quantité initiale
- Date d'expiration
- Date de réception
- Prix unitaire
- Fournisseur

Action « Ajouter un lot » qui ouvre le scanner.
Action « Ajustement manuel » pour cas particuliers.

**Scan de code-barres**

Integration Google ML Kit :

```swift
import MLKitBarcodeScanning

class BarcodeService {
    private let barcodeScanner: BarcodeScanner
    
    init() {
        let format = BarcodeFormat.all
        let barcodeOptions = BarcodeScannerOptions(formats: format)
        self.barcodeScanner = BarcodeScanner.barcodeScanner(options: barcodeOptions)
    }
    
    func scanBarcode(from image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        let visionImage = VisionImage(image: image)
        barcodeScanner.process(visionImage) { barcodes, error in
            // gestion résultat
        }
    }
}
```

**Vue scanner**

Camera full screen avec :
- Vue caméra live (AVCaptureSession)
- Cadre de détection animé
- Indicateur visuel quand code détecté
- Confirmation tactile (vibration) à la détection

**Form après scan**

Une fois le code-barres détecté, écran de saisie complémentaire :
- Nom du produit (pré-rempli depuis catalogue interne, modifiable)
- Catégorie (dropdown)
- Numéro de lot (saisie manuelle ou OCR via Vision framework Apple si étiquette claire)
- Date d'expiration (DatePicker)
- Quantité initiale
- Prix d'achat unitaire
- Fournisseur (dropdown ou champ libre)
- Photo du flacon (optionnel)
- Bouton « Ajouter au stock »

**Logique de déduction lors d'une session**

Quand la nurse marque une session comme « complétée », elle est invitée à scanner le flacon utilisé. Le système :
1. Identifie le lot via le code-barres
2. Décrémente la quantité de 1
3. Crée une entrée dans `inventory_transactions` liant la session au lot
4. Si quantité = 0, marque le lot comme épuisé

**Alertes**

- J-15 avant péremption : notification push + alerte dans le dashboard inventory
- Quantité totale d'une référence < seuil défini par la nurse : notification

## Onboarding utilisateur

Premier launch après installation :

Étape 1 — Welcome screens (3 swipes)
Visuels et messages présentant la valeur d'HCPilot.

Étape 2 — Création compte
- Email + magic link via Supabase Auth
- Ou Apple Sign-In (recommandé pour iOS)

Étape 3 — Setup pratique
- Prénom, nom, téléphone
- État d'exercice (dropdown US states)
- Numéro de licence
- Date d'expiration de licence
- Type de licence (RN, NP, etc.)
- Nom de la pratique
- NPI number (optionnel mais recommandé)

Étape 4 — Setup Stripe Connect
- Bouton « Configurer mes paiements »
- Redirection vers Stripe Connect Express onboarding
- Webhook reçoit la confirmation à la fin
- Retour dans l'app avec confirmation visuelle

Étape 5 — Setup Medical Director
- Nom, email, numéro de licence MD
- Upload du contrat PDF
- Date début/fin contrat
- Fréquence d'audit

Étape 6 — Premier standing order
- Sélection d'une formulation parmi templates pré-créés (Myers, NAD+ 250mg, NAD+ 500mg, etc.)
- Ou création custom
- Demande de signature au MD via email envoyé automatiquement

Étape 7 — Bienvenue
- L'app est prête à créer le premier RDV

## Gestion HIPAA et sécurité

**Chiffrement at rest**
- Supabase active AES-256 par défaut
- Activer l'add-on HIPAA (paid feature) avant le premier client réel
- BAA signé avec Supabase (formulaire à remplir, prend 2-4 semaines)

**Chiffrement in transit**
- Tout en HTTPS/TLS 1.3 minimum
- Certificate pinning côté iOS pour les appels critiques

**Authentification**
- Magic link via email (Supabase Auth)
- Apple Sign-In pour iOS
- Pas de password (réduction surface d'attaque)
- Session token JWT avec refresh automatique
- Auto-logout après 30 minutes d'inactivité (configurable)

**Stockage local sécurisé**
- Keychain pour tokens
- Core Data ou SwiftData chiffré pour cache local
- Pas de stockage de PHI dans NSUserDefaults

**Photos et documents**
- Stockage Supabase Storage avec policies RLS
- URLs signées temporaires (expiration 1h) pour accès
- Pas d'URLs publiques

**Audit logs**
- Triggers PostgreSQL automatiques sur tables sensibles
- Conservation 7 ans minimum (durée légale US)
- Pas de suppression (soft delete uniquement)

**Politique de confidentialité**
- Page dédiée accessible depuis settings
- Notice of Privacy Practices conforme HIPAA
- Acceptation explicite à l'onboarding

## Gestion offline

Architecture offline-first partielle :

**Données mises en cache local**
- Sessions du jour et demain
- Liste des clients récents (50 derniers)
- Catalogue des formulations / standing orders
- Stock courant

**Données non disponibles offline**
- Création de paiement Stripe (impossible sans réseau)
- Signature de consentement (signature locale OK mais sync requise pour validation)
- Génération PDF (faite côté serveur)

**Sync automatique au retour de réseau**
- Queue de mutations en attente
- Retry avec exponential backoff
- Conflict resolution : last-write-wins pour MVP

## Notifications push

Configuration APNs avec Supabase Edge Functions :

**Types de notifications**
- Rappel RDV J-1 et H-2
- Cliente arrive en retard (si géoloc activée)
- Licence/MD/standing order expiration
- Stock bas / péremption proche
- Paiement reçu (confirmation)
- Audit logs alerts critiques

## Tests

**Tests unitaires**
- ViewModels : tester logique métier
- Services : tester appels API mockés
- Validators : tester règles de validation

**Tests UI**
- Flow onboarding complet
- Flow création client + consentement
- Flow paiement (mode test Stripe)
- Flow scan stock

**Tests d'intégration**
- Cycle complet : création RDV → session → consentement → paiement → facture

## Conformité App Store

**Catégorisation**
- Catégorie principale : Medical
- Sous-catégorie : Health & Fitness

**Documents requis**
- Politique de confidentialité
- Conditions d'utilisation
- Notice de conformité HIPAA
- Disclaimer médical

**App Privacy details**
Déclarer dans App Store Connect :
- Données médicales collectées
- Données financières collectées
- Données de localisation collectées
- Utilisation pour fonctionnalité de l'app uniquement (pas de tracking publicitaire)

## Variables d'environnement (.env)

```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
SUPABASE_SERVICE_ROLE_KEY=eyJ... (backend only)

STRIPE_PUBLISHABLE_KEY=pk_live_xxx
STRIPE_SECRET_KEY=sk_live_xxx (backend only)
STRIPE_WEBHOOK_SECRET=whsec_xxx

MAPBOX_ACCESS_TOKEN=pk.xxx

SENTRY_DSN=https://xxx@sentry.io/xxx

POSTHOG_API_KEY=phc_xxx

ENVIRONMENT=production|staging|development
```

## Sprint planning suggéré (12 semaines)

**Sprint 1 (semaines 1-2) — Foundations**
- Setup projet Xcode + dépendances
- Setup Supabase + schema initial
- Authentification + onboarding basic
- Tab bar + navigation principale

**Sprint 2 (semaines 3-4) — Clients et planning**
- Écran Ma Journée + sessions vides
- CRUD clients complet
- Création de RDV simple

**Sprint 3 (semaines 5-6) — Consentement et compliance**
- Module consentement multi-points
- Signature électronique + génération PDF
- Module compliance basique (licence + MD + standing orders)

**Sprint 4 (semaines 7-8) — Paiement**
- Intégration Stripe Connect Express
- Flow onboarding Stripe pour nurses
- Flow paiement complet + facture PDF
- Webhooks Stripe

**Sprint 5 (semaines 9-10) — Stock et scan**
- Intégration ML Kit
- CRUD inventory
- Flow scan code-barres
- Liaison session ↔ lot utilisé

**Sprint 6 (semaines 11-12) — Polish et beta**
- Notifications push
- Tests utilisateurs avec 5-10 beta-nurses
- Bug fixes
- Préparation App Store submission

## Notes pour Claude Code

**Méthode recommandée**
- Travailler sprint par sprint, pas tout d'un coup
- Pour chaque écran : commencer par le ViewModel + les models, puis la vue
- Tester chaque feature en isolation avant integration
- Utiliser des données mockées pour développement rapide, puis brancher Supabase
- Implémenter d'abord le happy path, ajouter les états d'erreur après

**Conventions de code**
- Nommage en anglais pour le code, commentaires en français OK si tu préfères
- SwiftLint config recommandée
- Composition over inheritance
- Préférer struct sur class quand possible (SwiftUI)
- Pas de force unwrap sauf cas absolument sûr et justifié
- Préférer `guard let` à `if let` en early return

**Patterns à éviter**
- ObservableObject lourd avec trop de @Published (préférer plusieurs ViewModels modulaires)
- Singletons globaux (préférer injection de dépendances via @Environment)
- Hard-coded strings (utiliser Localizable.strings)
- Logique métier dans les vues

**Sécurité**
- Toujours valider côté serveur, jamais faire confiance au client
- Sanitize tous les inputs
- Pas de logging de PHI en clair
- Activer HIPAA add-on Supabase **avant** le premier client réel

---

Voilà le brief. C'est dense mais complet. Tu peux le donner à Claude Code en plusieurs morceaux selon les sprints, ou en une fois si tu veux qu'il ait la vision complète dès le départ.

Mon conseil : **donne-lui d'abord la vue d'ensemble + Sprint 1 uniquement**. Quand le Sprint 1 est livré et validé, tu passes au Sprint 2. Tu évites de surcharger Claude Code avec trop de contexte d'un coup, ce qui dégrade souvent la qualité du code généré sur les early sprints.

Tu veux qu'on affine une partie spécifique (par exemple le détail du Sprint 1 en tâches encore plus granulaires), ou tu pars avec ça ?