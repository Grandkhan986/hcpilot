import Foundation

struct Invoice: Identifiable, Hashable, Codable {
    let id: String
    let patient_id: String
    var patient_name: String?
    let visit_id: String?
    let invoice_number: String
    let status: InvoiceStatus
    let subtotal: Double?
    let tax: Double?
    let discount: Double?
    let total: Double
    let items: [InvoiceItem]?
    let due_date: String
    let paid_at: String?
    let stripe_payment_intent_id: String?
    let created_at: String
    let updated_at: String?

    enum InvoiceStatus: String, CaseIterable, Codable {
        case draft = "draft"
        case sent = "sent"
        case paid = "paid"
        case overdue = "overdue"
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
