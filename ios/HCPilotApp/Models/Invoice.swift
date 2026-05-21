import Foundation

/// Facture liée à une session. Brief : private pay via Stripe Connect Express
/// (commission 0,99 $). camelCase Swift / snake_case JSON via APIService.
struct Invoice: Identifiable, Hashable, Codable {
    let id: String
    let clientId: String
    var clientName: String?
    let sessionId: String?
    let invoiceNumber: String
    let status: InvoiceStatus
    let subtotal: Double?
    let tax: Double?
    let discount: Double?
    let total: Double
    let items: [InvoiceItem]?
    let dueDate: Date
    let paidAt: Date?
    let stripePaymentIntentId: String?
    let createdAt: Date
    let updatedAt: Date?

    enum InvoiceStatus: String, CaseIterable, Codable {
        case draft
        case sent
        case paid
        case overdue
        case refunded
        case partialRefund = "partial_refund"
        case cancelled
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
}
