import SwiftUI

/// H-104 — Édition d'un Medical Director existant.
///
/// Actions :
/// - Modification des champs (nom, email, licence, état, dates, audit freq)
/// - "Renouveler le contrat" : raccourci qui propose contractEndDate + 12 mois
/// - "Désactiver ce MD" : soft delete (is_active=false) avec confirmation,
///   alerte renforcée si c'est le dernier MD actif
/// - "Ajouter un nouveau MD" : navigation vers SetupWizardView (étape MD)
///
/// Accédé depuis ComplianceDashboardView → carte MD → "Modifier".
struct MedicalDirectorEditView: View {
    let mdId: String
    let isLastActiveMD: Bool
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: MedicalDirectorEditViewModel
    @State private var showDeactivateConfirm = false

    init(md: MedicalDirectorInfo, isLastActiveMD: Bool, onSaved: @escaping () -> Void) {
        self.mdId = md.id
        self.isLastActiveMD = isLastActiveMD
        self.onSaved = onSaved
        _vm = StateObject(wrappedValue: MedicalDirectorEditViewModel(md: md))
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Identité") {
                    TextField("Prénom", text: $vm.firstName)
                        .accessibilityIdentifier("md.edit.firstName")
                    TextField("Nom", text: $vm.lastName)
                        .accessibilityIdentifier("md.edit.lastName")
                    TextField("Email", text: $vm.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .accessibilityIdentifier("md.edit.email")
                }

                Section("Licence") {
                    TextField("Numéro de licence", text: $vm.licenseNumber)
                        .autocapitalization(.allCharacters)
                        .accessibilityIdentifier("md.edit.licenseNumber")
                    Picker("État", selection: $vm.stateCode) {
                        ForEach(USStates.codes, id: \.self) { Text($0).tag($0) }
                    }
                    .accessibilityIdentifier("md.edit.stateCode")
                }

                Section {
                    DatePicker("Début", selection: $vm.contractStart, displayedComponents: .date)
                        .accessibilityIdentifier("md.edit.contractStart")
                    DatePicker(
                        "Fin",
                        selection: $vm.contractEnd,
                        in: vm.contractStart...,
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("md.edit.contractEnd")
                    Button {
                        vm.renewContract()
                    } label: {
                        Label("Renouveler le contrat (+12 mois)", systemImage: "arrow.clockwise")
                            .font(.subheadline)
                    }
                    .accessibilityIdentifier("md.edit.renewContract")
                } header: {
                    Text("Contrat")
                } footer: {
                    Text("Le renouvellement avance la date de fin de 12 mois à partir de la fin actuelle.")
                        .font(.caption2)
                }

                Section("Audit") {
                    Stepper("Audit tous les \(vm.auditFrequencyDays) j", value: $vm.auditFrequencyDays, in: 7...90, step: 1)
                        .accessibilityIdentifier("md.edit.auditFrequency")
                    DatePicker(
                        "Prochain audit",
                        selection: Binding(
                            get: { vm.nextAuditDate ?? Date() },
                            set: { vm.nextAuditDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("md.edit.nextAudit")
                }

                if let err = vm.errorMessage {
                    Section { Text(err).font(.caption).foregroundStyle(.red) }
                }

                Section {
                    Button(role: .destructive) {
                        showDeactivateConfirm = true
                    } label: {
                        Label("Désactiver ce MD", systemImage: "person.slash")
                    }
                    .accessibilityIdentifier("md.edit.deactivate")
                }
            }
            .navigationTitle("Modifier MD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .accessibilityIdentifier("md.edit.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Task {
                            await vm.save()
                            if vm.errorMessage == nil {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                    .disabled(!vm.isValid || vm.isSaving)
                    .accessibilityIdentifier("md.edit.save")
                }
            }
            .confirmationDialog(
                isLastActiveMD
                    ? "Désactiver votre seul MD actif ?"
                    : "Désactiver ce MD ?",
                isPresented: $showDeactivateConfirm,
                titleVisibility: .visible
            ) {
                Button("Désactiver", role: .destructive) {
                    Task {
                        await vm.deactivate()
                        if vm.errorMessage == nil {
                            onSaved()
                            dismiss()
                        }
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                if isLastActiveMD {
                    Text("⚠️ Vous n'aurez plus de Medical Director valide. Votre conformité passera en statut critique et vous ne pourrez plus créer de nouvelles standing orders.")
                } else {
                    Text("Le MD sera marqué inactif. Ses standing orders existants restent valides jusqu'à expiration.")
                }
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class MedicalDirectorEditViewModel: ObservableObject {
    @Published var firstName: String
    @Published var lastName: String
    @Published var email: String
    @Published var licenseNumber: String
    @Published var stateCode: String
    @Published var contractStart: Date
    @Published var contractEnd: Date
    @Published var auditFrequencyDays: Int
    @Published var nextAuditDate: Date?
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let mdId: String
    private let api = APIService.shared

    init(md: MedicalDirectorInfo) {
        self.mdId = md.id
        self.firstName = md.firstName
        self.lastName = md.lastName
        self.email = md.email
        self.licenseNumber = md.licenseNumber
        self.stateCode = md.stateCode
        self.contractStart = md.contractStartDate
        self.contractEnd = md.contractEndDate ?? Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        self.auditFrequencyDays = md.auditFrequencyDays
        self.nextAuditDate = md.nextAuditDate
    }

    var isValid: Bool {
        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard !lastName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard Validators.isValidEmail(email) else { return false }
        guard Validators.isValidLicenseNumber(licenseNumber) else { return false }
        guard Validators.isValidStateCode(stateCode) else { return false }
        guard contractEnd >= contractStart else { return false }
        return true
    }

    func renewContract() {
        // H-104 : raccourci renouvellement +12 mois sur la date de fin courante.
        if let next = Calendar.current.date(byAdding: .year, value: 1, to: contractEnd) {
            contractEnd = next
        }
    }

    private func ymd(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: d)
    }

    func save() async {
        guard isValid else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let payload = APIService.UpdateMedicalDirectorRequest(
            firstName: firstName,
            lastName: lastName,
            email: email,
            licenseNumber: licenseNumber,
            stateCode: stateCode,
            contractStartDate: ymd(contractStart),
            contractEndDate: ymd(contractEnd),
            auditFrequencyDays: auditFrequencyDays,
            nextAuditDate: nextAuditDate.map(ymd),
            isActive: nil
        )
        do {
            _ = try await api.updateMedicalDirector(id: mdId, payload: payload)
        } catch {
            errorMessage = "Erreur : \(error.localizedDescription)"
        }
    }

    func deactivate() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let payload = APIService.UpdateMedicalDirectorRequest(isActive: false)
        do {
            _ = try await api.updateMedicalDirector(id: mdId, payload: payload)
        } catch {
            errorMessage = "Erreur : \(error.localizedDescription)"
        }
    }
}
