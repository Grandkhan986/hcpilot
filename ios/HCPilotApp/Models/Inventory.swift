import Foundation

/// Un lot d'inventaire — granularité per-batch alignée brief.
/// camelCase Swift / snake_case JSON via APIService global strategy.
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
    let expirationStatus: ComplianceStatus?
    let daysToExpiry: Int?
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

struct InventoryTransaction: Identifiable, Codable, Hashable {
    let id: String
    let inventoryLotId: String
    let sessionId: String?
    let transactionType: String
    let quantityChange: Int
    let notes: String?
    let createdAt: Date
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
