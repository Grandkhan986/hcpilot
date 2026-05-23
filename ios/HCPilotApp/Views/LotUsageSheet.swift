import SwiftUI

/// Sélecteur de lot utilisé à la fin d'une session. Présenté avant l'appel à
/// `/sessions/{id}/complete` : on enregistre l'usage du lot (décrément + traçabilité)
/// puis on clôture la session. Possibilité de "Sans scan" si pas de lot dispo
/// (le complete est alors fait sans entrée d'inventaire).
struct LotUsageSheet: View {
    let session: Session
    /// Si fourni, filtre les lots dont le `productName` matche (utile quand
    /// on connaît la formulation via un consentement déjà signé).
    let preferredProductName: String?
    var onCompleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var lots: [InventoryLot] = []
    @State private var selectedLotId: String?
    @State private var quantity: Int = 1
    @State private var notes: String = ""
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var filterToPreferred = true
    @State private var showCancelConfirm = false
    @State private var showSkipScanConfirm = false

    /// Audit H-68 : true si l'utilisateur a commencé à saisir quelque chose qui
    /// mérite confirmation avant fermeture.
    private var hasUserInput: Bool {
        selectedLotId != nil || !notes.isEmpty
    }

    private var displayedLots: [InventoryLot] {
        let filtered = (filterToPreferred && preferredProductName != nil)
            ? lots.filter { $0.productName == preferredProductName }
            : lots
        return filtered.sorted { $0.expirationDate < $1.expirationDate }
    }

    private var selectedLot: InventoryLot? {
        lots.first(where: { $0.id == selectedLotId })
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let preferred = preferredProductName {
                    HStack {
                        Toggle("Filtrer : \(preferred)", isOn: $filterToPreferred)
                            .font(.caption)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                if isLoading {
                    Spacer(); ProgressView(); Spacer()
                } else if displayedLots.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "cube.box").font(.largeTitle).foregroundStyle(.secondary)
                        Text("Aucun lot disponible").foregroundStyle(.secondary)
                        Text(filterToPreferred ? "Désactivez le filtre pour voir tous les lots." : "Ajoutez un lot via l'onglet Stock.")
                            .font(.caption2).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    List(displayedLots) { lot in
                        LotRow(lot: lot, isSelected: lot.id == selectedLotId)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedLotId = lot.id }
                    }
                    .listStyle(.plain)
                }

                if let lot = selectedLot {
                    VStack(spacing: 10) {
                        Divider()
                        HStack {
                            Text("Quantité utilisée").font(.subheadline)
                            Spacer()
                            Stepper("\(quantity)", value: $quantity, in: 1...lot.quantityRemaining)
                                .labelsHidden()
                            Text("\(quantity)").frame(minWidth: 30)
                        }
                        TextField("Notes (optionnel)", text: $notes, axis: .vertical)
                            .lineLimit(1...2)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding()
                }

                if let err = errorMessage {
                    Text(err).font(.caption).foregroundStyle(.red).padding(.bottom, 4)
                }

                actionBar
            }
            .navigationTitle("Terminer la session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        // Audit H-68 : confirm si lot sélectionné ou notes saisies
                        if hasUserInput {
                            showCancelConfirm = true
                        } else {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("lot.cancel")
                }
            }
            .confirmationDialog(
                "Abandonner la saisie ?",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Abandonner", role: .destructive) { dismiss() }
                Button("Continuer la saisie", role: .cancel) {}
            } message: {
                Text("La session reste en cours. Vous pourrez la terminer plus tard.")
            }
            .confirmationDialog(
                "Terminer sans enregistrer de lot ?",
                isPresented: $showSkipScanConfirm,
                titleVisibility: .visible
            ) {
                Button("Terminer sans lot", role: .destructive) {
                    Task { await skipScan() }
                }
                Button("Choisir un lot", role: .cancel) {}
            } message: {
                Text("Sans lot, la traçabilité FDA est perdue. Utilisez uniquement si vous n'avez vraiment pas le lot consommé sous la main.")
            }
            .task { await loadLots() }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 8) {
            Button {
                Task { await confirmWithUsage() }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Confirmer la consommation et terminer").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedLot == nil || isSubmitting ? Color.gray : Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(selectedLot == nil || isSubmitting)
            .accessibilityIdentifier("lot.confirm")

            // Audit H-65 : dégrader visuellement le skip-scan + exiger confirm
            // explicite. La traçabilité FDA est trop importante pour un tap
            // accidentel sur un gros bouton.
            Button {
                showSkipScanConfirm = true
            } label: {
                Text("Terminer sans enregistrer de lot")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .underline()
            }
            .disabled(isSubmitting)
            .accessibilityIdentifier("lot.skipScan")
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    private func loadLots() async {
        isLoading = true
        defer { isLoading = false }
        do {
            lots = try await APIService.shared.getInventoryLots()
        } catch {
            errorMessage = "Chargement lots : \(error.localizedDescription)"
        }
    }

    private func confirmWithUsage() async {
        guard let lot = selectedLot else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await APIService.shared.recordUsage(RecordUsageRequest(
                lotId: lot.id,
                sessionId: session.id,
                quantity: quantity,
                notes: notes.isEmpty ? nil : notes
            ))
            _ = try await APIService.shared.completeSession(sessionId: session.id)
            onCompleted()
            dismiss()
        } catch {
            errorMessage = "Erreur : \(error.localizedDescription)"
        }
    }

    private func skipScan() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            _ = try await APIService.shared.completeSession(sessionId: session.id)
            onCompleted()
            dismiss()
        } catch {
            errorMessage = "Erreur : \(error.localizedDescription)"
        }
    }
}

private struct LotRow: View {
    let lot: InventoryLot
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(lot.productName).font(.subheadline).fontWeight(.semibold)
                HStack(spacing: 8) {
                    Text("Lot \(lot.lotNumber)").font(.caption)
                    Text("Exp. \(lot.expirationDate, style: .date)")
                        .font(.caption2)
                        .foregroundStyle(colorForStatus(lot.expirationStatus ?? .ok))
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(lot.quantityRemaining)")
                    .font(.headline)
                Text("restant\(lot.quantityRemaining > 1 ? "s" : "")")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func colorForStatus(_ s: ComplianceStatus) -> Color {
        switch s {
        case .ok: return .green
        case .warning: return .orange
        case .critical, .expired: return .red
        case .unknown: return .gray
        }
    }
}
