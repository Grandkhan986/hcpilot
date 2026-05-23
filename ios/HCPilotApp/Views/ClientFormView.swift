import SwiftUI

/// Formulaire client — création ou édition. Aligné sur le brief schema :
/// adresse splittée en 5 champs, allergies/medications/medicalConditions en arrays.
///
/// Audit parcours 3 (`audit-parcours/03-client-creation.md`) :
/// - DOB en DatePicker (H-36)
/// - Validation email + phone US (H-37/H-38)
/// - Gender étendu (H-39)
/// - stateCode en Picker (H-40)
/// - accessibilityIdentifier (H-41)
/// - Confirm "Annuler" si dirty (H-42)
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
    @State private var dateOfBirth: Date? = nil
    @State private var gender: String = ""
    // Adresse splittée
    @State private var addressLine1: String = ""
    @State private var addressLine2: String = ""
    @State private var city: String = ""
    @State private var stateCode: String = "CA"
    @State private var postalCode: String = ""
    @State private var accessNotes: String = ""
    // Médical
    @State private var allergies: [String] = []
    @State private var medicalConditions: [String] = []
    // Fork A Lot 2 / M-44 : médications en chips (au lieu d'un CSV).
    @State private var medications: [String] = []
    // Contact d'urgence
    @State private var emergencyName: String = ""
    @State private var emergencyPhone: String = ""

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var showCancelConfirm = false

    private var title: String {
        switch mode {
        case .create: return "Nouveau client"
        case .edit:   return "Modifier client"
        }
    }

    /// Audit H-37/H-38 : un client peut laisser email/phone vides, mais si
    /// remplis, ils doivent être valides.
    private var emailIsValidOrEmpty: Bool {
        email.isEmpty || Validators.isValidEmail(email)
    }

    private var phoneIsValidOrEmpty: Bool {
        phone.isEmpty || Validators.isValidPhoneUS(phone)
    }

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && emailIsValidOrEmpty
            && phoneIsValidOrEmpty
            && !isSaving
    }

    /// Audit H-42 : true si la nurse a saisi quelque chose qui mérite un confirm
    /// avant fermeture sans save.
    private var isDirty: Bool {
        if case .edit = mode { return true }   // toute édition mérite un confirm
        return !firstName.isEmpty || !lastName.isEmpty || !email.isEmpty
            || !phone.isEmpty || dateOfBirth != nil || !addressLine1.isEmpty
            || !city.isEmpty || !postalCode.isEmpty || !accessNotes.isEmpty
            || !allergies.isEmpty || !medicalConditions.isEmpty
            || !medications.isEmpty || !emergencyName.isEmpty
            || !emergencyPhone.isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Identité") {
                    TextField("Prénom", text: $firstName)
                        .accessibilityIdentifier("client.firstName")
                    TextField("Nom", text: $lastName)
                        .accessibilityIdentifier("client.lastName")
                    Picker("Genre", selection: $gender) {
                        Text("—").tag("")
                        Text("Homme").tag("M")
                        Text("Femme").tag("F")
                        Text("Autre").tag("O")
                        Text("Non spécifié").tag("U")
                    }
                    .accessibilityIdentifier("client.gender")

                    DatePicker(
                        "Date de naissance",
                        selection: Binding(
                            get: { dateOfBirth ?? defaultDOB },
                            set: { dateOfBirth = $0 }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .accessibilityIdentifier("client.dateOfBirth")
                    if dateOfBirth == nil {
                        Button("Ajouter une date de naissance") {
                            dateOfBirth = defaultDOB
                        }
                        .font(.caption)
                        .accessibilityIdentifier("client.dateOfBirth.add")
                    }
                }

                Section {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .accessibilityIdentifier("client.email")
                    if !emailIsValidOrEmpty {
                        Text("Format email invalide.")
                            .font(.caption2).foregroundStyle(.red)
                    }
                    TextField("Téléphone", text: $phone)
                        .keyboardType(.phonePad)
                        .accessibilityIdentifier("client.phone")
                    if !phoneIsValidOrEmpty {
                        Text("Téléphone US attendu : 10 chiffres.")
                            .font(.caption2).foregroundStyle(.red)
                    }
                } header: {
                    Text("Contact")
                } footer: {
                    Text("Email et téléphone sont facultatifs.")
                        .font(.caption2)
                }

                Section("Adresse") {
                    // Fork A Lot 2 / M-43 : autocomplete Apple Maps natif.
                    // Remplit auto line1 / city / stateCode / postalCode au tap.
                    AddressAutocompleteField(
                        line1: $addressLine1,
                        city: $city,
                        stateCode: $stateCode,
                        postalCode: $postalCode
                    )
                    TextField("Adresse (ligne 2, optionnel)", text: $addressLine2)
                        .accessibilityIdentifier("client.addressLine2")
                    TextField("Ville", text: $city)
                        .accessibilityIdentifier("client.city")
                    HStack {
                        Picker("État", selection: $stateCode) {
                            ForEach(USStates.codes, id: \.self) { Text($0).tag($0) }
                        }
                        .accessibilityIdentifier("client.stateCode")
                        TextField("Code postal", text: $postalCode)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("client.postalCode")
                    }
                    TextField("Code accès / étage / parking", text: $accessNotes, axis: .vertical)
                        .lineLimit(1...2)
                        .accessibilityIdentifier("client.accessNotes")
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
                    // M-44 : médications en chips (saisie libre, pas de presets
                    // car trop variable d'une nurse à l'autre). Cohérent
                    // visuellement avec allergies / antécédents.
                    ChipMultiSelect(
                        title: "Médications en cours",
                        predefined: [],
                        selection: $medications,
                        placeholder: "Ex: Metformine 1000mg…"
                    )
                }

                Section("Contact d'urgence") {
                    TextField("Nom", text: $emergencyName)
                        .accessibilityIdentifier("client.emergencyName")
                    TextField("Téléphone", text: $emergencyPhone)
                        .keyboardType(.phonePad)
                        .accessibilityIdentifier("client.emergencyPhone")
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundColor(.red).font(.caption)
                            .accessibilityIdentifier("client.error")
                    }
                }
                if let info = infoMessage {
                    Section { Text(info).foregroundColor(.blue).font(.caption) }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        // Audit H-42 : confirm si dirty
                        if isDirty {
                            showCancelConfirm = true
                        } else {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("client.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { Task { await save() } }
                        .disabled(!canSave)
                        .accessibilityIdentifier("client.save")
                }
            }
            // Fork A Lot 1 / UI-T2 : alert au lieu de confirmationDialog.
            .alert("Abandonner la saisie ?", isPresented: $showCancelConfirm) {
                Button("Abandonner", role: .destructive) { dismiss() }
                Button("Continuer la saisie", role: .cancel) {}
            } message: {
                Text("Les informations saisies seront perdues.")
            }
            .onAppear(perform: preload)
        }
    }

    /// DOB par défaut quand l'utilisateur active le picker : 40 ans en arrière.
    private var defaultDOB: Date {
        Calendar.current.date(byAdding: .year, value: -40, to: Date()) ?? Date()
    }

    private func preload() {
        if case .edit(let c) = mode {
            firstName = c.firstName
            lastName = c.lastName
            email = c.email ?? ""
            phone = c.phone ?? ""
            dateOfBirth = c.dateOfBirth.flatMap(Self.parseISODate)
            gender = c.gender ?? ""
            addressLine1 = c.addressLine1 ?? ""
            addressLine2 = c.addressLine2 ?? ""
            city = c.city ?? ""
            stateCode = c.stateCode ?? "CA"
            postalCode = c.postalCode ?? ""
            accessNotes = c.accessNotes ?? ""
            allergies = c.allergies
            medicalConditions = c.medicalConditions
            medications = c.medications
            emergencyName = c.emergencyContactName ?? ""
            emergencyPhone = c.emergencyContactPhone ?? ""
        }
    }

    private static func parseISODate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: s)
    }

    private static func formatISODate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: d)
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

        let dobString = dateOfBirth.map(Self.formatISODate)

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
                    dateOfBirth: dobString,
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
                    medications: medications,
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
                    dateOfBirth: changed(dobString ?? "", c.dateOfBirth),
                    gender: changed(gender, c.gender),
                    addressLine1: changed(addressLine1, c.addressLine1),
                    addressLine2: changed(addressLine2, c.addressLine2),
                    city: changed(city, c.city),
                    stateCode: changed(stateCode, c.stateCode),
                    postalCode: changed(postalCode, c.postalCode),
                    accessNotes: changed(accessNotes, c.accessNotes),
                    allergies: changedArray(allergies, c.allergies),
                    medicalConditions: changedArray(medicalConditions, c.medicalConditions),
                    medications: changedArray(medications, c.medications),
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
        } catch APIService.QueuedError.enqueued {
            // Audit C-94 : la création offline est queueée — on traite comme un
            // succès optimiste pour ne pas frustrer l'utilisatrice. Le sync se
            // fera automatiquement au retour réseau.
            infoMessage = "Hors-ligne. Le client sera créé à la reconnexion."
            try? await Task.sleep(nanoseconds: 900_000_000)
            onSaved()
            dismiss()
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
