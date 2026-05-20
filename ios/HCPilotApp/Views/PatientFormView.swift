import SwiftUI

/// Formulaire patient — utilisé en création (mode `.create`) ou édition (`.edit`).
/// En mode édition, envoie un PATCH-like (champs inchangés non re-écrits côté backend).
struct PatientFormView: View {
    enum Mode {
        case create
        case edit(Patient)
    }

    let mode: Mode
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var dateOfBirth: String = ""
    @State private var gender: String = ""
    @State private var medicalHistory: String = ""
    @State private var allergies: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    private let genders = ["", "M", "F"]

    private var title: String {
        switch mode {
        case .create: return "Nouveau client"
        case .edit:   return "Modifier client"
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Identité")) {
                    TextField("Prénom", text: $firstName)
                    TextField("Nom", text: $lastName)
                    Picker("Genre", selection: $gender) {
                        Text("—").tag("")
                        Text("Homme").tag("M")
                        Text("Femme").tag("F")
                    }
                    TextField("Date de naissance (YYYY-MM-DD)", text: $dateOfBirth)
                        .keyboardType(.numbersAndPunctuation)
                }

                Section(header: Text("Contact")) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Téléphone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Adresse", text: $address, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section(header: Text("Médical")) {
                    TextField("Antécédents", text: $medicalHistory, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Allergies", text: $allergies, axis: .vertical)
                        .lineLimit(1...3)
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }
                if let info = infoMessage {
                    Section {
                        Text(info).foregroundColor(.blue).font(.caption)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { Task { await save() } }
                        .disabled(firstName.isEmpty || lastName.isEmpty || isSaving)
                }
            }
            .onAppear(perform: preload)
        }
    }

    private func preload() {
        if case .edit(let p) = mode {
            firstName = p.first_name
            lastName = p.last_name
            email = p.email ?? ""
            phone = p.phone ?? ""
            address = p.address ?? ""
            dateOfBirth = p.date_of_birth ?? ""
            gender = p.gender ?? ""
            medicalHistory = p.medical_history ?? ""
            allergies = p.allergies ?? ""
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        infoMessage = nil
        defer { isSaving = false }

        do {
            switch mode {
            case .create:
                let now = ISO8601DateFormatter().string(from: Date())
                let newPatient = Patient(
                    id: UUID().uuidString,
                    first_name: firstName,
                    last_name: lastName,
                    email: email.isEmpty ? nil : email,
                    phone: phone.isEmpty ? nil : phone,
                    address: address.isEmpty ? nil : address,
                    latitude: nil,
                    longitude: nil,
                    date_of_birth: dateOfBirth.isEmpty ? nil : dateOfBirth,
                    gender: gender.isEmpty ? nil : gender,
                    medical_history: medicalHistory.isEmpty ? nil : medicalHistory,
                    allergies: allergies.isEmpty ? nil : allergies,
                    archived_at: nil,
                    created_at: now,
                    updated_at: nil
                )
                _ = try await APIService.shared.createPatient(patient: newPatient)
                onSaved()
                dismiss()

            case .edit(let p):
                let patch = APIService.PatientPatch(
                    first_name: changed(firstName, p.first_name),
                    last_name: changed(lastName, p.last_name),
                    email: changed(email, p.email),
                    phone: changed(phone, p.phone),
                    date_of_birth: changed(dateOfBirth, p.date_of_birth),
                    gender: changed(gender, p.gender),
                    address: changed(address, p.address),
                    medical_history: changed(medicalHistory, p.medical_history),
                    allergies: changed(allergies, p.allergies)
                )
                let result = try await APIService.shared.updatePatient(id: p.id, patch: patch)
                if let n = result.synced_future_visits, n > 0 {
                    infoMessage = "\(n) visite\(n > 1 ? "s" : "") future\(n > 1 ? "s" : "") resynchronisée\(n > 1 ? "s" : "")."
                    // Petit délai pour que l'info soit lue avant le dismiss
                    try? await Task.sleep(nanoseconds: 700_000_000)
                }
                onSaved()
                dismiss()
            }
        } catch {
            errorMessage = "Erreur : \(error.localizedDescription)"
        }
    }

    /// Renvoie la nouvelle valeur si elle diffère de l'originale, sinon nil
    /// (= ne pas envoyer le champ au backend pour préserver la valeur existante).
    private func changed(_ new: String, _ old: String?) -> String? {
        let trimmed = new
        if trimmed == (old ?? "") { return nil }
        return trimmed
    }
}
