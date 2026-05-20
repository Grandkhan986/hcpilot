import SwiftUI

/// Hub des documents légaux et réglementaires (brief §HIPAA, §App Store).
/// 4 documents requis pour la soumission App Store et la conformité :
///   - Politique de confidentialité
///   - Notice of Privacy Practices (HIPAA §164.520)
///   - Disclaimer médical
///   - Conditions d'utilisation
struct LegalDocsView: View {
    var body: some View {
        List {
            Section("Documents") {
                NavigationLink(destination: PrivacyPolicyView()) {
                    Label("Politique de confidentialité", systemImage: "lock.shield")
                }
                NavigationLink(destination: HIPAANoticeView()) {
                    Label("Notice of Privacy Practices (HIPAA)", systemImage: "doc.text.fill")
                }
                NavigationLink(destination: MedicalDisclaimerView()) {
                    Label("Disclaimer médical", systemImage: "exclamationmark.triangle.fill")
                }
                NavigationLink(destination: TermsOfUseView()) {
                    Label("Conditions d'utilisation", systemImage: "doc.text")
                }
            }
            Section("Contact") {
                HStack {
                    Label("Privacy Officer", systemImage: "envelope")
                    Spacer()
                    Text("privacy@hcpilot.com").font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Label("Support", systemImage: "questionmark.circle")
                    Spacer()
                    Text("support@hcpilot.com").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Version") {
                HStack {
                    Text("HCPilot")
                    Spacer()
                    Text("v1.0.0 (MVP)").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Mentions légales")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Privacy Policy

private struct PrivacyPolicyView: View {
    var body: some View {
        DocumentScroll(title: "Politique de confidentialité", updated: "Mai 2026") {
            Paragraph("HCPilot est une application destinée aux infirmières IV mobiles indépendantes aux États-Unis. Cette politique décrit la collecte, l'utilisation, le stockage et le partage de vos données.")

            Heading("1. Données collectées")
            Bullet("Identité du soignant : nom, email, téléphone, numéro de licence, NPI, État d'exercice.")
            Bullet("Données client : nom, contact, date de naissance, adresse, antécédents, allergies, médication, contact d'urgence, ID document.")
            Bullet("Données de session : date, formulation administrée, signes vitaux, notes, photos, signatures.")
            Bullet("Données financières : montants, méthodes de paiement (transitent via Stripe).")
            Bullet("Données de géolocalisation : capturées uniquement à la signature des consentements (horodatage).")
            Bullet("Métadonnées techniques : adresse IP, modèle de l'appareil, version iOS.")

            Heading("2. Finalités")
            Bullet("Fourniture du service de gestion de pratique IV mobile.")
            Bullet("Conformité réglementaire (HIPAA, scope of practice par État, audit MD).")
            Bullet("Facturation et traitement des paiements.")
            Bullet("Audit logs immuables sur les actions sensibles.")

            Heading("3. Stockage et sécurité")
            Bullet("Chiffrement au repos AES-256 (Supabase + add-on HIPAA — BAA signé).")
            Bullet("Chiffrement en transit TLS 1.3.")
            Bullet("Token de session stocké dans le Keychain iOS (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly).")
            Bullet("Cache local protégé par NSFileProtectionCompleteUntilFirstUserAuthentication.")
            Bullet("Pas de stockage de PHI dans NSUserDefaults.")

            Heading("4. Durée de conservation")
            Paragraph("Les données médicales et d'audit sont conservées 7 ans (obligation HIPAA §164.530(j)). Les données de facturation sont conservées selon les exigences fiscales US (généralement 7 ans). Les données effacées (archivage client) restent dans la room d'archives accessible au soignant.")

            Heading("5. Partage")
            Bullet("Medical Director : accès limité aux dossiers couverts par sa standing order, pour les audits réglementaires.")
            Bullet("Stripe (paiements) : montants, identifiants de transaction. Pas de PHI.")
            Bullet("Aucun partage publicitaire ou tiers commercial.")

            Heading("6. Vos droits (sous HIPAA)")
            Bullet("Accès à vos PHI et copie sous 30 jours.")
            Bullet("Demande de rectification.")
            Bullet("Demande de restriction d'utilisation.")
            Bullet("Comptabilité des divulgations sous 6 ans.")
            Bullet("Plainte au Privacy Officer ou au HHS Office for Civil Rights.")
        }
    }
}

// MARK: - HIPAA Notice

private struct HIPAANoticeView: View {
    var body: some View {
        DocumentScroll(title: "Notice of Privacy Practices", updated: "Effective Mai 2026") {
            Paragraph("This notice describes how medical information about your clients may be used and disclosed and how clients can get access to this information. Please review it carefully. Required under 45 C.F.R. §164.520.")

            Heading("Uses and disclosures of PHI")
            Bullet("Treatment: PHI used to coordinate IV care across nurse, Medical Director, and pharmacy partners.")
            Bullet("Payment: PHI used to bill clients and process payments via Stripe Connect.")
            Bullet("Healthcare operations: quality assurance, audit logs, compliance reviews.")

            Heading("Client rights")
            Bullet("Right to access PHI (request within 30 days).")
            Bullet("Right to request amendment of PHI.")
            Bullet("Right to request restrictions on uses/disclosures.")
            Bullet("Right to confidential communications.")
            Bullet("Right to accounting of disclosures.")
            Bullet("Right to a paper copy of this notice.")
            Bullet("Right to file a complaint without retaliation.")

            Heading("Security safeguards")
            Bullet("Administrative: workforce training, access controls, sanction policies.")
            Bullet("Physical: device encryption, lock-screen requirement, remote wipe via MDM.")
            Bullet("Technical: TLS 1.3, AES-256 at rest, Keychain for credentials, audit logs append-only.")

            Heading("Breach notification")
            Paragraph("In the event of a breach affecting unsecured PHI, clients will be notified within 60 days as required by HITECH Act §13402. Notification to HHS and media (if breach affects >500 individuals) as required.")

            Heading("Privacy Officer")
            Paragraph("Contact privacy@hcpilot.com to exercise your rights or file a complaint. You may also file directly with the HHS Office for Civil Rights at hhs.gov/ocr/privacy/hipaa/complaints.")
        }
    }
}

// MARK: - Medical Disclaimer

private struct MedicalDisclaimerView: View {
    var body: some View {
        DocumentScroll(title: "Disclaimer médical", updated: "Mai 2026") {
            Paragraph("HCPilot est un outil de gestion de pratique pour infirmières IV mobiles. **Il ne fournit pas d'avis médical, de diagnostic, ni de traitement.**")

            Heading("Responsabilité clinique")
            Paragraph("Toutes les décisions cliniques restent sous la responsabilité du soignant licencié et du Medical Director qui supervise sa pratique. Les standing orders, formulations et protocoles ne constituent pas une prescription individuelle et doivent être appliqués dans le respect du scope of practice de l'État d'exercice.")

            Heading("Urgences médicales")
            Paragraph("En cas d'urgence (réaction anaphylactique, perte de conscience, douleur thoracique), composer immédiatement le **911**. Ne pas utiliser HCPilot pour gérer une urgence.")

            Heading("Limites de l'outil")
            Bullet("Le scan de code-barres ne remplace pas la vérification manuelle des informations du lot (péremption, intégrité du flacon).")
            Bullet("L'optimisation d'itinéraire est une suggestion ; le soignant adapte selon les conditions de terrain.")
            Bullet("Les rappels de conformité (J-90, J-30, J-7) sont indicatifs ; la responsabilité de renouveler licences, contrats MD et standing orders incombe au soignant.")
            Bullet("Les notifications push sont gérées localement par iOS ; HCPilot ne garantit pas leur livraison.")

            Heading("Conformité réglementaire")
            Paragraph("Le soignant utilisateur garantit qu'il opère dans le respect des lois et règlements de son État, notamment du scope of practice de sa licence et des protocoles d'administration IV en pratique mobile.")
        }
    }
}

// MARK: - Terms of Use

private struct TermsOfUseView: View {
    var body: some View {
        DocumentScroll(title: "Conditions d'utilisation", updated: "Mai 2026") {
            Paragraph("Les présentes conditions régissent l'utilisation de l'application HCPilot. Par l'utilisation de l'application, vous acceptez ces termes.")

            Heading("1. Licence")
            Paragraph("HCPilot vous accorde une licence personnelle, non-exclusive et non-transférable d'utilisation de l'application pour la gestion de votre pratique IV mobile.")

            Heading("2. Compte utilisateur")
            Bullet("Vous êtes responsable de la confidentialité de vos identifiants.")
            Bullet("Vous devez fournir des informations exactes lors de l'onboarding (licence, NPI, MD).")
            Bullet("Vous notifierez HCPilot immédiatement de toute utilisation non autorisée.")

            Heading("3. Propriété des données")
            Paragraph("Vos données et celles de vos clients vous appartiennent. HCPilot ne revendique aucune propriété sur les PHI. Vous pouvez exporter ou supprimer vos données à tout moment (sous réserve des obligations d'audit/conservation HIPAA).")

            Heading("4. Limitations de responsabilité")
            Paragraph("HCPilot est fourni « tel quel ». Dans la limite autorisée par la loi, HCPilot et ses dirigeants n'assument aucune responsabilité pour les dommages directs, indirects, ou consécutifs résultant de l'utilisation ou de l'indisponibilité de l'application, y compris les décisions cliniques prises sur la base des informations affichées.")

            Heading("5. Tarifs")
            Paragraph("L'application HCPilot est gratuite à télécharger. Une commission de 0,99 $ par transaction est prélevée via Stripe Connect sur les paiements traités. Aucun autre frais.")

            Heading("6. Résiliation")
            Paragraph("Vous pouvez résilier votre compte à tout moment depuis Profil → Paramètres. HCPilot peut résilier votre accès en cas de violation des présentes conditions, après notification raisonnable.")

            Heading("7. Droit applicable")
            Paragraph("Les présentes conditions sont régies par les lois de l'État de Californie, USA. Tout litige sera soumis aux tribunaux compétents de San Francisco.")
        }
    }
}

// MARK: - Building blocks

private struct DocumentScroll<Content: View>: View {
    let title: String
    let updated: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.title2).fontWeight(.bold)
                Text("Dernière mise à jour : \(updated)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider().padding(.vertical, 4)
                content()
                Spacer(minLength: 24)
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Heading: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.headline)
            .padding(.top, 8)
    }
}

private struct Paragraph: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(.init(text))  // markdown inline (gras avec **)
            .font(.body)
            .foregroundStyle(.primary)
    }
}

private struct Bullet: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").bold()
            Text(.init(text))
        }
        .font(.body)
    }
}
