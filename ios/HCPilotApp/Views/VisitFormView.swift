import SwiftUI

/// Formulaire d'édition d'une visite existante.
struct VisitFormView: View {
    let visit: Visit
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var visitType: String = ""
    @State private var address: String = ""
    @State private var notes: String = ""
    @State private var scheduledAt: Date = Date()
    @State private var estimatedDuration: Int = 60
    @State private var totalAmount: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let serviceTypes = ["IV_Hydration", "Post_Op", "Primary_Care", "Vaccination", "Consultation"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Service")) {
                    Picker("Type", selection: $visitType) {
                        ForEach(serviceTypes, id: \.self) { t in
                            Text(t.replacingOccurrences(of: "_", with: " ")).tag(t)
                        }
                    }
                    DatePicker("Date", selection: $scheduledAt, displayedComponents: [.date, .hourAndMinute])
                    Stepper("Durée : \(estimatedDuration) min", value: $estimatedDuration, in: 15...240, step: 15)
                }

                Section(header: Text("Lieu")) {
                    TextField("Adresse", text: $address, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section(header: Text("Détails")) {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Montant (€)", text: $totalAmount)
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
        visitType = visit.service_type
        address = visit.address
        notes = visit.notes ?? ""
        scheduledAt = visit.scheduled_at
        estimatedDuration = visit.estimated_duration ?? 60
        totalAmount = String(format: "%.2f", visit.total)
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let patch = APIService.VisitPatch(
            visit_type: visitType != visit.service_type ? visitType : nil,
            visit_date: scheduledAt != visit.scheduled_at ? scheduledAt : nil,
            address: address != visit.address ? address : nil,
            // Adresse changée → on laisse le backend regéocoder (lat/lng à nil)
            latitude: address != visit.address ? nil : nil,
            longitude: address != visit.address ? nil : nil,
            notes: notes != (visit.notes ?? "") ? notes : nil,
            estimated_duration: estimatedDuration != (visit.estimated_duration ?? 60) ? estimatedDuration : nil,
            total_amount: Double(totalAmount.replacingOccurrences(of: ",", with: ".")).map { $0 != visit.total ? $0 : nil } ?? nil
        )

        do {
            _ = try await APIService.shared.updateVisit(id: visit.id, patch: patch)
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Erreur : \(error.localizedDescription)"
        }
    }
}
