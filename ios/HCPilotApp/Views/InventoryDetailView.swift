import SwiftUI

/// Détail d'une référence produit : liste de tous les lots, qty restante,
/// péremption, supplier. Permet d'enregistrer un usage (décrément) sur un lot.
struct InventoryDetailView: View {
    let productName: String

    @State private var lots: [InventoryLot] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var lotForUsage: InventoryLot?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let err = errorMessage {
                Text(err).foregroundStyle(.red).padding()
            } else if lots.isEmpty {
                Text("Aucun lot pour ce produit").foregroundStyle(.secondary)
            } else {
                List {
                    Section("\(lots.count) lot\(lots.count > 1 ? "s" : "")") {
                        ForEach(lots) { lot in
                            LotRow(lot: lot)
                                .swipeActions {
                                    Button {
                                        lotForUsage = lot
                                    } label: {
                                        Label("Usage", systemImage: "minus.circle")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(productName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $lotForUsage) { lot in
            UsageSheet(lot: lot) { used in
                if used { Task { await load() } }
                lotForUsage = nil
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await APIService.shared.getInventoryLots()
            lots = all.filter { $0.product_name == productName }
                .sorted { $0.expiration_date < $1.expiration_date }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct LotRow: View {
    let lot: InventoryLot

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Lot \(lot.lot_number)").font(.subheadline).fontWeight(.semibold)
                Spacer()
                StatusChip(status: lot.expiration_status ?? "unknown")
            }
            HStack(spacing: 14) {
                Label("\(lot.quantity_remaining)/\(lot.quantity_initial)", systemImage: "cube")
                Label("Exp. \(lot.expiration_date)", systemImage: "calendar")
                if let d = lot.days_to_expiry {
                    Text(d < 0 ? "Expiré" : "J-\(d)")
                        .foregroundStyle(d < 30 ? .red : .secondary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if let supplier = lot.supplier {
                    Label(supplier, systemImage: "shippingbox")
                        .font(.caption2)
                }
                if let cost = lot.unit_cost {
                    Label(String(format: "%.2f €/unité", cost), systemImage: "eurosign.circle")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
            if let notes = lot.notes, !notes.isEmpty {
                Text(notes).font(.caption2).foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct StatusChip: View {
    let status: String
    var body: some View {
        Text(label).font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
    private var label: String {
        switch status {
        case "ok": return "OK"
        case "warning": return "Bientôt"
        case "critical": return "<15j"
        case "expired": return "Expiré"
        default: return "—"
        }
    }
    private var color: Color {
        switch status {
        case "ok": return .green
        case "warning": return .orange
        case "critical", "expired": return .red
        default: return .gray
        }
    }
}

private struct UsageSheet: View {
    let lot: InventoryLot
    var onClose: (Bool) -> Void

    @State private var quantity: Int = 1
    @State private var notes: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section("Lot") {
                    Text(lot.product_name).font(.headline)
                    HStack {
                        Text("Lot \(lot.lot_number)")
                        Spacer()
                        Text("Restant : \(lot.quantity_remaining)")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Usage") {
                    Stepper("Quantité : \(quantity)", value: $quantity, in: 1...lot.quantity_remaining)
                    TextField("Notes (optionnel)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                if let e = errorMessage {
                    Section { Text(e).font(.caption).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Enregistrer usage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onClose(false) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirmer") { Task { await submit() } }
                        .disabled(isSubmitting)
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let payload = RecordUsageRequest(
            lot_id: lot.id,
            session_id: nil,
            quantity: quantity,
            notes: notes.isEmpty ? nil : notes
        )
        do {
            _ = try await APIService.shared.recordUsage(payload)
            onClose(true)
        } catch {
            errorMessage = "Erreur : \(error.localizedDescription)"
        }
    }
}
