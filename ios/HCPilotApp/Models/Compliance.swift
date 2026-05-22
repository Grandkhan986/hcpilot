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

/// Licence d'exercice de la nurse (brief : RN/NP/LPN/MD/PA + état US).
struct LicenseInfo: Codable {
    let licenseNumber: String?
    let licenseType: String?
    let stateCode: String?
    let expirationDate: Date?
    let daysRemaining: Int?
    let status: ComplianceStatus
}

/// Medical Director qui supervise la nurse (réglementation US par État).
/// Brief : un seul MD actif à la fois.
/// Audit B2 : Equatable/Hashable basés sur `id`.
struct MedicalDirectorInfo: Codable, Identifiable, Hashable {
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

    static func == (lhs: MedicalDirectorInfo, rhs: MedicalDirectorInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Standing order signée par le Medical Director — autorise la nurse à
/// administrer une formulation IV donnée. Brief : version, date d'expiration.
/// Audit B2 : Equatable/Hashable basés sur `id`.
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

    static func == (lhs: StandingOrderInfo, rhs: StandingOrderInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Alerte de conformité (licence/MD/SO expiration, audit dû, etc.).
/// Brief : conserve l'horodatage triggered/acknowledged/resolved pour l'audit.
/// Audit B2 : Equatable/Hashable basés sur `id`.
struct ComplianceAlertInfo: Codable, Identifiable, Hashable {
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

    static func == (lhs: ComplianceAlertInfo, rhs: ComplianceAlertInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Agrégat de l'écran Conformité — réponse de `/compliance/dashboard`.
struct ComplianceDashboard: Codable {
    let license: LicenseInfo?
    let medicalDirector: MedicalDirectorInfo?
    let standingOrders: [StandingOrderInfo]
    let standingOrdersExpiringSoon: Int
    let alerts: [ComplianceAlertInfo]
    let unreadAlerts: Int
}
