import SwiftUI

struct StockView: View {
    @StateObject private var viewModel = StockViewModel()
    @State private var showAddItemSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    SearchBar(text: $viewModel.searchTerm)
                    Button(action: { showAddItemSheet = true }) {
                        Image(systemName: "plus")
                            .padding(8)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Picker("Catégorie", selection: $viewModel.selectedCategory) {
                    Text("Toutes").tag("all")
                    ForEach(viewModel.categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    List(viewModel.filteredStock) { item in
                        StockListItem(item: item)
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Stock")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAddItemSheet) {
                AddStockItemView(onAdded: { viewModel.refresh() })
            }
            .onAppear { viewModel.load() }
        }
    }
}

struct StockListItem: View {
    let item: StockItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                Text(item.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.quantity)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(item.isLowStock ? .red : .primary)

                Text(item.isLowStock ? "Stock faible" : "Stock OK")
                    .font(.caption2)
                    .foregroundColor(item.isLowStock ? .red : .green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

@MainActor
class StockViewModel: ObservableObject {
    @Published var stock: [StockItem] = []
    @Published var searchTerm = ""
    @Published var selectedCategory = "all"
    @Published var isLoading = false
    @Published var errorMessage: String?

    let apiService = APIService.shared

    let categories = ["IV_Supplies", "Medication", "Equipment"]

    var filteredStock: [StockItem] {
        stock.filter { item in
            let matchesSearch = searchTerm.isEmpty || item.name.lowercased().contains(searchTerm.lowercased())
            let matchesCategory = selectedCategory == "all" || item.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    func load() {
        Task { await fetchStock() }
    }

    func refresh() {
        Task { await fetchStock() }
    }

    private func fetchStock() async {
        isLoading = true
        do {
            stock = try await apiService.getStock()
        } catch {
            errorMessage = "Erreur: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

struct AddStockItemView: View {
    @Environment(\.dismiss) var dismiss
    var onAdded: () -> Void
    @State private var name = ""
    @State private var category = "IV_Supplies"
    @State private var quantity = 0
    @State private var minQuantity = 10

    let categories = ["IV_Supplies", "Medication", "Equipment"]
    let apiService = APIService.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informations")) {
                    TextField("Nom du produit", text: $name)
                    Picker("Catégorie", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }
                Section(header: Text("Quantité")) {
                    Stepper(value: $quantity, in: 0...10000, step: 1) {
                        Text("Quantité: \(quantity)")
                    }
                    Stepper(value: $minQuantity, in: 0...1000, step: 1) {
                        Text("Seuil min: \(minQuantity)")
                    }
                }
            }
            .navigationTitle("Nouvel Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { addItem() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private func addItem() {
        let newItem = StockItem(
            id: UUID().uuidString,
            name: name,
            category: category,
            quantity: quantity,
            min_quantity: minQuantity,
            description: nil,
            expiration_date: nil,
            barcode: nil,
            cost_per_unit: nil
        )
        Task {
            do {
                _ = try await apiService.addStockItem(item: newItem)
                onAdded()
                dismiss()
            } catch {
                print("Erreur ajout stock: \(error)")
            }
        }
    }
}

#Preview {
    StockView()
}
