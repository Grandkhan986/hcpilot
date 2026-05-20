import SwiftUI

/// Formulaire client — création ou édition. Aligné sur le brief schema :
/// adresse splittée en 5 champs, allergies/medications/medical_conditions en arrays.
struct ClientFormView: View {
    enum Mode {
        case create
        case edit(Client)
    }

    let mode: Mode
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    // Identité
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var dateOfBirth: String = ""
    @State private var gender: String = ""
    // Adresse splittée
    @State private var addressLine1: String = ""
    @State private var addressLine2: String = ""
    @State private var city: String = ""
    @State private var stateCode: String = ""
    @State private var postalCode: String = ""
    @State private var accessNotes: String = ""
    // Médical (chaînes séparées par virgule — affichage simple, conversion array au save)
    @State private var allergiesStr: String = ""
    @State private var medicalConditionsStr: String = ""
    @State private var medicationsStr: String = ""
    // Contact d'urgence
    @State private var emergencyName: String = ""
    @State private var emergencyPhone: String = ""

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    private var title: String {
        switch mode {
        case .create: return "Nouveau client"
        case .edit:   return "Modifier client"
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Identité") {
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

                Section("Contact") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    TextField("Téléphone", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("Adresse") {
                    TextField("Adresse (ligne 1)", text: $addressLine1)
                    TextField("Adresse (ligne 2, optionnel)", text: $addressLine2)
                    TextField("Ville", text: $city)
                    HStack {
                        TextField("État (CA, TX, …)", text: $stateCode)
                            .autocapitalization(.allCharacters)
                        TextField("Code postal", text: $postalCode)
                            .keyboardType(.numberPad)
                    }
                    TextField("Code accès / étage / parking", text: $accessNotes, axis: .vertical)
                        .lineLimit(1...2)
                }

                Section {
                    Text("Séparez les entrées par une virgule.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Allergies", text: $allergiesStr, axis: .vertical).lineLimit(1...3)
                    TextField("Antécédents médicaux", text: $medicalConditionsStr, axis: .vertical).lineLimit(1...3)
                    TextField("Médications en cours", text: $medicationsStr, axis: .vertical).lineLimit(1...3)
                } header: { Text("Médical") }

                Section("Contact d'urgence") {
                    TextField("Nom", text: $emergencyName)
                    TextField("Téléphone", text: $emergencyPhone)
                        .keyboardType(.phonePad)
                }

                if let error = errorMessage {
                    Section { Text(error).foregroundColor(.red).font(.caption) }
                }
                if let info = infoMessage {
                    Section { Text(info).foregroundColor(.blue).font(.caption) }
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
        if case .edit(let c) = mode {
            firstName = c.first_name
            lastName = c.last_name
            email = c.email ?? ""
            phone = c.phone ?? ""
            dateOfBirth = c.date_of_birth ?? ""
            gender = c.gender ?? ""
            addressLine1 = c.address_line1 ?? ""
            addressLine2 = c.address_line2 ?? ""
            city = c.city ?? ""
            stateCode = c.state_code ?? ""
            postalCode = c.postal_code ?? ""
            accessNotes = c.access_notes ?? ""
            allergiesStr = c.allergies.joined(separator: ", ")
            medicalConditionsStr = c.medical_conditions.joined(separator: ", ")
            medicationsStr = c.medications.joined(separator: ", ")
            emergencyName = c.emergency_contact_name ?? ""
            emergencyPhone = c.emergency_contact_phone ?? ""
        }
    }

    /// Split "Pénicilline, Iode" → ["Pénicilline", "Iode"]
    private func splitCSV(_ s: String) -> [String] {
        s.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        infoMessage = nil
        defer { isSaving = false }

        do {
            switch mode {
            case .create:
                let now = Date()
                let newClient = Client(
                    id: UUID().uuidString,
                    nurse_id: "",  // serveur remplit depuis le JWT
                    first_name: firstName,
                    last_name: lastName,
                    email: email.isEmpty ? nil : email,
                    phone: phone.isEmpty ? nil : phone,
                    date_of_birth: dateOfBirth.isEmpty ? nil : dateOfBirth,
                    gender: gender.isEmpty ? nil : gender,
                    address_line1: addressLine1.isEmpty ? nil : addressLine1,
                    address_line2: addressLine2.isEmpty ? nil : addressLine2,
                    city: city.isEmpty ? nil : city,
                    state_code: stateCode.isEmpty ? nil : stateCode,
                    postal_code: postalCode.isEmpty ? nil : postalCode,
                    access_notes: accessNotes.isEmpty ? nil : accessNotes,
                    latitude: nil,
                    longitude: nil,
                    allergies: splitCSV(allergiesStr),
                    medical_conditions: splitCSV(medicalConditionsStr),
                    medications: splitCSV(medicationsStr),
                    emergency_contact_name: emergencyName.isEmpty ? nil : emergencyName,
                    emergency_contact_phone: emergencyPhone.isEmpty ? nil : emergencyPhone,
                    id_document_path: nil,
                    archived_at: nil,
                    created_at: now,
                    updated_at: nil
                )
                _ = try await APIService.shared.createClient(client: newClient)
                onSaved()
                dismiss()

            case .edit(let c):
                let patch = APIService.ClientPatch(
                    first_name: changed(firstName, c.first_name),
                    last_name: changed(lastName, c.last_name),
                    email: changed(email, c.email),
                    phone: changed(phone, c.phone),
                    date_of_birth: changed(dateOfBirth, c.date_of_birth),
                    gender: changed(gender, c.gender),
                    address_line1: changed(addressLine1, c.address_line1),
                    address_line2: changed(addressLine2, c.address_line2),
                    city: changed(city, c.city),
                    state_code: changed(stateCode, c.state_code),
                    postal_code: changed(postalCode, c.postal_code),
                    access_notes: changed(accessNotes, c.access_notes),
                    allergies: changedArray(splitCSV(allergiesStr), c.allergies),
                    medical_conditions: changedArray(splitCSV(medicalConditionsStr), c.medical_conditions),
                    medications: changedArray(splitCSV(medicationsStr), c.medications),
                    emergency_contact_name: changed(emergencyName, c.emergency_contact_name),
                    emergency_contact_phone: changed(emergencyPhone, c.emergency_contact_phone)
                )
                let result = try await APIService.shared.updateClient(id: c.id, patch: patch)
                if let n = result.synced_future_sessions, n > 0 {
                    infoMessage = "\(n) session\(n > 1 ? "s" : "") future\(n > 1 ? "s" : "") resynchronisée\(n > 1 ? "s" : "")."
                    try? await Task.sleep(nanoseconds: 700_000_000)
                }
                onSaved()
                dismiss()
            }
        } catch {
            errorMessage = "Erreur : \(error.localizedDescription)"
        }
    }

    /// Nouvelle valeur si différente, sinon nil (PATCH-like).
    private func changed(_ new: String, _ old: String?) -> String? {
        if new == (old ?? "") { return nil }
        return new
    }

    private func changedArray(_ new: [String], _ old: [String]) -> [String]? {
        if new == old { return nil }
        return new
    }
}
