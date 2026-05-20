import Foundation

struct ConsentCheckpoint: Codable, Hashable, Identifiable {
    let label: String
    var accepted: Bool

    var id: String { label }
}

/// Métadonnées d'un consentement signé (sans le blob signature/PDF).
struct ConsentSummary: Identifiable, Codable {
    let id: String
    let session_id: String
    let client_id: String
    let nurse_id: String
    let formulation_name: String
    let checkpoints: [ConsentCheckpoint]
    let signed_at: String
    let signed_latitude: Double?
    let signed_longitude: Double?
    let ip_address: String?
    let device_info: [String: String]?
    let has_pdf: Bool
    let created_at: String
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
