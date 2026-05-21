import Foundation

/// Une session IV : ce que la nurse effectue chez le client.
/// Brief `sessions`. Modèle private pay — pas de copay/insurance.
/// camelCase Swift / snake_case JSON via APIService global strategy.
struct Session: Identifiable, Codable, Equatable {
    let id: String
    let clientId: String
    let nurseId: String
    var clientName: String?
    let formulationName: String
    let formulationInventoryId: String?  // FK lot inventaire — traçabilité FDA
    var status: SessionStatus
    let scheduledAt: Date
    let createdAt: Date
    let address: String
    let latitude: Double?
    let longitude: Double?
    let totalAmount: Double
    var estimatedDuration: Int?
    // Clock-in / clock-out session entière
    var startedAt: Date?
    var completedAt: Date?
    // Heures effectives de la perfusion IV
    var ivStartTime: Date?
    var ivEndTime: Date?
    // Vitals : jsonb libre `{"bp_sys": 120, "bp_dia": 80, "hr": 72, ...}`
    var preVitals: [String: String]?
    var duringVitals: [String: String]?
    var postVitals: [String: String]?
    var dripRate: String?
    var clinicalNotes: String?
    var photosPaths: [String]
    var cancelledAt: Date?
    var cancellationReason: String?

    /// Cycle de vie (brief : 6 statuts).
    /// scheduled → en_route → in_progress → completed
    /// scheduled → cancelled
    /// scheduled → no_show
    enum SessionStatus: String, Codable, CaseIterable {
        case scheduled
        case enRoute = "en_route"
        case inProgress = "in_progress"
        case completed
        case cancelled
        case noShow = "no_show"
    }

    static func == (lhs: Session, rhs: Session) -> Bool {
        lhs.id == rhs.id
    }
}
