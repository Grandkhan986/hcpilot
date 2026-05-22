import Foundation

/// Brief schema `clients` — patient privé du soignant IV mobile (private pay).
/// camelCase Swift / snake_case JSON via APIService global strategy.
/// Audit B2 : Equatable/Hashable basés sur `id` (l'identité de l'entité) plutôt
/// que sur toutes les propriétés.
struct Client: Identifiable, Hashable, Codable {
    let id: String
    let nurseId: String
    let firstName: String
    let lastName: String
    let email: String?
    let phone: String?
    let dateOfBirth: String?
    let gender: String?
    // Adresse splittée (brief)
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let stateCode: String?
    let postalCode: String?
    let accessNotes: String?
    // Coords géocodées (denormalized pour route optimization + cache offline)
    let latitude: Double?
    let longitude: Double?
    // Antécédents médicaux en arrays
    let allergies: [String]
    let medicalConditions: [String]
    let medications: [String]
    let emergencyContactName: String?
    let emergencyContactPhone: String?
    let idDocumentPath: String?  // photo ID (Supabase Storage en prod)
    let archivedAt: Date?
    let createdAt: Date
    let updatedAt: Date?

    var isArchived: Bool { archivedAt != nil }

    var fullName: String { "\(firstName) \(lastName)" }

    var initials: String {
        "\(firstName.prefix(1))\(lastName.prefix(1))"
    }

    /// Concatène les 5 champs d'adresse pour l'affichage simple.
    var fullAddress: String {
        [addressLine1, addressLine2, city, postalCode, stateCode]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    static func == (lhs: Client, rhs: Client) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
