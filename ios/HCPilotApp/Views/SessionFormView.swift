import SwiftUI

/// Formulaire d'édition d'une session existante.
struct SessionFormView: View {
    let session: Session
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sessionType: String = ""
    @State private var address: String = ""
    @State private var notes: String = ""
    @State private var scheduledAt: Date = Date()
    @State private var estimatedDuration: Int = 60
    @State private var totalAmount: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Formulations brief-aligned (cf. /formulations backend) — IV products réels.
    private let serviceTypes = ["Myers Cocktail", "NAD+ 250mg", "NAD+ 500mg"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Formulation")) {
                    Picker("Formulation IV", selection: $sessionType) {
                        ForEach(serviceTypes, id: \.self) { t in
                            Text(t).tag(t)
                        }
                    }
                    DatePicker("Date", selection: $scheduledAt, displayedComponents: [.date, .hourAndMinute])
                    Stepper("Durée : \(estimatedDuration) min", value: $estimatedDuration, in: 15...240, step: 15)
                }

                Section(header: Text("Lieu")) {
                    TextField("Adresse", text: $address, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section(header: Text("Détails cliniques")) {
                    TextField("Notes cliniques", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Montant ($)", text: $totalAmount)
                        .keyboardType(.decimalPad)
                }

                if let error = errorMessage {
                    Section { Text(error).foregroundColor(.red).font(.caption) }
                }
            }
            .navigationTitle("Modifier session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { Task { await save() } }
                        .disabled(address.isEmpty || isSaving)
                }
            }
            .onAppear(perform: preload)
        }
    }

    private func preload() {
        sessionType = session.formulationName
        address = session.address
        notes = session.clinicalNotes ?? ""
        scheduledAt = session.scheduledAt
        estimatedDuration = session.estimatedDuration ?? 60
        totalAmount = String(format: "%.2f", session.totalAmount)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let patch = APIService.SessionPatch(
            formulationName: sessionType != session.formulationName ? sessionType : nil,
            scheduledAt: scheduledAt != session.scheduledAt ? scheduledAt : nil,
            address: address != session.address ? address : nil,
            // Adresse changée → on laisse le backend regéocoder (lat/lng à nil)
            latitude: nil,
            longitude: nil,
            clinicalNotes: notes != (session.clinicalNotes ?? "") ? notes : nil,
            estimatedDuration: estimatedDuration != (session.estimatedDuration ?? 60) ? estimatedDuration : nil,
            totalAmount: Double(totalAmount.replacingOccurrences(of: ",", with: "."))
                .flatMap { $0 != session.totalAmount ? $0 : nil }
        )

        do {
            _ = try await APIService.shared.updateSession(id: session.id, patch: patch)
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Erreur : \(error.localizedDescription)"
        }
    }
}
