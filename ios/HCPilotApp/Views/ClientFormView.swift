import SwiftUI

/// Formulaire client — création ou édition. Aligné sur le brief schema :
/// adresse splittée en 5 champs, allergies/medications/medicalConditions en arrays.
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
    // Médical — chips multi-select pour allergies/conditions (brief §création
    // client), saisie libre CSV pour médications (trop varié pour prédéfinir).
    @State private var allergies: [String] = []
    @State private var medicalConditions: [String] = []
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

                Section("Médical") {
                    ChipMultiSelect(
                        title: "Allergies",
                        predefined: ChipPresets.allergies,
                        selection: $allergies,
                        placeholder: "Autre allergie…"
                    )
                    ChipMultiSelect(
                        title: "Antécédents médicaux",
                        predefined: ChipPresets.medicalConditions,
                        selection: $medicalConditions,
                        placeholder: "Autre antécédent…"
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Médications en cours").font(.subheadline).fontWeight(.semibold)
                        Text("Séparez les entrées par une virgule.").font(.caption2).foregroundStyle(.secondary)
                        TextField("Ex: Metformine 1000mg, Lisinopril 10mg", text: $medicationsStr, axis: .vertical)
                            .lineLimit(1...3)
                    }
                }

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
            firstName = c.firstName
            lastName = c.lastName
            email = c.email ?? ""
            phone = c.phone ?? ""
            dateOfBirth = c.dateOfBirth ?? ""
            gender = c.gender ?? ""
            addressLine1 = c.addressLine1 ?? ""
            addressLine2 = c.addressLine2 ?? ""
            city = c.city ?? ""
            stateCode = c.stateCode ?? ""
            postalCode = c.postalCode ?? ""
            accessNotes = c.accessNotes ?? ""
            allergies = c.allergies
            medicalConditions = c.medicalConditions
            medicationsStr = c.medications.joined(separator: ", ")
            emergencyName = c.emergencyContactName ?? ""
            emergencyPhone = c.emergencyContactPhone ?? ""
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
                    nurseId: "",  // serveur remplit depuis le JWT
                    firstName: firstName,
                    lastName: lastName,
                    email: email.isEmpty ? nil : email,
                    phone: phone.isEmpty ? nil : phone,
                    dateOfBirth: dateOfBirth.isEmpty ? nil : dateOfBirth,
                    gender: gender.isEmpty ? nil : gender,
                    addressLine1: addressLine1.isEmpty ? nil : addressLine1,
                    addressLine2: addressLine2.isEmpty ? nil : addressLine2,
                    city: city.isEmpty ? nil : city,
                    stateCode: stateCode.isEmpty ? nil : stateCode,
                    postalCode: postalCode.isEmpty ? nil : postalCode,
                    accessNotes: accessNotes.isEmpty ? nil : accessNotes,
                    latitude: nil,
                    longitude: nil,
                    allergies: allergies,
                    medicalConditions: medicalConditions,
                    medications: splitCSV(medicationsStr),
                    emergencyContactName: emergencyName.isEmpty ? nil : emergencyName,
                    emergencyContactPhone: emergencyPhone.isEmpty ? nil : emergencyPhone,
                    idDocumentPath: nil,
                    archivedAt: nil,
                    createdAt: now,
                    updatedAt: nil
                )
                _ = try await APIService.shared.createClient(client: newClient)
                onSaved()
                dismiss()

            case .edit(let c):
                let patch = APIService.ClientPatch(
                    firstName: changed(firstName, c.firstName),
                    lastName: changed(lastName, c.lastName),
                    email: changed(email, c.email),
                    phone: changed(phone, c.phone),
                    dateOfBirth: changed(dateOfBirth, c.dateOfBirth),
                    gender: changed(gender, c.gender),
                    addressLine1: changed(addressLine1, c.addressLine1),
                    addressLine2: changed(addressLine2, c.addressLine2),
                    city: changed(city, c.city),
                    stateCode: changed(stateCode, c.stateCode),
                    postalCode: changed(postalCode, c.postalCode),
                    accessNotes: changed(accessNotes, c.accessNotes),
                    allergies: changedArray(allergies, c.allergies),
                    medicalConditions: changedArray(medicalConditions, c.medicalConditions),
                    medications: changedArray(splitCSV(medicationsStr), c.medications),
                    emergencyContactName: changed(emergencyName, c.emergencyContactName),
                    emergencyContactPhone: changed(emergencyPhone, c.emergencyContactPhone)
                )
                let result = try await APIService.shared.updateClient(id: c.id, patch: patch)
                if let n = result.syncedFutureSessions, n > 0 {
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
