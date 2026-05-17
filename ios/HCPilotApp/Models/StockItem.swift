import Foundation

struct StockItem: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let category: String
    var quantity: Int
    let min_quantity: Int
    let description: String?
    let expiration_date: String?
    let barcode: String?
    let cost_per_unit: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name = "product_name"
        case category
        case quantity
        case min_quantity
        case description
        case expiration_date
        case barcode
        case cost_per_unit
    }

    var isLowStock: Bool {
        quantity <= min_quantity
    }
}
