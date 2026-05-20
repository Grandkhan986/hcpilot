import Foundation

/// Un lot d'inventaire — granularité per-batch alignée brief.
struct InventoryLot: Identifiable, Codable, Hashable {
    let id: String
    let nurse_id: String
    let product_name: String
    let product_category: String
    let barcode: String?
    let lot_number: String
    let expiration_date: String
    let quantity_initial: Int
    var quantity_remaining: Int
    let unit_cost: Double?
    let supplier: String?
    let received_at: String
    let notes: String?
    let created_at: String
    let expiration_status: String?  // ok | warning | critical | expired
    let days_to_expiry: Int?
}

/// Agrégation d'inventaire par référence produit (vue liste).
struct InventoryProduct: Identifiable, Codable, Hashable {
    var id: String { product_name }
    let product_name: String
    let product_category: String
    let barcode: String?
    let total_quantity: Int
    let lot_count: Int
    let nearest_expiration: String
    let total_value: Double
    let expiration_status: String
}

/// Représentation allégée renvoyée par /reports/dashboard.low_stock_items.
struct LowStockProduct: Identifiable, Codable, Hashable {
    var id: String { product_name }
    let product_name: String
    let product_category: String
    let total_quantity: Int
    let nearest_expiration: String
}

struct InventoryTransaction: Identifiable, Codable, Hashable {
    let id: String
    let inventory_lot_id: String
    let session_id: String?
    let transaction_type: String
    let quantity_change: Int
    let notes: String?
    let created_at: String
}

struct CreateLotRequest: Encodable {
    let product_name: String
    let product_category: String
    let barcode: String?
    let lot_number: String
    let expiration_date: String
    let quantity_initial: Int
    let unit_cost: Double?
    let supplier: String?
    let received_at: String?
    let notes: String?
}

struct RecordUsageRequest: Encodable {
    let lot_id: String
    let session_id: String?
    let quantity: Int
    let notes: String?
}

struct RecordUsageResponse: Decodable {
    let lot: InventoryLot
    let transaction: InventoryTransaction
}
