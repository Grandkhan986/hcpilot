import Foundation

/// Une case à cocher du consentement éclairé. L'`id` est un UUID stable
/// distinct du `label` (audit H8 : éviter les collisions si deux labels
/// identiques co-existent).
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

/// Métadonnées d'un consentement signé (sans le blob signature/PDF).
/// Brief schema `consents` — toutes les dates sont en Date (audit H1).
struct ConsentSummary: Identifiable, Codable {
    let id: String
    let session_id: String
    let client_id: String
    let nurse_id: String
    let standing_order_id: String?
    let formulation_name: String
    let checkpoints: [ConsentCheckpoint]
    let signed_at: Date
    let signed_latitude: Double?
    let signed_longitude: Double?
    let ip_address: String?
    let device_info: [String: String]?
    let has_pdf: Bool
    let created_at: Date
}

struct CreateConsentRequest: Encodable {
    let session_id: String
    let standing_order_id: String
    let checkpoints: [ConsentCheckpoint]
    let signature_image_b64: String
    let pdf_b64: String?
    let signed_latitude: Double?
    let signed_longitude: Double?
    let device_info: [String: String]?
}
