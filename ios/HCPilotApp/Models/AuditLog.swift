import Foundation

/// Types d'entités tracées dans l'audit log HIPAA (audit H11).
enum AuditEntityType: String, Codable {
    case consents
    case clients
    case sessions
    case users
    case standingOrders = "standing_orders"
    case medicalDirectors = "medical_directors"
    case complianceAlerts = "compliance_alerts"
    case inventoryLots = "inventory_lots"
    case inventoryTransactions = "inventory_transactions"
    case unknown

    init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        self = AuditEntityType(rawValue: s) ?? .unknown
    }
}

/// Action loggée (audit H11).
enum AuditAction: String, Codable {
    case create
    case read
    case update
    case delete
    case export
    case unknown

    init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        self = AuditAction(rawValue: s) ?? .unknown
    }
}

/// Entrée immuable du journal d'audit. Brief §HIPAA : conservation 7 ans,
/// IP/UA capturées côté serveur. camelCase Swift / snake_case JSON.
/// Audit B2 : Equatable/Hashable basés sur `id`.
struct AuditLogEntry: Identifiable, Codable, Hashable {
    let id: String
    let nurseId: String?
    let entityType: AuditEntityType
    let entityId: String
    let action: AuditAction
    let changes: AnyJSONValue?
    let ipAddress: String?
    let userAgent: String?
    let occurredAt: Date

    static func == (lhs: AuditLogEntry, rhs: AuditLogEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Représentation décodable récursive de toute valeur JSON (audit H12).
indirect enum AnyJSONValue: Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([AnyJSONValue])
    case object([String: AnyJSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? c.decode(Int.self) {
            self = .int(i)
        } else if let d = try? c.decode(Double.self) {
            self = .double(d)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let arr = try? c.decode([AnyJSONValue].self) {
            self = .array(arr)
        } else if let obj = try? c.decode([String: AnyJSONValue].self) {
            self = .object(obj)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i): try c.encode(i)
        case .double(let d): try c.encode(d)
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    var displayString: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return String(b)
        case .null: return "null"
        case .array(let a): return "[" + a.map(\.displayString).joined(separator: ", ") + "]"
        case .object(let o):
            let pairs = o.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value.displayString)" }
            return "{" + pairs.joined(separator: ", ") + "}"
        }
    }

    var asObject: [String: AnyJSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }
}
