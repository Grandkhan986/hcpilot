Guide complet des fees HCPilot
Préambule — Le modèle de fees en une page
HCPilot opère deux services distincts facturés indépendamment à ses clients (nurses indépendantes US), avec une troisième couche de fees Stripe payée séparément.
Service 1 — Subscription Platform Access (HCPilot)
299$ USD par mois, facturation récurrente automatique via Stripe Billing. Donne accès à la plateforme HCPilot dans son ensemble.
Service 2 — Per-Transaction Processing (HCPilot)
0.99$ USD par transaction processée. Collection automatique via le mécanisme Stripe Connect application_fee_amount au moment de chaque paiement patient.
Service 3 — Payment Processing (Stripe, indépendant de HCPilot)
2.9% + 0.30$ par transaction. Payé directement par la nurse à Stripe. HCPilot n'est pas impliqué dans ce flux financier.
Les deux services HCPilot sont indépendants l'un de l'autre. Chaque transaction génère une facture HCPilot immédiate de 0.99.LasubscriptiongeˊneˋreunefactureHCPilotmensuellede299. La subscription génère une facture HCPilot mensuelle de 299
.LasubscriptiongeˊneˋreunefactureHCPilotmensuellede299. Pas de consolidation des factures. Pas de mélange comptable entre HCPilot et Stripe.

Partie 1 — Guide technique
Architecture générale
Le système repose sur trois composants Stripe distincts qui s'articulent :
Stripe Connect (mode platform) : configuré sur le compte HCPilot Pte Ltd Singapour. Permet l'orchestration des paiements patient → nurse avec prélèvement automatique de la fee transactionnelle de 0.99$.
Stripe Billing : configuré sur le compte HCPilot Pte Ltd. Gère la subscription mensuelle 299$ via recurring charges sur la carte de la nurse.
Stripe Standard Accounts (US) : un par nurse, créés via OAuth depuis HCPilot. Ce sont des comptes Stripe US indépendants, propriété de la nurse, qui hébergent les fonds patients.
Setup initial Stripe Connect
Activation sur le compte HCPilot Pte Ltd
Depuis le dashboard Stripe en mode test puis en mode production :

Settings → Connect → Get started
Type : Platform or marketplace
Description du business : "B2B SaaS platform providing software services to independent healthcare professionals operating in the United States"
Industry : Software / SaaS platform

Configuration OAuth

Enable OAuth onboarding : ON
Redirect URIs : https://hcpilot.app/api/stripe/oauth/callback
Logo et branding HCPilot uploadés
Configuration des emails branding

Variables d'environnement
STRIPE_SECRET_KEY=sk_test_xxx              # secret API key
STRIPE_PUBLISHABLE_KEY=pk_test_xxx         # public key (frontend)
STRIPE_CONNECT_CLIENT_ID=ca_xxx            # client_id pour OAuth
STRIPE_WEBHOOK_SECRET=whsec_xxx            # secret pour vérifier webhooks
STRIPE_PRICE_ID_SUBSCRIPTION=price_xxx     # ID du price 299$/month
ENCRYPTION_KEY=xxx                          # clé pour chiffrer les access tokens
Création du produit subscription dans Stripe
Dans le dashboard Stripe, créer le produit subscription :

Product name : "HCPilot Pro Platform Access"
Description : "Monthly subscription for HCPilot platform access"
Price : $299.00 USD per month, recurring
Récupérer le price_id pour l'env

Flow d'onboarding nurse — OAuth
Étape 1 — Initier OAuth depuis HCPilot
typescriptrouter.get('/api/stripe/oauth/start', async (req, res) => {
  const nurse = await db.nurses.findById(req.user.id);
  
  // KYC interne préalable obligatoire
  if (!nurse.rn_license_verified_at || !nurse.medical_director_verified) {
    return res.status(400).json({ 
      error: 'Complete profile verification first' 
    });
  }
  
  // CSRF state token pour sécurité
  const state = crypto.randomUUID();
  await db.oauthStates.create({
    state,
    nurse_id: nurse.id,
    expires_at: new Date(Date.now() + 30 * 60 * 1000)
  });
  
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: process.env.STRIPE_CONNECT_CLIENT_ID,
    scope: 'read_write',
    state,
    'stripe_user[country]': 'US',
    'stripe_user[business_type]': 'individual',
    'stripe_user[email]': nurse.email,
    'stripe_user[first_name]': nurse.first_name,
    'stripe_user[last_name]': nurse.last_name,
    'stripe_user[phone_number]': nurse.phone,
    'redirect_uri': 'https://hcpilot.app/api/stripe/oauth/callback'
  });
  
  res.json({ url: `https://connect.stripe.com/oauth/authorize?${params}` });
});
Étape 2 — Callback OAuth et token exchange
typescriptrouter.get('/api/stripe/oauth/callback', async (req, res) => {
  const { code, state, error } = req.query;
  
  if (error) return res.redirect('/stripe/connect-failed');
  
  const stateRecord = await db.oauthStates.findOne({ state });
  if (!stateRecord || stateRecord.expires_at < new Date()) {
    return res.redirect('/stripe/connect-failed?reason=invalid_state');
  }
  
  try {
    const response = await stripe.oauth.token({
      grant_type: 'authorization_code',
      code: code as string
    });
    
    const { stripe_user_id, access_token, refresh_token } = response;
    const account = await stripe.accounts.retrieve(stripe_user_id);
    
    await db.nurseStripeAccounts.create({
      nurse_id: stateRecord.nurse_id,
      stripe_account_id: stripe_user_id,
      stripe_access_token: encrypt(access_token),
      stripe_refresh_token: refresh_token ? encrypt(refresh_token) : null,
      charges_enabled: account.charges_enabled,
      payouts_enabled: account.payouts_enabled,
      country: account.country,
      default_currency: account.default_currency,
      connected_at: new Date()
    });
    
    await db.oauthStates.delete({ state });
    
    if (account.charges_enabled) {
      return res.redirect('/stripe/connect-success');
    } else {
      return res.redirect('/stripe/connect-pending-review');
    }
    
  } catch (error) {
    console.error('OAuth error:', error);
    return res.redirect('/stripe/connect-failed?reason=token_exchange_failed');
  }
});
Étape 3 — Setup subscription via Stripe Billing
typescriptasync function setupNurseSubscription(nurseId: string) {
  const nurse = await db.nurses.findById(nurseId);
  
  // Customer sur le compte HCPilot Pte Ltd
  const customer = await stripe.customers.create({
    email: nurse.email,
    name: `${nurse.first_name} ${nurse.last_name}`,
    metadata: { hcpilot_nurse_id: nurse.id }
  });
  
  // Setup Intent pour collecter la carte
  const setupIntent = await stripe.setupIntents.create({
    customer: customer.id,
    payment_method_types: ['card'],
    usage: 'off_session'
  });
  
  await db.subscriptions.create({
    nurse_id: nurse.id,
    stripe_customer_id: customer.id,
    setup_intent_id: setupIntent.id,
    status: 'pending_card_setup',
    monthly_amount_cents: 29900
  });
  
  return { 
    customer_id: customer.id, 
    setup_intent_client_secret: setupIntent.client_secret 
  };
}

async function activateSubscription(nurseId: string, paymentMethodId: string) {
  const subRecord = await db.subscriptions.findOne({ nurse_id: nurseId });
  
  await stripe.paymentMethods.attach(paymentMethodId, {
    customer: subRecord.stripe_customer_id
  });
  
  await stripe.customers.update(subRecord.stripe_customer_id, {
    invoice_settings: { default_payment_method: paymentMethodId }
  });
  
  const subscription = await stripe.subscriptions.create({
    customer: subRecord.stripe_customer_id,
    items: [{ price: process.env.STRIPE_PRICE_ID_SUBSCRIPTION }],
    payment_settings: { 
      save_default_payment_method: 'on_subscription' 
    }
  });
  
  await db.subscriptions.update(subRecord.id, {
    stripe_subscription_id: subscription.id,
    status: 'active',
    current_period_start: new Date(subscription.current_period_start * 1000),
    current_period_end: new Date(subscription.current_period_end * 1000),
    payment_method_id: paymentMethodId
  });
  
  return subscription;
}
Flow de transaction patient
Étape 1 — Création du PaymentIntent avec application_fee
typescriptasync function createPatientPayment(sessionId: string, serviceAmountCents: number) {
  const session = await db.sessions.findById(sessionId);
  const nurse = await db.nurses.findById(session.nurse_id);
  const nurseAccount = await db.nurseStripeAccounts.findOne({ 
    nurse_id: nurse.id 
  });
  const patient = await db.patients.findById(session.patient_id);
  
  if (!nurseAccount.charges_enabled) {
    throw new Error('Nurse account not ready to accept payments');
  }
  
  const totalAmountCents = serviceAmountCents + 99;  // +$0.99 platform fee
  
  const paymentIntent = await stripe.paymentIntents.create({
    amount: totalAmountCents,
    currency: 'usd',
    description: 'Mobile health service',
    receipt_email: patient.email,
    
    // LA LIGNE CLÉ : 0.99$ application fee vers HCPilot
    application_fee_amount: 99,
    
    metadata: {
      hcpilot_session_id: session.id,
      hcpilot_nurse_id: nurse.id,
      hcpilot_patient_id: patient.id,
      hcpilot_service_amount: serviceAmountCents.toString()
    },
    
    automatic_payment_methods: { enabled: true }
  }, {
    stripeAccount: nurseAccount.stripe_account_id,
    idempotencyKey: `session_${sessionId}_payment_v1`
  });
  
  const payment = await db.payments.create({
    session_id: session.id,
    nurse_id: nurse.id,
    patient_id: patient.id,
    stripe_payment_intent_id: paymentIntent.id,
    stripe_account_id: nurseAccount.stripe_account_id,
    total_amount_cents: totalAmountCents,
    service_amount_cents: serviceAmountCents,
    platform_fee_cents: 99,
    status: 'pending'
  });
  
  await db.platformFees.create({
    nurse_id: nurse.id,
    payment_id: payment.id,
    session_id: session.id,
    stripe_payment_intent_id: paymentIntent.id,
    amount_cents: 99,
    status: 'pending'
  });
  
  return {
    payment_id: payment.id,
    payment_url: generatePaymentUrl(paymentIntent.id),
    client_secret: paymentIntent.client_secret
  };
}
Étape 2 — Webhook payment_intent.succeeded
typescriptasync function handlePaymentIntentSucceeded(event) {
  const pi = event.data.object;
  
  const payment = await db.payments.findOne({
    stripe_payment_intent_id: pi.id
  });
  if (!payment) return;
  
  await db.payments.update(payment.id, {
    status: 'succeeded',
    succeeded_at: new Date(),
    stripe_charge_id: pi.latest_charge
  });
  
  await db.platformFees.update(
    { stripe_payment_intent_id: pi.id },
    {
      status: 'collected',
      collected_at: new Date(),
      stripe_application_fee_id: pi.application_fee
    }
  );
  
  await db.sessions.update(payment.session_id, { status: 'paid' });
  
  // Queue génération de facture transaction async
  await queueTransactionInvoiceGeneration({
    payment_intent_id: pi.id,
    nurse_id: payment.nurse_id,
    session_id: payment.session_id,
    transaction_date: new Date(pi.created * 1000)
  });
  
  await sendNotificationToNurse(payment.nurse_id, {
    title: 'Payment received',
    body: `$${(payment.service_amount_cents/100).toFixed(2)} from your patient`
  });
}
Étape 3 — Génération asynchrone de la facture transaction
typescriptasync function generateTransactionInvoice(params) {
  const nurse = await db.nurses.findById(params.nurse_id);
  const invoiceNumber = await generateSequentialInvoiceNumber('transaction');
  
  const invoice = await db.invoices.create({
    invoice_number: invoiceNumber,
    nurse_id: nurse.id,
    invoice_type: 'transaction',
    
    session_id: params.session_id,
    payment_intent_id: params.payment_intent_id,
    
    amount_cents: 99,
    total_cents: 99,
    
    status: 'paid',
    issue_date: params.transaction_date,
    paid_date: params.transaction_date,
    
    line_items: [{
      description: `Platform usage fee - Session ${params.session_id}`,
      quantity: 1,
      unit_amount_cents: 99
    }]
  });
  
  const pdfBuffer = await generateTransactionInvoicePdf(invoice, nurse);
  const pdfUrl = await uploadToCdn(
    pdfBuffer, 
    `invoices/transactions/${invoiceNumber}.pdf`
  );
  
  await db.invoices.update(invoice.id, { pdf_url: pdfUrl });
  
  // PAS d'email envoyé (stratégie de réduction de friction)
  return invoice;
}

async function generateSequentialInvoiceNumber(type: 'transaction' | 'subscription') {
  const today = new Date();
  const dateString = format(today, 'yyyy-MM-dd');
  const prefix = type === 'transaction' ? 'HCP-T' : 'HCP-S';
  
  const result = await db.invoiceSequences.upsert({
    where: { date_type: { date: dateString, type } },
    update: { current_seq: { increment: 1 } },
    create: { date: dateString, type, current_seq: 1 }
  });
  
  const padded = String(result.current_seq).padStart(5, '0');
  return `${prefix}-${format(today, 'yyyy-MM-dd')}-${padded}`;
}
Étape 4 — Handler subscription invoice.payment_succeeded
typescriptasync function handleSubscriptionInvoicePaymentSucceeded(event) {
  const invoice = event.data.object;
  
  if (!invoice.subscription) return;
  
  const sub = await db.subscriptions.findOne({
    stripe_subscription_id: invoice.subscription
  });
  if (!sub) return;
  
  const invoiceNumber = await generateSequentialInvoiceNumber('subscription');
  
  const hcpilotInvoice = await db.invoices.create({
    invoice_number: invoiceNumber,
    nurse_id: sub.nurse_id,
    invoice_type: 'subscription',
    
    stripe_invoice_id: invoice.id,
    amount_cents: invoice.amount_paid,
    total_cents: invoice.amount_paid,
    status: 'paid',
    issue_date: new Date(invoice.created * 1000),
    paid_date: new Date(invoice.status_transitions.paid_at * 1000),
    
    line_items: [{
      description: 'HCPilot Pro - Monthly Platform Subscription',
      quantity: 1,
      unit_amount_cents: invoice.amount_paid
    }]
  });
  
  const pdfBuffer = await generateSubscriptionInvoicePdf(hcpilotInvoice);
  const pdfUrl = await uploadToCdn(
    pdfBuffer, 
    `invoices/subscriptions/${invoiceNumber}.pdf`
  );
  
  await db.invoices.update(hcpilotInvoice.id, { pdf_url: pdfUrl });
  
  await sendSubscriptionReceipt(sub.nurse_id, hcpilotInvoice, pdfUrl);
}
Database schema essentiel
sqlCREATE TABLE invoices (
  id                          UUID PRIMARY KEY,
  invoice_number              VARCHAR UNIQUE,
  nurse_id                    UUID FK,
  invoice_type                ENUM('transaction', 'subscription'),
  
  session_id                  UUID FK NULL,
  payment_intent_id           VARCHAR NULL,
  stripe_invoice_id           VARCHAR NULL,
  
  amount_cents                INTEGER,
  total_cents                 INTEGER,
  status                      ENUM('paid', 'pending', 'failed'),
  
  issue_date                  TIMESTAMP,
  paid_date                   TIMESTAMP NULL,
  
  line_items                  JSONB,
  pdf_url                     VARCHAR,
  
  created_at                  TIMESTAMP,
  updated_at                  TIMESTAMP
);

CREATE TABLE invoice_sequences (
  date                        DATE,
  type                        ENUM('transaction', 'subscription'),
  current_seq                 INTEGER,
  PRIMARY KEY (date, type)
);

CREATE TABLE platform_fees (
  id                          UUID PRIMARY KEY,
  nurse_id                    UUID FK,
  payment_id                  UUID FK,
  session_id                  UUID FK,
  
  stripe_payment_intent_id    VARCHAR,
  stripe_application_fee_id   VARCHAR,
  
  amount_cents                INTEGER,
  status                      ENUM('pending', 'collected', 'refunded'),
  
  collected_at                TIMESTAMP NULL,
  refunded_at                 TIMESTAMP NULL,
  
  created_at                  TIMESTAMP
);

CREATE TABLE subscriptions (
  id                          UUID PRIMARY KEY,
  nurse_id                    UUID FK,
  
  stripe_customer_id          VARCHAR,
  stripe_subscription_id      VARCHAR,
  payment_method_id           VARCHAR,
  
  monthly_amount_cents        INTEGER DEFAULT 29900,
  
  status                      ENUM('pending_card_setup', 'active', 'paused', 'cancelled', 'past_due'),
  current_period_start        TIMESTAMP,
  current_period_end          TIMESTAMP,
  
  created_at                  TIMESTAMP,
  cancelled_at                TIMESTAMP NULL
);
Sécurité
Chiffrement des tokens
Tous les access_token et refresh_token Stripe doivent être chiffrés au repos en AES-256-GCM avant stockage en DB.
Idempotency keys
Toutes les créations de PaymentIntents et autres opérations critiques utilisent des idempotency keys uniques pour éviter les doublons en cas de retry réseau.
Webhook signature verification
Tous les webhooks Stripe doivent vérifier leur signature via stripe.webhooks.constructEvent avant de processer.
HIPAA et PHI
Aucun PHI clinique dans les metadata Stripe. Limités aux IDs internes abstraits, descriptions génériques ("Mobile health service"), dates et montants.
Webhooks à configurer
Sur Connect webhooks endpoint :

payment_intent.succeeded
payment_intent.payment_failed
charge.refunded
charge.dispute.created
charge.dispute.closed
account.updated
account.application.deauthorized
application_fee.created
application_fee.refunded

Sur Account webhooks endpoint (subscription) :

customer.subscription.created
customer.subscription.updated
customer.subscription.deleted
invoice.payment_succeeded
invoice.payment_failed


Partie 2 — Guide juridique
Cadre général
HCPilot Pte Ltd, entité singapourienne, vend deux services software B2B à des nurses indépendantes US. Cette structure relève du droit commercial international (Singapour ↔ US), du droit healthcare US (notamment CPOM), et des régulations payment (Stripe ToS, card network rules).
Dimension 1 — Corporate Practice of Medicine (CPOM)
Le risque principal
Le fee splitting médical est prohibé dans environ 33 États US avec des intensités variables. Vous devez démontrer que vos fees ne constituent pas un partage de revenu médical avec une entité non-médicale.
Les 5 piliers de défense
Pilier 1 — Flat fee, pas pourcentage
Le 0.99$ est fixe quelle que soit la valeur de la session. Une session à 50$ ou 500$ génère la même fee. Ce critère est essentiel pour échapper au fee splitting.
Pilier 2 — Service software documenté
La fee rémunère explicitement un service identifiable : infrastructure HIPAA, payment orchestration, scheduling, inventory, compliance dashboard, reporting fiscal. Chaque dollar prélevé correspond à de la valeur technique livrée.
Pilier 3 — Facturation explicite
Chaque transaction génère une facture HCPilot officielle. C'est une transaction commerciale B2B documentée, pas un prélèvement opaque.
Pilier 4 — Consentement explicite
La nurse signe des Terms of Service qui détaillent la fee, son mécanisme de collection, et autorisent explicitement HCPilot à la prélever.
Pilier 5 — Aucune influence sur la pratique médicale
HCPilot ne participe pas aux décisions cliniques, ne sélectionne pas les patients, ne fixe pas les prix médicaux. La nurse garde 100% du contrôle de sa pratique et 100% de son revenu médical net.
Wording protecteur dans les Terms of Service
Section X - Nature of Platform Fees

Subscriber acknowledges and agrees that the Platform 
Fee ($0.99 per transaction) and the Subscription Fee 
($299/month) are flat usage-based fees for the 
Software Services provided by HCPilot, and are NOT:

(a) A commission on Subscriber's medical revenue;
(b) A percentage of any patient payment;
(c) A fee split with HCPilot for medical services;
(d) Compensation for medical, clinical, or 
    professional services performed by Subscriber.

The Platform Fee remains constant regardless of the 
amount Subscriber charges to patients. HCPilot does 
not participate in Subscriber's clinical decisions, 
patient selection, pricing strategies, or treatment 
protocols. Subscriber retains full control of their 
medical practice and 100% of their medical revenue 
net of standard payment processing fees.
États sensibles à valider spécifiquement
Six États requièrent une attention particulière dans le memo juridique : California, New York, Texas, New Jersey, Illinois, Pennsylvania.
Dimension 2 — HIPAA Compliance
Status de HCPilot
HCPilot est Business Associate des nurses pour les données patient stockées dans la plateforme (Supabase HIPAA). Un BAA doit être signé entre HCPilot et chaque nurse.
Status de Stripe
Stripe est protégé par Section 1179 du HIPAA qui exempte les payment processors du statut de Business Associate, à condition que Stripe ne reçoive aucun PHI clinique.
Règles strictes sur les données Stripe
Dans tous les metadata, descriptions, statement descriptors, et autres champs Stripe, jamais transmettre :

Type de traitement médical spécifique (NAD+, Glutathione, vitamine C, etc.)
Conditions médicales du patient
Allergies, médicaments
Notes cliniques

Limité à :

IDs internes abstraits (UUID des objets)
"Mobile health service" (générique)
Date de la session
Nom du patient (acceptable car c'est qui paie)
Montants

Dimension 3 — Money Transmitter Laws
Statut de HCPilot
Vous n'êtes pas Money Transmitter parce que vous ne transmettez jamais d'argent. L'argent patient va directement sur le compte Stripe de la nurse (Direct Charge). Votre fee de 0.99$ est prélevée par Stripe lui-même (qui est, lui, registered MSB avec licenses dans tous les États), et déposée sur votre compte HCPilot.
Conditions à maintenir

Ne jamais "hold" les fonds patient
Ne jamais agir comme escrow
Toujours utiliser Direct Charges (jamais Destination Charges avec transfer cross-border)
Ne pas devenir Custodial pour des fonds nurse

Dimension 4 — Stripe ToS Compliance
Disclosure obligatoire de la fee
Dans vos Terms of Service nurse, écrire explicitement le mécanisme de collection via application_fee_amount.
Pas de claims trompeurs
Éviter "0% commission", "Free payments", "No fees" qui seraient faux. Utiliser "$0.99 per transaction", "Flat platform fee", "0.5% of typical session".
Compliance avec les card network rules
Avec Direct Charges + application_fee, vous êtes dans une catégorie standard reconnue (Marketplace fee), supportée par Visa, Mastercard, Amex. Pas de double surcharge possible.
Dimension 5 — Fiscalité
Côté Singapour (HCPilot Pte Ltd)
Imposable à 17% corporate tax SG, avec exemptions startup (75% sur les 100k SGD initiaux les 3 premières années).
GST 0% sur les exports de services (vos services SaaS sont vendus à des clients US, donc exports zero-rated).
Substance économique à maintenir : nominee director, registered office, corporate secretary, accountant. Coût annuel : 5-8k SGD.
Reporting annuel : Form C-S si revenu <5M SGD, ECI dans les 3 mois après fin d'exercice.
Côté US
No nexus : pas d'employé, pas de bureau, pas d'inventory. Vous n'êtes pas imposable à US Income Tax.
Form W-8BEN-E à fournir à Stripe pour certifier votre foreign entity status. Withholding rate généralement 0% sur les SaaS services via US-Singapour tax treaty.
Form 1042-S annuel de Stripe documentant les application fees collectées. Informational only, pas d'impôt à payer aux US.
Sales tax US sur SaaS B2B : généralement non applicable à une foreign entity sans nexus.
Documents juridiques essentiels

Terms of Service nurse (contrat principal)
BAA HIPAA (Business Associate Agreement avec chaque nurse)
Privacy Policy
Patient disclosure (sur la page de paiement)
Acceptable Use Policy
Refund Policy
Cookie Policy

Plan de validation juridique pré-launch
Avocat US healthcare (4-6k USD) : Memo de validation 50-États CPOM, review Terms of Service, review BAA, review patient disclosure, recommandations par État sensible. Timeline : 3-4 semaines.
Fiscaliste cross-border SG/US (1-2k USD) : Validation structure, W-8BEN-E, substance économique SG, sales tax US, IRAS reporting. Timeline : 2-3 semaines.

Partie 3 — Guide commercial
Le positionnement de marché
À 299/mois+0.99/mois + 0.99
/mois+0.99 par session, HCPilot se positionne comme la platform premium pour mobile IV practices établies, pas comme un outil léger pour nurses débutantes.
Segment cible
Idéal : RN avec 50-300 sessions/mois, practice établie depuis 6+ mois, pratique dans 1-3 États, revenue mensuel 10-60k$, cherchant à scaler.
Pas votre cible : nurse débutante qui teste le concept, volume <30 sessions/mois, practice purement amateur.
La structure complète des coûts pour la nurse
Pour une nurse faisant 100 sessions/mois à 200$ chacune (20k$ revenue mensuel) :
ItemMontant% du revenueHCPilot subscription$299.001.50%HCPilot platform fees (100 × $0.99)$99.000.50%Stripe processing (2.9% + $0.30 × 100)$613.003.07%Total operating costs$1,011.005.06%Net to nurse$18,989.0094.94%
Comparaison concurrence
ProviderTotal cost/mo (on $20K)% of revenueHCPilot$1,0115.06%Mangomint Pro + payments$1,3486.75%Independent (DIY, just Stripe)$6133.07% (no features)Hydreight (20% commission)$4,61323.07%
Le pitch principal : 4.6x moins cher qu'Hydreight, avec les mêmes features et plus.
La pricing page
HCPilot Pricing - Complete Mobile IV Practice Platform

$299/month + $0.99 per session

Designed for mobile IV nurses doing 50+ sessions/month.

EVERYTHING INCLUDED
─────────────────────────────────────
✓ Smart scheduling & route optimization
✓ Multi-state compliance & MD audit tracking
✓ FDA-grade inventory & lot management
✓ HIPAA-compliant patient records
✓ Integrated payments via your own Stripe
✓ Real-time revenue & 1099 reporting
✓ Patient communication automation
✓ Concierge support (live chat + monthly review)

YOUR TOTAL COSTS (Example: 100 sessions/month at $200)
─────────────────────────────────────
HCPilot subscription:           $299.00
HCPilot platform usage:          $99.00
Stripe payment processing:      $613.00
                              (2.9% + $0.30 per transaction,
                               paid directly to Stripe)
─────────────────────────────────────
Total operating costs:        $1,011.00 (5.06%)
You keep:                    $18,989.00 (94.94%)

COMPARE WITH ALTERNATIVES
─────────────────────────────────────
Hydreight (20% + fees):        $4,613/month (23.07%)
Mangomint Pro + payments:      $1,348/month (6.75%)
DIY (just Stripe):               $613/month (3.07%)
                               but you lose all platform features

You save $3,602/month vs Hydreight.
That's $43,224/year staying in YOUR pocket.

100% of your patient revenue stays with you.
We charge for the software, not for your patients.

[Start your 30-day free trial]
[Schedule a demo]
Le revenue net pour HCPilot
Maintenant le pendant côté HCPilot, en intégrant les fees Stripe que vous payez.
Per-transaction (côté HCPilot)

Application_fee collectée : 100 × 0.99$ = 99$/mois
Fees Stripe sur application_fee : 0$ (gratuit avec Standard accounts)
Payout fees vers SG : ~0$ (standard payouts gratuits)
Net HCPilot per-transaction : 99$/mois

Subscription (côté HCPilot)

Subscription collectée : 299$/mois
Stripe processing (2.9% + 0.30):8.97) : 8.97
):8.97
Stripe Billing fee (0.5%) : 1.50$
Net HCPilot subscription : 288.53$/mois

Total net HCPilot par nurse active

Per-transaction : 99$
Subscription : 288.53$
Total brut : 398$/mois
Total net après Stripe fees : 387.53$/mois
Marge nette sur fees Stripe : 97.4%

Projections ARR nettes
À 200 nurses actives :

ARR brut : 955 200$
Fees Stripe totaux : 25 128$
ARR net : 930 072$

À 500 nurses actives :

ARR brut : 2 388 000$
Fees Stripe totaux : 62 820$
ARR net : 2 325 180$

À 1000 nurses actives :

ARR brut : 4 776 000$
Fees Stripe totaux : 125 640$
ARR net : 4 650 360$

Stratégies d'optimisation des fees Stripe
Négociation Volume Pricing
À partir de 80 000/moisdeprocessingvolume,Stripeacceptedeneˊgocierlesrates.Sur500nursesactives,votrevolumemensuelatteint 10M/mois de processing volume, Stripe accepte de négocier les rates. Sur 500 nurses actives, votre volume mensuel atteint ~10M
/moisdeprocessingvolume,Stripeacceptedeneˊgocierlesrates.Sur500nursesactives,votrevolumemensuelatteint 10M (subscriptions + transactions cumulées). À ce niveau, négociation sérieuse possible :

2.9% → 2.5-2.7%
0.5% Billing fee → 0.3-0.4%

Économies estimées : 30-50k$/mois à 500+ nurses.
Settlement en USD
Tenir un wallet USD sur Stripe SG et payouter vers un compte multi-currency SG (DBS, OCBC, Aspire, Wise Business) évite les fees FX de 1-2%.
Le pitch d'onboarding (sales call)
Minute 1 — Le contexte
"Vous générez probablement 20-40k/moisenrevenuepatient.Laquestionn′estpascombienvouspayezenoutils,c′estcombienvotrebusinessgrowthvaut.Hydreightprend20/mois en revenue patient. La question n'est pas combien vous payez en outils, c'est combien votre business growth vaut. Hydreight prend 20%, soit 4-8k
/moisenrevenuepatient.Laquestionn′estpascombienvouspayezenoutils,c′estcombienvotrebusinessgrowthvaut.Hydreightprend20 par mois sur votre business. C'est 50-100k$ par an que vous laissez partir vers eux. Avec HCPilot, vous récupérez 90% de ce montant en gardant les mêmes outils."
Minute 2 — Le différenciateur produit
"Hydreight est conçu pour les cliniques avec employees. HCPilot est conçu pour vous, nurse indépendante mobile. Compliance par État, MD audit tracking automatique, route optimization, inventory mobile, intégration avec votre propre Stripe pour que vous gardiez 100% du contrôle de votre argent."
Minute 3 — L'économie chiffrée
"À 100 sessions/mois, vous payez 1 011$ total en operating costs. Vous gardez 18 989.AvecHydreight,vousgarderiez15387. Avec Hydreight, vous garderiez 15 387
.AvecHydreight,vousgarderiez15387. La différence : 3 602$ par mois. Pour exactement les mêmes outils."
Minute 4 — L'invitation
"On vous offre un free trial 30 jours, no credit card upfront. Vous testez le système, vous voyez la qualité, vous décidez. Si ça ne vous convient pas, vous partez et vous ne nous devez rien. Si ça vous convient, vous économisez 43k$/an."
Les objections classiques et réponses
"299$ c'est cher"
"Le prix n'est pas 299.Leprixest299. Le prix est 299
.Leprixest299 pour gagner 3 602$/mois vs Hydreight. C'est un ROI de 12x sur votre investissement HCPilot."
"0.99$ par session c'est en plus de la subscription ?"
"Oui, c'est inclus comme platform usage fee. Pour 100 sessions, ça fait 99/mois.ComparezavecHydreightquiprend4000/mois. Comparez avec Hydreight qui prend 4 000
/mois.ComparezavecHydreightquiprend4000 pour le même volume. Notre 99$ remplace leur 4 000$."
"Et les fees Stripe ?"
"Les 2.9% + 0.30$ vont à Stripe directement, pas à HCPilot. C'est le coût standard de processing card payments aux US. Pas négociable au niveau individuel nurse mais on le négocie à notre échelle de platform. Hydreight, Mangomint, Mindbody, tout le monde paie les mêmes fees Stripe."
"Pourquoi pas Mangomint ?"
"Mangomint est super pour les med spas avec staff. Pas optimisé pour mobile/field service. HCPilot est natif mobile : route optimization, kit inventory, compliance multi-États avec MD audit workflow. Pour le même prix que Mangomint Pro, vous avez la spécialisation qui matche votre workflow."
Stratégie d'acquisition
Channels prioritaires
1. Cold outbound LinkedIn : profil cible "Registered Nurse" + "Mobile IV" + "Owner". 50 messages/jour, taux de réponse 5-10%.
2. Partnerships compounding pharmacies : Empower, Olympia, etc. Référencement croisé avec commission 5-10% lifetime.
3. Communautés Facebook/Reddit nurses IV : présence éducative via articles compliance, business operations.
4. Content marketing SEO : "How to start mobile IV business", "Multi-state IV compliance guide".
5. Conférences healthcare : American Med Spa Association, IV therapy conferences. 1-2 par trimestre.
CAC tolérable
LTV par nurse à 100 sessions/mois : ARPU 4 776/an×4ans=19104/an × 4 ans = 19 104
/an×4ans=19104 LTV.
Ratio LTV/CAC 3:1 : CAC tolérable de 6 368$ par nurse.
Modélisation financière 3 ans
Hypothèses

100 sessions/mois moyenne par nurse
200$ revenue moyen par session
Churn 3%/mois
Acquisition : 15 nurses/mois an 1, 30/mois an 2, 50/mois an 3

Projections
Année 1 : 150 nurses fin d'année, ARR 715 800$ brut / 696 600$ net après Stripe fees. Coûts opérationnels ~400k$. Profit avant impôt : break-even à légèrement positif.
Année 2 : 450 nurses fin d'année, ARR 2 147 400$ brut / 2 091 400$ net. Coûts opérationnels ~1.1M.Profitavantimpo^t: 990k. Profit avant impôt : ~990k
.Profitavantimpo^t: 990k.
Année 3 : 950 nurses fin d'année, ARR 4 533 600$ brut / 4 413 600$ net. Coûts opérationnels ~2.1M.Profitavantimpo^t: 2.3M. Profit avant impôt : ~2.3M
.Profitavantimpo^t: 2.3M.
Avec les exemptions startup IRAS SG, tax burden minimal les premières années. Année 3, 17% sur ~2.3M$ = ~390k$ de tax. Net profit après tax année 3 : ~1.9M$.
KPIs business à tracker
Acquisition

Cost Per Lead par channel
Demo-to-trial conversion rate
Trial-to-paid conversion rate
CAC fully loaded
Time-to-paid (jours)

Retention

Monthly Churn Rate (target <3%)
Annual Churn Rate (target <30%)
Net Revenue Retention (target >100%)
Gross Margin (target >80%)

Revenue

MRR from subscriptions
Transaction Revenue (per-session fees)
ARR brut et net
ARPU
Revenue Mix (sub vs transaction, target 75/25)

Usage product

Active Nurses (DAU, WAU, MAU)
Average Sessions per Nurse per Month
GMV processed through HCPilot
Transaction Success Rate


Synthèse exécutive
HCPilot opère un modèle de fees dual élégant : subscription mensuelle de 299$ + 0.99$ per-transaction via Stripe Connect application_fee. Plus le payment processing Stripe standard (2.9% + 0.30$) que paie la nurse directement.
Techniquement : implémentation propre via Stripe Connect Standard avec Direct Charges + Stripe Billing pour la subscription. Architecture scalable, automation totale, edge cases gérés. Standard accounts évitent les Connect fees récurrents.
Juridiquement : modèle défendable par flat fee + service software documenté + facturation immédiate. Compliance CPOM, HIPAA, Money Transmitter, et Stripe ToS solides avec wording approprié et validation avocat US healthcare.
Commercialement : positionné comme premium pour established practices, avec un pitch économique imbattable (4.6x moins cher qu'Hydreight) et différenciation technique claire face à Mangomint/Mindbody.
Économiquement pour HCPilot : 387.53$ net par nurse par mois après fees Stripe (97.4% de marge sur fees). À 200 nurses actives, ARR net de 930k.Aˋ1000nurses,ARRnetde4.65M. À 1000 nurses, ARR net de 4.65M
.Aˋ1000nurses,ARRnetde4.65M.
Le modèle peut générer 700k$ ARR brut en année 1, 2.1M$ en année 2, 4.5M$ en année 3 avec exécution disciplinée. Profit après tax année 3 : ~1.9M$.
Points critiques restants à valider : sandbox technique du mécanisme application_fee SG → US (2-3 jours dev) et consultation juridique US healthcare (4-6 semaines, 4-6k$). Une fois ces deux validations passées, le modèle est prêt pour le launch.