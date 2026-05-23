import SwiftUI

/// Wizard d'onboarding Sprint 1 du brief HCPilot — refondu suite à l'audit
/// parcours 1 (`audit-parcours/01-onboarding.md`).
///
/// 5 étapes guidées :
/// 0. Welcome (checklist préparatoire + temps estimé)
/// 1. Pratique & licence  (PUT /users/me/practice)
/// 2. Medical Director    (POST /compliance/medical_directors)
/// 3. Premier standing order (POST /compliance/standingOrders depuis template)
/// 4. Écran de bienvenue final.
struct SetupWizardView: View {
    var onCompleted: () -> Void

    @StateObject private var vm = SetupWizardViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDismissConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressBar(current: vm.step, total: SetupWizardViewModel.totalSteps)
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .accessibilityIdentifier("onboarding.progress")

                TabView(selection: $vm.step) {
                    WelcomeStep(vm: vm).tag(0)
                    LicenseStep(vm: vm).tag(1)
                    MedicalDirectorStep(vm: vm).tag(2)
                    StandingOrderStep(vm: vm).tag(3)
                    DoneStep(vm: vm, onClose: {
                        onCompleted()
                        dismiss()
                    }).tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: vm.step)
            }
            .navigationTitle("Configuration de la pratique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        // Audit C-03 : confirm si données partielles non envoyées.
                        if vm.hasUnsavedWork {
                            showDismissConfirm = true
                        } else {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("onboarding.close")
                }
            }
            .confirmationDialog(
                "Quitter la configuration ?",
                isPresented: $showDismissConfirm,
                titleVisibility: .visible
            ) {
                Button("Quitter, j'y reviendrai", role: .destructive) { dismiss() }
                Button("Continuer la configuration", role: .cancel) {}
            } message: {
                Text("Vos saisies non envoyées seront perdues. Vous pourrez reprendre depuis Profil → Configuration.")
            }
            .interactiveDismissDisabled(vm.hasUnsavedWork)
        }
    }
}

// MARK: - Liste partagée des États US

enum USStates {
    static let codes: [String] = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC",
    ]
}

// MARK: - Progress bar

private struct ProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    Capsule()
                        .fill(i <= current ? Color.blue : Color.gray.opacity(0.25))
                        .frame(height: 4)
                }
            }
            Text("Étape \(current + 1) sur \(total)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Step 0 : Welcome (audit C-02)

private struct WelcomeStep: View {
    @ObservedObject var vm: SetupWizardViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                    Text("Bienvenue dans HCPilot")
                        .font(.title2).fontWeight(.bold)
                    Text("Configurons votre pratique en 3 étapes — environ 5 minutes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Ce dont vous aurez besoin")
                        .font(.headline)
                    checklist(
                        "Votre licence active (type, État, numéro, date d'expiration)",
                        systemImage: "person.crop.rectangle.badge.checkmark"
                    )
                    checklist(
                        "Le nom, l'email et le numéro de licence de votre Medical Director",
                        systemImage: "stethoscope"
                    )
                    checklist(
                        "Les dates de début et de fin de votre contrat MD",
                        systemImage: "calendar"
                    )
                    checklist(
                        "La première formulation IV que votre MD vous a autorisée",
                        systemImage: "doc.text.fill"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("À propos de la conformité")
                        .font(.headline)
                    Text("Aux USA, l'administration IV par une nurse exige un standing order signé par un Medical Director. HCPilot stocke ces documents de manière HIPAA-conforme et vous alerte avant expiration.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    vm.step = 1
                } label: {
                    Text("Commencer la configuration")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityIdentifier("onboarding.welcome.start")
                .padding(.top, 8)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func checklist(_ text: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.blue)
                .frame(width: 24, alignment: .center)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Step 1 : License (audit H-05/H-08)

private struct LicenseStep: View {
    @ObservedObject var vm: SetupWizardViewModel

    private let licenseTypes = ["RN", "NP", "LPN", "MD", "PA"]

    var body: some View {
        Form {
            Section {
                Text("Votre identité professionnelle et la licence qui vous autorise à exercer dans votre État.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Identité") {
                TextField("Prénom", text: $vm.firstName)
                    .accessibilityIdentifier("onboarding.firstName")
                TextField("Nom", text: $vm.lastName)
                    .accessibilityIdentifier("onboarding.lastName")
                TextField("Téléphone", text: $vm.phone)
                    .keyboardType(.phonePad)
                    .accessibilityIdentifier("onboarding.phone")
                TextField("Nom de la pratique", text: $vm.practiceName)
                    .accessibilityIdentifier("onboarding.practiceName")
            }

            Section("Licence") {
                Picker("Type", selection: $vm.licenseType) {
                    ForEach(licenseTypes, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityIdentifier("onboarding.licenseType")
                Picker("État d'exercice", selection: $vm.stateCode) {
                    ForEach(USStates.codes, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityIdentifier("onboarding.stateCode")
                TextField("Numéro de licence", text: $vm.licenseNumber)
                    .autocapitalization(.allCharacters)
                    .accessibilityIdentifier("onboarding.licenseNumber")
                DatePicker("Expiration", selection: $vm.licenseExpirationDate, displayedComponents: .date)
                    .accessibilityIdentifier("onboarding.licenseExpiration")
            }

            Section {
                TextField("National Provider Identifier", text: $vm.npiNumber)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("onboarding.npi")
            } header: {
                Text("NPI (optionnel)")
            } footer: {
                // Audit H-10 : aide inline sur pourquoi NPI est optionnel.
                Text("Utile pour facturer une assurance. Vous pouvez l'ajouter plus tard si vous êtes en private pay uniquement.")
                    .font(.caption2)
            }

            if let err = vm.errorMessage {
                Section {
                    Text(err).foregroundStyle(.red).font(.caption)
                        .accessibilityIdentifier("onboarding.error")
                }
            }

            Section {
                Button {
                    Task { await vm.submitLicense() }
                } label: {
                    HStack {
                        Spacer()
                        if vm.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Continuer").fontWeight(.semibold)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .foregroundStyle(.white)
                    .background(vm.licenseStepValid ? Color.blue : Color.gray)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .disabled(!vm.licenseStepValid || vm.isSubmitting)
                .accessibilityIdentifier("onboarding.continue")
            }
        }
    }
}

// MARK: - Step 2 : Medical Director (audit C-04 / H-06 / H-07 / H-09)

private struct MedicalDirectorStep: View {
    @ObservedObject var vm: SetupWizardViewModel

    var body: some View {
        Form {
            Section {
                // Audit C-04 : explication métier pour les utilisatrices débutantes.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Le Medical Director (MD) est le médecin qui supervise votre pratique. Son nom doit figurer sur les standing orders qui autorisent l'administration IV.")
                        .font(.caption)
                    Text("Aux USA, chaque État réglemente la nature de cette supervision. Saisissez les informations de votre MD telles qu'elles figurent sur votre contrat.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Identité") {
                TextField("Prénom", text: $vm.mdFirstName)
                    .accessibilityIdentifier("onboarding.md.firstName")
                TextField("Nom", text: $vm.mdLastName)
                    .accessibilityIdentifier("onboarding.md.lastName")
                TextField("Email", text: $vm.mdEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .accessibilityIdentifier("onboarding.md.email")
            }

            Section("Licence MD") {
                TextField("Numéro de licence", text: $vm.mdLicenseNumber)
                    .autocapitalization(.allCharacters)
                    .accessibilityIdentifier("onboarding.md.licenseNumber")
                // Audit H-07 : passer mdStateCode en Picker pour cohérence avec stateCode.
                Picker("État", selection: $vm.mdStateCode) {
                    ForEach(USStates.codes, id: \.self) { Text($0).tag($0) }
                }
                .accessibilityIdentifier("onboarding.md.stateCode")
            }

            Section {
                DatePicker("Début", selection: $vm.mdContractStart, displayedComponents: .date)
                    .accessibilityIdentifier("onboarding.md.contractStart")
                DatePicker(
                    "Fin",
                    selection: $vm.mdContractEnd,
                    in: vm.mdContractStart...,
                    displayedComponents: .date
                )
                .accessibilityIdentifier("onboarding.md.contractEnd")
                Stepper("Audit tous les \(vm.mdAuditFrequencyDays) j", value: $vm.mdAuditFrequencyDays, in: 7...90, step: 1)
                    .accessibilityIdentifier("onboarding.md.auditFrequency")
            } header: {
                Text("Contrat")
            } footer: {
                // Audit H-09 : help text sur l'audit frequency.
                Text("Fréquence des entretiens d'audit avec votre MD. La convention est de 30 jours pour les nouvelles nurses.")
                    .font(.caption2)
            }

            if let err = vm.errorMessage {
                Section {
                    Text(err).foregroundStyle(.red).font(.caption)
                        .accessibilityIdentifier("onboarding.md.error")
                }
            }

            Section {
                HStack {
                    Button("Retour") { vm.step = 1 }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("onboarding.md.back")
                    Spacer()
                    Button {
                        Task { await vm.submitMedicalDirector() }
                    } label: {
                        if vm.isSubmitting {
                            ProgressView()
                        } else {
                            Text("Continuer").fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.mdStepValid || vm.isSubmitting)
                    .accessibilityIdentifier("onboarding.md.continue")
                }
                .listRowBackground(Color.clear)
            }
        }
    }
}

// MARK: - Step 3 : First Standing Order (audit C-04)

private struct StandingOrderStep: View {
    @ObservedObject var vm: SetupWizardViewModel

    private let templates = ["Myers Cocktail", "NAD+ 250mg", "NAD+ 500mg"]

    var body: some View {
        Form {
            Section {
                // Audit C-04 : explication métier.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Un standing order est l'autorisation signée par votre MD pour administrer une formulation IV donnée.")
                        .font(.caption)
                    Text("Choisissez la première formulation autorisée — vous pourrez en ajouter d'autres ensuite depuis l'onglet Conformité.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Formulation") {
                ForEach(templates, id: \.self) { name in
                    Button {
                        vm.standingOrderFormulation = name
                    } label: {
                        HStack {
                            Text(name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if vm.standingOrderFormulation == name {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .accessibilityIdentifier("onboarding.so.template.\(name)")
                }
            }

            Section("Validité") {
                DatePicker(
                    "Expiration",
                    selection: $vm.standingOrderExpiresAt,
                    in: Date()...,
                    displayedComponents: .date
                )
                .accessibilityIdentifier("onboarding.so.expiration")
            }

            if let err = vm.errorMessage {
                Section {
                    Text(err).foregroundStyle(.red).font(.caption)
                        .accessibilityIdentifier("onboarding.so.error")
                }
            }

            Section {
                HStack {
                    Button("Retour") { vm.step = 2 }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("onboarding.so.back")
                    Spacer()
                    Button {
                        Task { await vm.submitStandingOrder() }
                    } label: {
                        if vm.isSubmitting {
                            ProgressView()
                        } else {
                            Text("Continuer").fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.standingOrderFormulation.isEmpty || vm.isSubmitting)
                    .accessibilityIdentifier("onboarding.so.continue")
                }
                .listRowBackground(Color.clear)
            }
        }
    }
}

// MARK: - Step 4 : Done

private struct DoneStep: View {
    @ObservedObject var vm: SetupWizardViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Configuration terminée")
                .font(.title2).fontWeight(.bold)
                .accessibilityIdentifier("onboarding.done.title")
            VStack(alignment: .leading, spacing: 10) {
                Label("Licence \(vm.licenseType) · \(vm.stateCode) · expire le \(vm.formattedDate(vm.licenseExpirationDate))", systemImage: "person.crop.rectangle.badge.checkmark")
                Label("Medical Director : \(vm.mdFirstName) \(vm.mdLastName)", systemImage: "stethoscope")
                Label("Standing order : \(vm.standingOrderFormulation)", systemImage: "doc.text.fill")
            }
            .font(.subheadline)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Text("Vous êtes prêt(e) à créer votre première session IV.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
            Button(action: onClose) {
                Text("Terminer")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityIdentifier("onboarding.done.finish")
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class SetupWizardViewModel: ObservableObject {
    /// Total d'étapes (welcome + 3 actions + done).
    static let totalSteps = 5

    @Published var step: Int = 0
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    // Step 1 — License
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var phone = ""
    @Published var practiceName = ""
    @Published var licenseType = "RN"
    @Published var stateCode = "CA"
    @Published var licenseNumber = ""
    @Published var licenseExpirationDate: Date = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
    @Published var npiNumber = ""

    // Step 2 — MD
    @Published var mdFirstName = ""
    @Published var mdLastName = ""
    @Published var mdEmail = ""
    @Published var mdLicenseNumber = ""
    @Published var mdStateCode = "CA"
    @Published var mdContractStart: Date = Date()
    @Published var mdContractEnd: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @Published var mdAuditFrequencyDays: Int = 30
    @Published var createdMedicalDirectorId: String?
    /// Marqué `true` dès que la step 1 a été POSTée avec succès (sert au gate
    /// de confirmation à la fermeture du wizard).
    @Published var licenseStepCompleted = false
    @Published var mdStepCompleted = false

    // Step 3 — Standing order
    @Published var standingOrderFormulation = "Myers Cocktail"
    @Published var standingOrderExpiresAt: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    private let api = APIService.shared

    /// Audit H-05/H-06 : validations format pré-submit basées sur Validators.
    var licenseStepValid: Bool {
        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard !lastName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard Validators.isValidLicenseNumber(licenseNumber) else { return false }
        guard Validators.isValidStateCode(stateCode) else { return false }
        // Téléphone & NPI optionnels, mais s'ils sont remplis, ils doivent être valides.
        if !phone.isEmpty, !Validators.isValidPhoneUS(phone) { return false }
        if !npiNumber.isEmpty, !Validators.isValidNPI(npiNumber) { return false }
        return true
    }

    var mdStepValid: Bool {
        guard !mdFirstName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard !mdLastName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard Validators.isValidEmail(mdEmail) else { return false }
        guard Validators.isValidLicenseNumber(mdLicenseNumber) else { return false }
        guard Validators.isValidStateCode(mdStateCode) else { return false }
        // Audit H-06 : contractEnd > contractStart (le DatePicker borne déjà,
        // mais on garde un second check au cas où l'utilisateur revisiterait
        // les dates dans l'ordre inverse via une autre voie).
        guard mdContractEnd > mdContractStart else { return false }
        return true
    }

    /// Audit C-03 : true si l'utilisatrice a saisi quelque chose qui n'a pas
    /// encore été POSTé au backend → on doit prévenir avant de dismiss.
    /// La welcome step et la done step ne comptent pas.
    var hasUnsavedWork: Bool {
        switch step {
        case 1: // License en cours de saisie, pas encore validée
            return !licenseStepCompleted && (
                !firstName.isEmpty || !lastName.isEmpty || !licenseNumber.isEmpty
            )
        case 2: // MD en cours
            return !mdStepCompleted && (
                !mdFirstName.isEmpty || !mdLastName.isEmpty || !mdEmail.isEmpty || !mdLicenseNumber.isEmpty
            )
        case 3: // Standing order en cours
            // Si on est arrivé à la step 3, la step 2 est validée. Reste à
            // vérifier que la formulation n'est pas envoyée — ici on considère
            // que toute step 3 atteinte mais non validée mérite un confirm.
            return true
        default:
            return false
        }
    }

    func formattedDate(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateStyle = .medium
        return df.string(from: d)
    }

    private func ymd(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        return df.string(from: d)
    }

    func submitLicense() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        let payload = APIService.UpdatePracticeRequest(
            firstName: firstName,
            lastName: lastName,
            phone: phone.isEmpty ? nil : phone,
            stateCode: stateCode,
            licenseNumber: licenseNumber,
            licenseExpirationDate: ymd(licenseExpirationDate),
            licenseType: licenseType,
            practiceName: practiceName.isEmpty ? nil : practiceName,
            npiNumber: npiNumber.isEmpty ? nil : npiNumber
        )
        do {
            _ = try await api.updatePractice(payload)
            licenseStepCompleted = true
            step = 2
        } catch {
            errorMessage = "Erreur licence : \(error.localizedDescription)"
        }
    }

    func submitMedicalDirector() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        let payload = APIService.CreateMedicalDirectorRequest(
            firstName: mdFirstName,
            lastName: mdLastName,
            email: mdEmail,
            licenseNumber: mdLicenseNumber,
            stateCode: mdStateCode,
            contractStartDate: ymd(mdContractStart),
            contractEndDate: ymd(mdContractEnd),
            auditFrequencyDays: mdAuditFrequencyDays,
            nextAuditDate: nil
        )
        do {
            let md = try await api.createMedicalDirector(payload)
            createdMedicalDirectorId = md.id
            mdStepCompleted = true
            step = 3
        } catch {
            errorMessage = "Erreur MD : \(error.localizedDescription)"
        }
    }

    func submitStandingOrder() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        let payload = APIService.CreateStandingOrderRequest(
            formulationName: standingOrderFormulation,
            medicalDirectorId: createdMedicalDirectorId,
            expiresAt: ymd(standingOrderExpiresAt)
        )
        do {
            _ = try await api.createStandingOrder(payload)
            step = 4
        } catch {
            errorMessage = "Erreur standing order : \(error.localizedDescription)"
        }
    }
}
