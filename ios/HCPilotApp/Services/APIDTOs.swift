import Foundation

/// Data Transfer Objects (DTOs) used by `APIService`. Extracted from
/// `APIService.swift` (audit B4) to keep the service file focused on
/// request orchestration. Types remain namespaced under `APIService` so
/// existing call sites (`APIService.ClientPatch`, `APIService.SessionPatch`,
/// etc.) compile unchanged.
extension APIService {

    // MARK: - Auth

    struct LoginResponse: Decodable {
        let accessToken: String
        let tokenType: String
        let user: UserProfile
    }

    // MARK: - Sessions

    /// Patch partiel d'une session (PATCH-like). Aligné brief : champs cliniques
    /// vitals, dripRate, IV times pour saisie pendant/après la perfusion.
    struct SessionPatch: Encodable {
        var formulationName: String?
        var formulationInventoryId: String?
        var scheduledAt: Date?
        var address: String?
        var latitude: Double?
        var longitude: Double?
        var clinicalNotes: String?
        var estimatedDuration: Int?
        var totalAmount: Double?
        var ivStartTime: Date?
        var ivEndTime: Date?
        var preVitals: [String: String]?
        var duringVitals: [String: String]?
        var postVitals: [String: String]?
        var dripRate: String?
        var cancellationReason: String?
    }

    // MARK: - Clients

    /// Patch envoyé sur PUT /clients/{id}. Tous champs Optional :
    /// - nil  → champ non touché côté backend (filtré)
    /// - ""   → champ vidé
    /// Aligné sur le brief schema `clients` (adresse splittée en 5 champs,
    /// allergies/medicalConditions/medications en arrays).
    struct ClientPatch: Encodable {
        var firstName: String?
        var lastName: String?
        var email: String?
        var phone: String?
        var dateOfBirth: String?
        var gender: String?
        var addressLine1: String?
        var addressLine2: String?
        var city: String?
        var stateCode: String?
        var postalCode: String?
        var accessNotes: String?
        var allergies: [String]?
        var medicalConditions: [String]?
        var medications: [String]?
        var emergencyContactName: String?
        var emergencyContactPhone: String?
    }

    /// Réponse de PUT /clients/{id} : client mis à jour + nb sessions futures
    /// resync'ées suite à un changement d'adresse.
    struct UpdatedClientResponse: Decodable {
        let id: String
        let firstName: String
        let lastName: String
        let addressLine1: String?
        let city: String?
        let stateCode: String?
        let postalCode: String?
        let latitude: Double?
        let longitude: Double?
        let archivedAt: String?
        let syncedFutureSessions: Int?
    }

    /// Soft-delete : archive le client.
    /// Renvoie le nombre de sessions planifiées supprimées.
    struct ArchiveClientResponse: Decodable {
        let message: String
        let clientId: String
        let deletedScheduledSessions: Int
    }

    // MARK: - Reports

    struct DashboardResponse: Decodable {
        let totalClients: Int
        let today_visits: Int
        let pendingInvoices: Int
        let lowStockAlerts: Int
        let monthlyRevenue: Double
        let sessionsToday: [Session]
        let lowStockItems: [LowStockProduct]
    }

    struct RevenueResponse: Decodable {
        let total_revenue: Double
        let total_visits: Int
        let average_visit_value: Double
        let by_visit_type: [String: Double]
    }

    // MARK: - Onboarding

    struct UpdatePracticeRequest: Encodable {
        var firstName: String?
        var lastName: String?
        var phone: String?
        var stateCode: String?
        var licenseNumber: String?
        var licenseExpirationDate: String?
        var licenseType: String?
        var practiceName: String?
        var npiNumber: String?
    }

    struct PracticeResponse: Decodable {
        let userId: String
        let stateCode: String?
        let licenseNumber: String?
        let licenseExpirationDate: String?
        let licenseType: String?
        let practiceName: String?
        let npiNumber: String?
    }

    struct CreateMedicalDirectorRequest: Encodable {
        let firstName: String
        let lastName: String
        let email: String
        let licenseNumber: String
        let stateCode: String
        let contractStartDate: String
        let contractEndDate: String?
        let auditFrequencyDays: Int
        let nextAuditDate: String?
    }

    struct CreateStandingOrderRequest: Encodable {
        let formulationName: String
        let medicalDirectorId: String?
        let expiresAt: String?
    }

    // MARK: - Consents

    /// Renvoie le PDF base64 du consentement.
    struct ConsentPDFResponse: Decodable {
        let pdfB64: String
    }

    // MARK: - Route Optimization

    struct OptimizedStop: Decodable {
        let sessionId: String
        let order: Int
    }

    struct OptimizedRouteResponse: Decodable {
        let optimizedRoute: [OptimizedStop]
        /// Polyline points as [longitude, latitude] pairs (GeoJSON LineString order).
        let routeGeometry: [[Double]]?
        let totalDistanceM: Double
        let totalDurationS: Double
        let warning: String?
    }
}
