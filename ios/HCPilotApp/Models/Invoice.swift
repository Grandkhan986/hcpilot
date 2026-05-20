import Foundation

struct Invoice: Identifiable, Hashable, Codable {
    let id: String
    let client_id: String
    var client_name: String?
    let session_id: String?
    let invoice_number: String
    let status: InvoiceStatus
    let subtotal: Double?
    let tax: Double?
    let discount: Double?
    let total: Double
    let items: [InvoiceItem]?
    let due_date: Date
    let paid_at: Date?
    let stripe_payment_intent_id: String?
    let created_at: Date
    let updated_at: Date?

    enum InvoiceStatus: String, CaseIterable, Codable {
        case draft = "draft"
        case sent = "sent"
        case paid = "paid"
        case overdue = "overdue"
        case refunded = "refunded"
        case partial_refund = "partial_refund"
        case cancelled = "cancelled"
    }

    static func == (lhs: Invoice, rhs: Invoice) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct InvoiceItem: Identifiable, Hashable, Codable {
    var id: String { "\(description)-\(quantity)" }
    let description: String
    let quantity: Int
    let price: Double

    enum CodingKeys: String, CodingKey {
        case description
        case quantity
        case price
    }
}
