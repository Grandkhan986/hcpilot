import SwiftUI

/// Bottom sheet déclenchée par un tap sur une carte de stock bas (brief §refonte
/// Home — action « Réapprovisionner »). Affiche le détail du produit et propose
/// deux CTA : voir les lots filtrés (in-app) ou ouvrir l'URL fournisseur perso.
struct LowStockSheet: View {
    let item: LowStockProduct
    let onSeeAllLots: () -> Void

    /// URL fournisseur configurée par la nurse. Persistée via @AppStorage.
    /// Intégration directe Olympia/Empower/AnazaoHealth = Tier 2.
    @AppStorage("supplier.restock.url") private var supplierURL: String = ""
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Handle visuel
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.productName)
                    .font(.title3.weight(.semibold))
                Text(item.productCategory.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Quantité restante", systemImage: "cube.box")
                        .font(.subheadline)
                    Spacer()
                    Text("\(item.totalQuantity)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.totalQuantity == 0 ? .red : .primary)
                }
                HStack {
                    Label("Péremption la plus proche", systemImage: "calendar")
                        .font(.subheadline)
                    Spacer()
                    Text(Self.dateFormatter.string(from: item.nearestExpiration))
                        .font(.subheadline.weight(.semibold))
                }
            }

            Divider()

            VStack(spacing: 8) {
                Button {
                    onSeeAllLots()
                    dismiss()
                } label: {
                    Label("Voir tous les lots", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)

                Button {
                    if let url = URL(string: supplierURL), !supplierURL.isEmpty {
                        openURL(url)
                    }
                } label: {
                    Label(
                        supplierURL.isEmpty ? "Configurer le fournisseur…" : "Réapprovisionner",
                        systemImage: "cart.badge.plus"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(supplierURL.isEmpty ? .secondary : .blue)
                .disabled(supplierURL.isEmpty)

                if supplierURL.isEmpty {
                    // Champ de config inline — la nurse colle son lien Olympia/
                    // Empower/AnazaoHealth la première fois.
                    TextField("URL portail fournisseur", text: $supplierURL)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}
