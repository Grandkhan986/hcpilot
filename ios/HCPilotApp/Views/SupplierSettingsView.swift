import SwiftUI

/// Préférences fournisseur de la nurse (brief §refonte Home — patch 4).
/// L'URL est utilisée par le bottom sheet « Réapprovisionner » de l'accueil.
/// Persistée localement via @AppStorage : on ne renvoie pas l'URL au serveur
/// pour rester soft sur la confidentialité (chaque nurse a son contrat).
struct SupplierSettingsView: View {
    @AppStorage("supplier.restock.url") private var supplierURL: String = ""
    @AppStorage("supplier.name") private var supplierName: String = ""
    @Environment(\.openURL) private var openURL

    private static let presets: [(label: String, url: String)] = [
        ("Olympia Pharmacy", "https://olympiapharmacy.com/"),
        ("Empower Pharmacy", "https://empowerpharmacy.com/"),
        ("AnazaoHealth",     "https://www.anazaohealth.com/"),
    ]

    var body: some View {
        Form {
            Section("Fournisseur principal") {
                TextField("Nom du fournisseur", text: $supplierName)
                    .textContentType(.organizationName)
                TextField("URL du portail (https://…)", text: $supplierURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            Section("Raccourcis") {
                ForEach(Self.presets, id: \.url) { preset in
                    Button {
                        supplierName = preset.label
                        supplierURL = preset.url
                    } label: {
                        HStack {
                            Text(preset.label)
                            Spacer()
                            if supplierURL == preset.url {
                                Image(systemName: "checkmark").foregroundStyle(.blue)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }

            if let url = URL(string: supplierURL), !supplierURL.isEmpty {
                Section {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Tester le lien", systemImage: "arrow.up.forward.square")
                    }
                }
            }

            Section("Pourquoi ?") {
                Text("HCPilot vous redirige vers votre portail fournisseur quand un produit passe sous le seuil de stock bas. L'intégration directe (commande en un tap) arrive plus tard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Fournisseur (réappro)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SupplierSettingsView() }
}
