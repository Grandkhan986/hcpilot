import Foundation

/// Une session IV : ce que la nurse effectue chez le client.
/// Brief : table `sessions`. Modèle private pay — pas de champs insurance/copay.
struct Session: Identifiable, Codable, Equatable {
    let id: String
    let client_id: String
    var client_name: String?
    let formulation_name: String
    var status: SessionStatus
    let scheduled_at: Date
    let created_at: Date
    let address: String
    let latitude: Double?
    let longitude: Double?
    let notes: String?
    let total: Double
    var estimated_duration: Int?
    var started_at: Date?
    var completed_at: Date?

    /// Cycle de vie d'une session (brief : 6 statuts).
    /// Transitions normales :
    ///   scheduled → en_route → in_progress → completed
    ///   scheduled → cancelled
    ///   scheduled → no_show (si le client n'est pas présent)
    enum SessionStatus: String, Codable, CaseIterable {
        case scheduled = "scheduled"
        case en_route = "en_route"
        case in_progress = "in_progress"
        case completed = "completed"
        case cancelled = "cancelled"
        case no_show = "no_show"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case client_id
        case client_name
        case formulation_name
        case status
        case scheduled_at
        case created_at
        case address
        case latitude
        case longitude
        case notes
        case total = "total_amount"
        case estimated_duration
        case started_at
        case completed_at
    }

    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }
}

struct UserProfile: Codable {
    let id: String
    let email: String
    let full_name: String
    let role: String?
    let specialty: String?
    let phone: String?
    let avatar_url: String?
    let settings: UserSettings?
}

struct UserSettings: Codable {
    let notifications: Bool?
    let emailNotifications: Bool?
    let SMSNotifications: Bool?
    let darkMode: Bool?
    let autoOptimizeRoutes: Bool?
    let showPriceHistory: Bool?
}
