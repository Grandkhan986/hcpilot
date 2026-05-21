import SwiftUI

/// Flow complet d'ajout d'un lot : scan code-barres → formulaire pré-rempli si
/// le produit est déjà connu → POST /inventory/lots.
struct AddLotFlow: View {
    var onSaved: () -> Void

    @State private var scannedBarcode: String?
    @State private var prefill: InventoryLot?
    @State private var showForm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if showForm {
            LotEntryView(
                barcode: scannedBarcode,
                prefill: prefill,
                onSaved: {
                    onSaved()
                    dismiss()
                },
                onCancel: { dismiss() }
            )
        } else {
            BarcodeScannerView(
                onDetected: { code in
                    scannedBarcode = code
                    Task { await checkExistingProduct(barcode: code) }
                },
                onCancel: { dismiss() }
            )
        }
    }

    private func checkExistingProduct(barcode: String) async {
        do {
            let existing = try await APIService.shared.findLotsByBarcode(barcode)
            // Si on connaît déjà ce produit, on pré-remplit avec le 1er lot trouvé
            prefill = existing.first
        } catch {
            prefill = nil
        }
        showForm = true
    }
}

struct LotEntryView: View {
    let barcode: String?
    let prefill: InventoryLot?
    var onSaved: () -> Void
    var onCancel: () -> Void

    @State private var productName: String = ""
    @State private var category: String = "vitamins"
    @State private var lotNumber: String = ""
    @State private var expirationDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var quantityInitial: Int = 1
    @State private var unitCost: String = ""
    @State private var supplier: String = ""
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    let categories = ["nad", "vitamins", "saline", "medication", "supplies", "other"]

    var body: some View {
        NavigationView {
            Form {
                if let prefill {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Produit reconnu : \(prefill.productName)").font(.caption)
                        }
                    }
                }
                Section("Produit") {
                    TextField("Nom du produit", text: $productName)
                    Picker("Catégorie", selection: $category) {
                        ForEach(categories, id: \.self) { c in
                            Text(c.capitalized).tag(c)
                        }
                    }
                    if let bc = barcode {
                        HStack {
                            Text("Code-barres")
                            Spacer()
                            Text(bc).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Lot") {
                    TextField("Numéro de lot", text: $lotNumber)
                        .autocapitalization(.allCharacters)
                    DatePicker("Péremption", selection: $expirationDate, displayedComponents: .date)
                    Stepper("Quantité initiale : \(quantityInitial)", value: $quantityInitial, in: 1...500)
                }

                Section("Acquisition") {
                    TextField("Fournisseur", text: $supplier)
                    TextField("Coût unitaire (€)", text: $unitCost)
                        .keyboardType(.decimalPad)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let err = errorMessage {
                    Section {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Nouveau lot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { Task { await save() } }
                        .disabled(productName.isEmpty || lotNumber.isEmpty || isSaving)
                }
            }
            .onAppear(perform: applyPrefill)
        }
    }

    private func applyPrefill() {
        if let prefill {
            productName = prefill.productName
            category = prefill.productCategory
            if let s = prefill.supplier { supplier = s }
            if let c = prefill.unitCost { unitCost = String(format: "%.2f", c) }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(secondsFromGMT: 0)
        let cost = Double(unitCost.replacingOccurrences(of: ",", with: "."))
        let payload = CreateLotRequest(
            productName: productName,
            productCategory: category,
            barcode: barcode,
            lotNumber: lotNumber,
            expirationDate: df.string(from: expirationDate),
            quantityInitial: quantityInitial,
            unitCost: cost,
            supplier: supplier.isEmpty ? nil : supplier,
            receivedAt: df.string(from: Date()),
            notes: notes.isEmpty ? nil : notes
        )
        do {
            _ = try await APIService.shared.createInventoryLot(payload)
            onSaved()
        } catch {
            errorMessage = "Erreur : \(error.localizedDescription)"
        }
    }
}
