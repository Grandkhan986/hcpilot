import SwiftUI

/// Liste principale d'inventaire — vue groupée par référence produit avec
/// total quantity et statut péremption. Bouton "+ Scanner" pour ajouter un lot.
struct InventoryListView: View {
    @StateObject private var vm = InventoryViewModel()
    @State private var showAddSheet = false
    @State private var searchTerm = ""

    var filtered: [InventoryProduct] {
        guard !searchTerm.isEmpty else { return vm.products }
        return vm.products.filter {
            $0.productName.localizedCaseInsensitiveContains(searchTerm)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerStats
                    .padding(.horizontal)
                    .padding(.top, 8)

                SearchBar(text: $searchTerm)
                    .padding(.horizontal)
                    .padding(.top, 8)

                if vm.isLoading && vm.products.isEmpty {
                    Spacer(); ProgressView(); Spacer()
                } else if filtered.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "cube.box")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Aucun produit en stock")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    List(filtered) { product in
                        NavigationLink(destination: InventoryDetailView(productName: product.productName)) {
                            ProductRow(product: product)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await vm.load() }
                }
            }
            .navigationTitle("Inventaire")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Scanner", systemImage: "barcode.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddLotFlow(onSaved: { Task { await vm.load() } })
            }
            .task { await vm.load() }
        }
    }

    private var headerStats: some View {
        HStack(spacing: 12) {
            StatTile(
                title: "Références",
                value: "\(vm.products.count)",
                color: .blue
            )
            StatTile(
                title: "Valeur stock",
                value: String(format: "%.0f €", vm.totalValue),
                color: .green
            )
            StatTile(
                title: "Péremptions ⚠️",
                value: "\(vm.expiringCount)",
                color: vm.expiringCount > 0 ? .orange : .secondary
            )
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.headline).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ProductRow: View {
    let product: InventoryProduct

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(colorForStatus(product.expirationStatus))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName)
                    .font(.subheadline).fontWeight(.semibold)
                HStack(spacing: 8) {
                    Text(product.productCategory.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                    Text("\(product.lotCount) lot\(product.lotCount > 1 ? "s" : "")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Exp. \(product.nearestExpiration, style: .date)")
                        .font(.caption2)
                        .foregroundStyle(colorForStatus(product.expirationStatus))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(product.totalQuantity)")
                    .font(.headline)
                Text("unités")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private func colorForStatus(_ status: ComplianceStatus) -> Color {
    switch status {
    case .ok: return .green
    case .warning: return .orange
    case .critical, .expired: return .red
    case .unknown: return .gray
    }
}

@MainActor
final class InventoryViewModel: ObservableObject {
    @Published var products: [InventoryProduct] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    var totalValue: Double {
        products.reduce(0) { $0 + $1.totalValue }
    }

    var expiringCount: Int {
        products.filter { [.warning, .critical, .expired].contains($0.expirationStatus) }.count
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let productsTask = api.getInventoryProducts()
            async let lotsTask = api.getInventoryLots()
            products = try await productsTask
            let lots = try await lotsTask
            // Brief §Notifications : J-15 péremption + J-30 (planif commandes).
            await NotificationService.shared.scheduleInventoryExpirationNotifications(lots: lots)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    InventoryListView()
}
