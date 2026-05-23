import Foundation

/// Facture liée à une session. Brief : private pay via Stripe Connect Express
/// (commission 0,99 $). camelCase Swift / snake_case JSON via APIService.
///
/// Audit H10 : tip, travel fee, payment method et traçabilité refund sont
/// explicités — sinon la facture ne reflète pas réellement ce qui a été perçu
/// (les nurses IV mobiles facturent souvent tip + déplacement).
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
    let tipAmount: Double?
    let travelFeeAmount: Double?
    let total: Double
    let items: [InvoiceItem]?
    let paymentMethod: PaymentMethod?
    let dueDate: Date
    let paidAt: Date?
    let refundedAt: Date?
    let refundAmount: Double?
    let stripePaymentIntentId: String?
    /// C-63 (stub) — chemin local du PDF généré à la complétion de session.
    /// Sera remplacé par un path Supabase Storage en Sprint 4 Stripe.
    let invoicePdfPath: String?
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

    /// Modes de paiement supportés par Stripe Connect Express + saisie cash
    /// hors plateforme (rare mais possible pour les tips terrain).
    enum PaymentMethod: String, CaseIterable, Codable {
        case card
        case applePay = "apple_pay"
        case googlePay = "google_pay"
        case ach
        case cash
        case other
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
