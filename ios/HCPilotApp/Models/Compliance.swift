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
    let licenseNumber: String?
    let licenseType: String?
    let stateCode: String?
    let expirationDate: Date?
    let daysRemaining: Int?
    let status: ComplianceStatus
}

struct MedicalDirectorInfo: Codable, Identifiable {
    let id: String
    let nurseId: String
    let firstName: String
    let lastName: String
    let email: String
    let licenseNumber: String
    let stateCode: String
    let contractStartDate: Date
    let contractEndDate: Date?
    let auditFrequencyDays: Int
    let nextAuditDate: Date?
    let isActive: Bool
    let contractStatus: ComplianceStatus?
    let nextAuditStatus: ComplianceStatus?

    var fullName: String { "\(firstName) \(lastName)" }
}

struct StandingOrderInfo: Codable, Identifiable, Hashable {
    let id: String
    let nurseId: String
    let medicalDirectorId: String?
    let formulationName: String
    let formulationCategory: String
    let consentText: String?
    let version: Int
    let signedAt: Date?
    let expiresAt: Date?
    let isActive: Bool
    let expirationStatus: ComplianceStatus?
}

struct ComplianceAlertInfo: Codable, Identifiable {
    let id: String
    let nurseId: String
    let alertType: String
    let severity: AlertSeverity
    let title: String
    let description: String
    let relatedEntityId: String?
    let triggeredAt: Date
    let acknowledgedAt: Date?
    let resolvedAt: Date?
}

struct ComplianceDashboard: Codable {
    let license: LicenseInfo?
    let medicalDirector: MedicalDirectorInfo?
    let standingOrders: [StandingOrderInfo]
    let standingOrdersExpiringSoon: Int
    let alerts: [ComplianceAlertInfo]
    let unreadAlerts: Int
}
