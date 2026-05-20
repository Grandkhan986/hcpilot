import Foundation

struct AuditLogEntry: Identifiable, Codable {
    let id: String
    let nurse_id: String?
    let entity_type: String  // consents | clients | sessions | inventory_transactions
    let entity_id: String
    let action: String       // create | read | update | delete | export
    let changes: [String: AnyDecodable]?
    let ip_address: String?
    let user_agent: String?
    let occurred_at: String
}

/// Wrapper minimal pour décoder les `changes` qui peuvent contenir n'importe
/// quel JSON (string, int, bool, dict, array, null). On affiche en string.
struct AnyDecodable: Codable {
    let value: String

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            value = s
        } else if let i = try? c.decode(Int.self) {
            value = String(i)
        } else if let d = try? c.decode(Double.self) {
            value = String(d)
        } else if let b = try? c.decode(Bool.self) {
            value = String(b)
        } else if c.decodeNil() {
            value = "null"
        } else {
            value = "—"
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}
