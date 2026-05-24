import Foundation

/// L2-13 — Vitals typés (BP/HR/SpO2 en Int) plutôt qu'un dict opaque
/// `[String: String]`. Custom Codable pour rester compatible avec le
/// backend qui stocke encore les vitals comme JSONB dict snake_case.
struct Vitals: Codable, Equatable {
    var bpSystolic: Int?
    var bpDiastolic: Int?
    var heartRate: Int?
    var spo2: Int?
    var notes: String?
    var capturedAt: Date?

    init(bpSystolic: Int? = nil, bpDiastolic: Int? = nil, heartRate: Int? = nil,
         spo2: Int? = nil, notes: String? = nil, capturedAt: Date? = nil) {
        self.bpSystolic = bpSystolic
        self.bpDiastolic = bpDiastolic
        self.heartRate = heartRate
        self.spo2 = spo2
        self.notes = notes
        self.capturedAt = capturedAt
    }

    init(dict: [String: String]) {
        self.bpSystolic = dict["bp_systolic"].flatMap(Int.init)
        self.bpDiastolic = dict["bp_diastolic"].flatMap(Int.init)
        self.heartRate = dict["heart_rate"].flatMap(Int.init)
        self.spo2 = dict["spo2"].flatMap(Int.init)
        self.notes = dict["notes"]
        if let ts = dict["captured_at"] {
            self.capturedAt = ISO8601DateFormatter().date(from: ts)
        }
    }

    var asDict: [String: String] {
        var dict: [String: String] = [:]
        if let v = bpSystolic { dict["bp_systolic"] = "\(v)" }
        if let v = bpDiastolic { dict["bp_diastolic"] = "\(v)" }
        if let v = heartRate { dict["heart_rate"] = "\(v)" }
        if let v = spo2 { dict["spo2"] = "\(v)" }
        if let n = notes, !n.isEmpty { dict["notes"] = n }
        if let t = capturedAt {
            dict["captured_at"] = ISO8601DateFormatter().string(from: t)
        }
        return dict
    }

    var isEmpty: Bool {
        bpSystolic == nil && bpDiastolic == nil && heartRate == nil && spo2 == nil
            && (notes ?? "").isEmpty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: String].self)
        self.init(dict: dict)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(asDict)
    }
}

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
    // L2-13 — Vitals typés (Vitals struct) avec mapping bi-directionnel
    // vers le dict snake_case stocké côté backend.
    var preVitals: Vitals?
    var duringVitals: Vitals?
    var postVitals: Vitals?
    var dripRate: String?
    var clinicalNotes: String?
    var photosPaths: [String]
    var cancelledAt: Date?
    var cancellationReason: String?
    /// Audit M5 : updatedAt présent sur tous les Models mutables (utilisé par
    /// MutationQueue pour le last-write-wins, et pour les sync conflicts).
    var updatedAt: Date?

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
