import Foundation

struct LicenseInfo: Codable {
    let license_number: String?
    let license_type: String?
    let state_code: String?
    let expiration_date: String?
    let days_remaining: Int?
    let status: String  // ok | warning | critical | expired | unknown
}

struct MedicalDirectorInfo: Codable, Identifiable {
    let id: String
    let nurse_id: String
    let first_name: String
    let last_name: String
    let email: String
    let license_number: String
    let state_code: String
    let contract_start_date: String
    let contract_end_date: String?
    let audit_frequency_days: Int
    let next_audit_date: String?
    let is_active: Bool
    let contract_status: String?
    let next_audit_status: String?

    var full_name: String { "\(first_name) \(last_name)" }
}

struct StandingOrderInfo: Codable, Identifiable, Hashable {
    let id: String
    let nurse_id: String
    let medical_director_id: String?
    let formulation_name: String
    let formulation_category: String
    let consent_text: String?
    let version: Int
    let signed_at: String?
    let expires_at: String?
    let is_active: Bool
    let expiration_status: String?
}

struct ComplianceAlertInfo: Codable, Identifiable {
    let id: String
    let nurse_id: String
    let alert_type: String
    let severity: String  // info | warning | critical
    let title: String
    let description: String
    let related_entity_id: String?
    let triggered_at: String
    let acknowledged_at: String?
    let resolved_at: String?
}

struct ComplianceDashboard: Codable {
    let license: LicenseInfo?
    let medical_director: MedicalDirectorInfo?
    let standing_orders: [StandingOrderInfo]
    let standing_orders_expiring_soon: Int
    let alerts: [ComplianceAlertInfo]
    let unread_alerts: Int
}
