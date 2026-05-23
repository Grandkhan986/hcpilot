import SwiftUI
import MapKit
import Combine

/// Fork A Lot 2 / M-43 — champ d'adresse avec autocomplétion Apple Maps.
///
/// Utilise `MKLocalSearchCompleter` (natif iOS, pas de clé tierce, pas de
/// coût). À la frappe, des suggestions s'affichent ; un tap sur une
/// suggestion remplit `line1`, `city`, `stateCode` et `postalCode` en
/// déclenchant un `MKLocalSearch` pour récupérer les composants détaillés
/// via le `placemark`.
///
/// Limité aux États-Unis (`region` centrée sur les USA) — cohérent avec
/// la cible du brief (nurses IV mobiles US).
struct AddressAutocompleteField: View {
    @Binding var line1: String
    @Binding var city: String
    @Binding var stateCode: String
    @Binding var postalCode: String

    @StateObject private var completer = AddressCompleterModel()
    @State private var isFocused = false
    @FocusState private var fieldFocus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Adresse (ligne 1)", text: $line1)
                .focused($fieldFocus)
                .accessibilityIdentifier("client.addressLine1")
                .onChange(of: line1) { _, newValue in
                    if fieldFocus {
                        completer.update(query: newValue)
                    }
                }
                .onChange(of: fieldFocus) { _, focused in
                    if !focused {
                        // Délai pour laisser le tap sur une suggestion
                        // se déclencher avant le clear.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            completer.suggestions = []
                        }
                    }
                }

            if fieldFocus && !completer.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(completer.suggestions, id: \.id) { suggestion in
                        Button {
                            select(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Text(suggestion.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("address.suggestion.\(suggestion.id)")
                        Divider().padding(.leading, 12)
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 1)
            }
        }
    }

    private func select(_ suggestion: AddressCompleterModel.Suggestion) {
        // Lance un MKLocalSearch pour récupérer les composants structurés
        // (street / locality / administrativeArea / postalCode).
        Task {
            await completer.resolve(suggestion) { placemark in
                Task { @MainActor in
                    if let street = placemark.thoroughfare {
                        let number = placemark.subThoroughfare.map { "\($0) " } ?? ""
                        line1 = "\(number)\(street)"
                    } else {
                        // Fallback : utilise le titre brut
                        line1 = suggestion.title
                    }
                    if let c = placemark.locality { city = c }
                    if let s = placemark.administrativeArea {
                        // MKPlacemark renvoie parfois "California" → on
                        // veut juste "CA". Code postal US = 2 lettres.
                        stateCode = s.count == 2 ? s.uppercased() : Self.usStateAbbreviation(for: s) ?? s
                    }
                    if let z = placemark.postalCode { postalCode = z }
                    completer.suggestions = []
                    fieldFocus = false
                }
            }
        }
    }

    /// Mapping rapide nom complet → code 2 lettres pour les états US.
    /// Couvre les cas où MKLocalSearchCompleter renvoie "California" au lieu de "CA".
    private static func usStateAbbreviation(for name: String) -> String? {
        let map = [
            "Alabama": "AL", "Alaska": "AK", "Arizona": "AZ", "Arkansas": "AR",
            "California": "CA", "Colorado": "CO", "Connecticut": "CT",
            "Delaware": "DE", "Florida": "FL", "Georgia": "GA", "Hawaii": "HI",
            "Idaho": "ID", "Illinois": "IL", "Indiana": "IN", "Iowa": "IA",
            "Kansas": "KS", "Kentucky": "KY", "Louisiana": "LA", "Maine": "ME",
            "Maryland": "MD", "Massachusetts": "MA", "Michigan": "MI",
            "Minnesota": "MN", "Mississippi": "MS", "Missouri": "MO",
            "Montana": "MT", "Nebraska": "NE", "Nevada": "NV",
            "New Hampshire": "NH", "New Jersey": "NJ", "New Mexico": "NM",
            "New York": "NY", "North Carolina": "NC", "North Dakota": "ND",
            "Ohio": "OH", "Oklahoma": "OK", "Oregon": "OR", "Pennsylvania": "PA",
            "Rhode Island": "RI", "South Carolina": "SC", "South Dakota": "SD",
            "Tennessee": "TN", "Texas": "TX", "Utah": "UT", "Vermont": "VT",
            "Virginia": "VA", "Washington": "WA", "West Virginia": "WV",
            "Wisconsin": "WI", "Wyoming": "WY",
        ]
        return map[name]
    }
}

/// Wrapper autour de `MKLocalSearchCompleter` qui expose les suggestions
/// en `@Published` pour SwiftUI. Filtre les résultats par adresse aux USA.
@MainActor
final class AddressCompleterModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [Suggestion] = []

    struct Suggestion: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let raw: MKLocalSearchCompletion
    }

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        // Région approximative USA. MKLocalSearchCompleter biaise mais
        // ne filtre pas strictement — c'est OK pour le MVP.
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
            span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
        )
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            suggestions = []
            return
        }
        completer.queryFragment = trimmed
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.suggestions = results.prefix(5).map { r in
                Suggestion(
                    id: "\(r.title)|\(r.subtitle)",
                    title: r.title,
                    subtitle: r.subtitle,
                    raw: r
                )
            }
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.suggestions = [] }
    }

    /// Résout une suggestion en un `MKPlacemark` structuré.
    func resolve(_ suggestion: Suggestion, completion: @escaping (CLPlacemark) -> Void) async {
        let request = MKLocalSearch.Request(completion: suggestion.raw)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            if let placemark = response.mapItems.first?.placemark {
                completion(placemark)
            }
        } catch {
            // Silent fail — le caller a déjà l'option de fallback sur title brut
        }
    }
}
