import Foundation

struct Patient: Identifiable, Hashable, Codable {
    let id: String
    let first_name: String
    let last_name: String
    let email: String?
    let phone: String?
    let address: String?
    let latitude: Double?
    let longitude: Double?
    let date_of_birth: String?
    let gender: String?
    let medical_history: String?
    let allergies: String?
    let archived_at: String?
    let created_at: String
    let updated_at: String?

    var isArchived: Bool { archived_at != nil }

    var full_name: String {
        "\(first_name) \(last_name)"
    }

    var initials: String {
        "\(first_name.prefix(1))\(last_name.prefix(1))"
    }
}
