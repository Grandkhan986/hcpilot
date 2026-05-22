import Foundation

/// Un lot d'inventaire — granularité per-batch alignée brief (traçabilité FDA).
/// camelCase Swift / snake_case JSON via APIService global strategy.
/// Audit B2 : Equatable/Hashable basés sur `id`.
struct InventoryLot: Identifiable, Codable, Hashable {
    let id: String
    let nurseId: String
    let productName: String
    let productCategory: String
    let barcode: String?
    let lotNumber: String
    let expirationDate: Date
    let quantityInitial: Int
    var quantityRemaining: Int
    let unitCost: Double?
    let supplier: String?
    let receivedAt: Date
    let notes: String?
    let createdAt: Date
    /// Audit M5 — mutable (qty décrémentée à l'usage).
    var updatedAt: Date?
    /// Audit M6 — soft delete pour rappels FDA (`recall`) sans perdre l'audit
    /// trail des sessions qui ont utilisé ce lot.
    var archivedAt: Date?
    let expirationStatus: ComplianceStatus?
    let daysToExpiry: Int?

    var isArchived: Bool { archivedAt != nil }

    static func == (lhs: InventoryLot, rhs: InventoryLot) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Agrégation d'inventaire par référence produit (vue liste).
struct InventoryProduct: Identifiable, Codable, Hashable {
    var id: String { productName }
    let productName: String
    let productCategory: String
    let barcode: String?
    let totalQuantity: Int
    let lotCount: Int
    let nearestExpiration: Date
    let totalValue: Double
    let expirationStatus: ComplianceStatus
}

/// Représentation allégée renvoyée par /reports/dashboard.lowStockItems.
struct LowStockProduct: Identifiable, Codable, Hashable {
    var id: String { productName }
    let productName: String
    let productCategory: String
    let totalQuantity: Int
    let nearestExpiration: Date
}

/// Mouvement de stock immuable (audit trail brief + traçabilité FDA).
/// Audit B2 : Equatable/Hashable basés sur `id`.
struct InventoryTransaction: Identifiable, Codable, Hashable {
    let id: String
    let inventoryLotId: String
    let sessionId: String?
    let transactionType: String
    let quantityChange: Int
    let notes: String?
    let createdAt: Date

    static func == (lhs: InventoryTransaction, rhs: InventoryTransaction) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct CreateLotRequest: Encodable {
    let productName: String
    let productCategory: String
    let barcode: String?
    let lotNumber: String
    let expirationDate: String  // serveur attend YYYY-MM-DD
    let quantityInitial: Int
    let unitCost: Double?
    let supplier: String?
    let receivedAt: String?  // YYYY-MM-DD
    let notes: String?
}

struct RecordUsageRequest: Encodable {
    let lotId: String
    let sessionId: String?
    let quantity: Int
    let notes: String?
}

struct RecordUsageResponse: Decodable {
    let lot: InventoryLot
    let transaction: InventoryTransaction
}
