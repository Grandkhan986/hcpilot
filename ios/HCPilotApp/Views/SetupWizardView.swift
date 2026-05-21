import SwiftUI

/// Wizard d'onboarding Sprint 1 du brief HCPilot. 3 étapes guidées :
/// 1. Pratique & licence  (PUT /users/me/practice)
/// 2. Medical Director    (POST /compliance/medical_directors)
/// 3. Premier standing order (POST /compliance/standingOrders depuis template)
/// + écran de bienvenue final.
struct SetupWizardView: View {
    var onCompleted: () -> Void

    @StateObject private var vm = SetupWizardViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressBar(current: vm.step, total: 4)
                    .padding(.horizontal)
                    .padding(.top, 12)

                TabView(selection: $vm.step) {
                    LicenseStep(vm: vm).tag(0)
                    MedicalDirectorStep(vm: vm).tag(1)
                    StandingOrderStep(vm: vm).tag(2)
                    DoneStep(vm: vm, onClose: {
                        onCompleted()
                        dismiss()
                    }).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: vm.step)
            }
            .navigationTitle("Configuration de la pratique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
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

// MARK: - Step 1 : License

private struct LicenseStep: View {
    @ObservedObject var vm: SetupWizardViewModel

    private let licenseTypes = ["RN", "NP", "LPN", "MD", "PA"]
    private let states = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "DC",
    ]

    var body: some View {
        Form {
            Section {
                Text("Votre identité professionnelle et la licence qui vous autorise à exercer dans votre État.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Identité") {
                TextField("Prénom", text: $vm.firstName)
                TextField("Nom", text: $vm.lastName)
                TextField("Téléphone", text: $vm.phone)
                    .keyboardType(.phonePad)
                TextField("Nom de la pratique", text: $vm.practiceName)
            }

            Section("Licence") {
                Picker("Type", selection: $vm.licenseType) {
                    ForEach(licenseTypes, id: \.self) { Text($0).tag($0) }
                }
                Picker("État d'exercice", selection: $vm.stateCode) {
                    ForEach(states, id: \.self) { Text($0).tag($0) }
                }
                TextField("Numéro de licence", text: $vm.licenseNumber)
                    .autocapitalization(.allCharacters)
                DatePicker("Expiration", selection: $vm.licenseExpirationDate, displayedComponents: .date)
            }

            Section("NPI (optionnel)") {
                TextField("National Provider Identifier", text: $vm.npiNumber)
                    .keyboardType(.numberPad)
            }

            if let err = vm.errorMessage {
                Section { Text(err).foregroundStyle(.red).font(.caption) }
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
            }
        }
    }
}

// MARK: - Step 2 : Medical Director

private struct MedicalDirectorStep: View {
    @ObservedObject var vm: SetupWizardViewModel

    var body: some View {
        Form {
            Section {
                Text("Le Medical Director supervise votre pratique. Son nom doit figurer sur les standing orders qui autorisent l'administration IV.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Identité") {
                TextField("Prénom", text: $vm.mdFirstName)
                TextField("Nom", text: $vm.mdLastName)
                TextField("Email", text: $vm.mdEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            }

            Section("Licence MD") {
                TextField("Numéro de licence", text: $vm.mdLicenseNumber)
                    .autocapitalization(.allCharacters)
                TextField("État", text: $vm.mdStateCode)
                    .autocapitalization(.allCharacters)
            }

            Section("Contrat") {
                DatePicker("Début", selection: $vm.mdContractStart, displayedComponents: .date)
                DatePicker("Fin", selection: $vm.mdContractEnd, displayedComponents: .date)
                Stepper("Audit tous les \(vm.mdAuditFrequencyDays) j", value: $vm.mdAuditFrequencyDays, in: 7...90, step: 1)
            }

            if let err = vm.errorMessage {
                Section { Text(err).foregroundStyle(.red).font(.caption) }
            }

            Section {
                HStack {
                    Button("Retour") { vm.step = 0 }
                        .buttonStyle(.bordered)
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
                }
                .listRowBackground(Color.clear)
            }
        }
    }
}

// MARK: - Step 3 : First Standing Order

private struct StandingOrderStep: View {
    @ObservedObject var vm: SetupWizardViewModel

    private let templates = ["Myers Cocktail", "NAD+ 250mg", "NAD+ 500mg"]

    var body: some View {
        Form {
            Section {
                Text("Choisissez la première formulation que votre Medical Director vous a autorisée. Vous pourrez en ajouter d'autres plus tard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                }
            }

            Section("Validité") {
                DatePicker("Expiration", selection: $vm.standingOrderExpiresAt, displayedComponents: .date)
            }

            if let err = vm.errorMessage {
                Section { Text(err).foregroundStyle(.red).font(.caption) }
            }

            Section {
                HStack {
                    Button("Retour") { vm.step = 1 }
                        .buttonStyle(.bordered)
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
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class SetupWizardViewModel: ObservableObject {
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

    // Step 3 — Standing order
    @Published var standingOrderFormulation = "Myers Cocktail"
    @Published var standingOrderExpiresAt: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    private let api = APIService.shared

    var licenseStepValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !licenseNumber.isEmpty
    }

    var mdStepValid: Bool {
        !mdFirstName.isEmpty && !mdLastName.isEmpty
            && mdEmail.contains("@") && !mdLicenseNumber.isEmpty
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
            step = 1
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
            step = 2
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
            step = 3
        } catch {
            errorMessage = "Erreur standing order : \(error.localizedDescription)"
        }
    }
}
