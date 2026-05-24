import Foundation

/// L2-11 — Genre du client : enum type-safe avec codes courts compatibles
/// backend (M/F/O/U). Decode tolérant (valeur inconnue → .unspecified)
/// pour éviter de casser un Client existant si le backend ajoute un code.
enum Gender: String, CaseIterable, Codable {
    case male = "M"
    case female = "F"
    case other = "O"
    case unspecified = "U"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Gender(rawValue: raw) ?? .unspecified
    }

    var displayName: String {
        switch self {
        case .male: return "Homme"
        case .female: return "Femme"
        case .other: return "Autre"
        case .unspecified: return "Non spécifié"
        }
    }
}

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
    /// L2-10 — conservé en String? côté Model (backend = "YYYY-MM-DD" ISO)
    /// pour ne pas casser le contrat JSON ; helper `dateOfBirthAsDate` pour
    /// le parsing safe côté UI/calculs d'âge.
    let dateOfBirth: String?
    let gender: Gender?
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

    /// L2-26 — `fullName` gère firstName/lastName vide : utilise l'autre
    /// composant seul plutôt que d'afficher " Martin" ou "Marie ".
    var fullName: String {
        let trimmed = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "—" : trimmed
    }

    /// L2-27 — `initials` avec fallback si l'un des composants est vide.
    var initials: String {
        let f = firstName.prefix(1)
        let l = lastName.prefix(1)
        let combined = "\(f)\(l)"
        return combined.isEmpty ? "?" : combined
    }

    /// L2-10 — Parse safe de la DOB string en Date (ISO `yyyy-MM-dd`).
    /// Centralise la logique au lieu de la dupliquer dans chaque caller.
    var dateOfBirthAsDate: Date? {
        guard let s = dateOfBirth, !s.isEmpty else { return nil }
        return Client.isoDateFormatter.date(from: s)
    }

    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

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
