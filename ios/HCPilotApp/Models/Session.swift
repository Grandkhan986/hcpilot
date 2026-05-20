import Foundation

/// Une session IV : ce que la nurse effectue chez le client.
/// Brief : table `sessions`. Modèle private pay — pas de champs insurance/copay.
/// Capture les données cliniques nécessaires à un audit FDA (formulation_inventory_id
/// = lot utilisé) et à une revue HIPAA (vitals + clinical_notes).
struct Session: Identifiable, Codable, Equatable {
    let id: String
    let client_id: String
    let nurse_id: String
    var client_name: String?
    let formulation_name: String
    /// Lien vers le lot inventaire administré — traçabilité FDA en cas de rappel.
    let formulation_inventory_id: String?
    var status: SessionStatus
    let scheduled_at: Date
    let created_at: Date
    // Adresse + coords denormalisées (snapshot au moment de la création)
    let address: String
    let latitude: Double?
    let longitude: Double?
    let total: Double
    var estimated_duration: Int?
    // Clock-in / clock-out session entière (route + IV + débrief)
    var started_at: Date?
    var completed_at: Date?
    // Heures effectives de la perfusion IV (distinctes du clock-in/out session)
    var iv_start_time: Date?
    var iv_end_time: Date?
    /// Vitals : jsonb libre `{"bp_sys": 120, "bp_dia": 80, "hr": 72, ...}`.
    /// On utilise `[String: String]` côté iOS pour simplifier — backend renvoie
    /// des nombres mais on les stringify côté API.
    var pre_vitals: [String: String]?
    var during_vitals: [String: String]?
    var post_vitals: [String: String]?
    var drip_rate: String?  // ex: "50 mL/h"
    var clinical_notes: String?
    var photos_paths: [String]
    var cancelled_at: Date?
    var cancellation_reason: String?

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
        case nurse_id
        case client_name
        case formulation_name
        case formulation_inventory_id
        case status
        case scheduled_at
        case created_at
        case address
        case latitude
        case longitude
        case total = "total_amount"
        case estimated_duration
        case started_at
        case completed_at
        case iv_start_time
        case iv_end_time
        case pre_vitals
        case during_vitals
        case post_vitals
        case drip_rate
        case clinical_notes
        case photos_paths
        case cancelled_at
        case cancellation_reason
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
