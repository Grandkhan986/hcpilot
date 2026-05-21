import Foundation

/// Une case à cocher du consentement éclairé.
/// `id` UUID distinct du `label` (audit H8).
struct ConsentCheckpoint: Codable, Hashable, Identifiable {
    let id: String
    let label: String
    var accepted: Bool

    init(id: String = UUID().uuidString, label: String, accepted: Bool) {
        self.id = id
        self.label = label
        self.accepted = accepted
    }
}

/// Métadonnées d'un consentement signé. Brief `consents`.
/// camelCase Swift / snake_case JSON via APIService global strategy.
struct ConsentSummary: Identifiable, Codable {
    let id: String
    let sessionId: String
    let clientId: String
    let nurseId: String
    let standingOrderId: String?
    let formulationName: String
    let checkpoints: [ConsentCheckpoint]
    let signedAt: Date
    let signedLatitude: Double?
    let signedLongitude: Double?
    let ipAddress: String?
    let deviceInfo: [String: String]?
    let hasPdf: Bool
    let createdAt: Date
}

struct CreateConsentRequest: Encodable {
    let sessionId: String
    let standingOrderId: String
    let checkpoints: [ConsentCheckpoint]
    let signatureImageB64: String
    let pdfB64: String?
    let signedLatitude: Double?
    let signedLongitude: Double?
    let deviceInfo: [String: String]?
}
