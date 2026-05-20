import Foundation

/// Statut visuel d'une licence/contrat/standing order selon proximité de
/// l'expiration. Brief seuils : 90j / 30j / 15j (audit H6).
enum ComplianceStatus: String, Codable {
    case ok          // > 90j
    case warning     // 30-90j
    case critical    // < 30j
    case expired     // passé
    case unknown
}

/// Sévérité d'une alerte (audit H6).
enum AlertSeverity: String, Codable {
    case info
    case warning
    case critical
}

struct LicenseInfo: Codable {
    let license_number: String?
    let license_type: String?
    let state_code: String?
    let expiration_date: Date?
    let days_remaining: Int?
    let status: ComplianceStatus
}

struct MedicalDirectorInfo: Codable, Identifiable {
    let id: String
    let nurse_id: String
    let first_name: String
    let last_name: String
    let email: String
    let license_number: String
    let state_code: String
    let contract_start_date: Date
    let contract_end_date: Date?
    let audit_frequency_days: Int
    let next_audit_date: Date?
    let is_active: Bool
    let contract_status: ComplianceStatus?
    let next_audit_status: ComplianceStatus?

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
    let signed_at: Date?
    let expires_at: Date?
    let is_active: Bool
    let expiration_status: ComplianceStatus?
}

struct ComplianceAlertInfo: Codable, Identifiable {
    let id: String
    let nurse_id: String
    let alert_type: String
    let severity: AlertSeverity
    let title: String
    let description: String
    let related_entity_id: String?
    let triggered_at: Date
    let acknowledged_at: Date?
    let resolved_at: Date?
}

struct ComplianceDashboard: Codable {
    let license: LicenseInfo?
    let medical_director: MedicalDirectorInfo?
    let standing_orders: [StandingOrderInfo]
    let standing_orders_expiring_soon: Int
    let alerts: [ComplianceAlertInfo]
    let unread_alerts: Int
}
