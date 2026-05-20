import Foundation

struct Visit: Identifiable, Codable, Equatable {
    let id: String
    let client_id: String
    var client_name: String?
    let service_type: String
    var status: VisitStatus
    let scheduled_at: Date
    let created_at: Date
    let address: String
    let latitude: Double?
    let longitude: Double?
    let notes: String?
    let total: Double
    var estimated_duration: Int?
    var copay: Double?
    var insurance_claimed: Bool?
    var started_at: Date?
    var completed_at: Date?

    enum VisitStatus: String, Codable, CaseIterable {
        case scheduled = "scheduled"
        case in_progress = "in_progress"
        case completed = "completed"
        case cancelled = "cancelled"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case client_id
        case client_name
        case service_type = "visit_type"
        case status
        case scheduled_at
        case created_at
        case address
        case latitude
        case longitude
        case notes
        case total = "total_amount"
        case estimated_duration
        case copay
        case insurance_claimed
        case started_at
        case completed_at
    }

    static func == (lhs: Visit, rhs: Visit) -> Bool {
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
