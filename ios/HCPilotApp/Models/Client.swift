import Foundation

/// Brief schema `clients` — patient privé du soignant IV mobile (private pay,
/// pas d'insurance). Allergies/medical_conditions/medications sont des arrays
/// (jsonb dans le brief). Adresse splittée en 5 champs.
struct Client: Identifiable, Hashable, Codable {
    let id: String
    let nurse_id: String
    let first_name: String
    let last_name: String
    let email: String?
    let phone: String?
    let date_of_birth: String?
    let gender: String?
    // Adresse splittée (brief)
    let address_line1: String?
    let address_line2: String?
    let city: String?
    let state_code: String?
    let postal_code: String?
    let access_notes: String?  // code accès immeuble, étage, parking
    // Coords géocodées (denormalized pour route optimization + cache offline)
    let latitude: Double?
    let longitude: Double?
    // Antécédents médicaux en arrays
    let allergies: [String]
    let medical_conditions: [String]
    let medications: [String]
    let emergency_contact_name: String?
    let emergency_contact_phone: String?
    let id_document_path: String?  // photo ID stockée (Supabase Storage en prod)
    let archived_at: Date?
    let created_at: Date
    let updated_at: Date?

    var isArchived: Bool { archived_at != nil }

    var full_name: String { "\(first_name) \(last_name)" }

    var initials: String {
        "\(first_name.prefix(1))\(last_name.prefix(1))"
    }

    /// Concatène les 5 champs d'adresse pour l'affichage simple.
    /// (Le brief utilise les champs séparés ; cette computed n'est qu'une commodité.)
    var full_address: String {
        [address_line1, address_line2, city, postal_code, state_code]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}
