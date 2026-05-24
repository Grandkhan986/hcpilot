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
    /// L2-2 — devise ISO 4217. Optionnelle pour rétro-compat avec les
    /// payloads existants (backend mock + invoices déjà persistées sans
    /// currency). `effectiveCurrency` retourne USD par défaut.
    let currency: String?
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

    /// L2-2 — devise effective. Stripe Connect (Sprint 4) exigera ce champ
    /// par invoice ; en attendant on défaulte USD car la cible HCPilot
    /// (nurses IV mobiles) est US-only.
    var effectiveCurrency: String { currency ?? "USD" }

    enum InvoiceStatus: String, CaseIterable, Codable {
        case draft
        case sent
        case paid
        case overdue
        case refunded
        case partialRefund = "partial_refund"
        case cancelled

        /// L2-25 — Mapping vers les statuts Stripe Invoice (Sprint 4 prep).
        /// Stripe Invoice statuses : draft, open, paid, void, uncollectible.
        /// `refunded` / `partialRefund` n'ont pas d'équivalent direct au
        /// niveau Stripe Invoice (les remboursements vivent sur le PaymentIntent),
        /// on les mappe sur `paid` côté Stripe + on garde le détail localement.
        var stripeStatus: String {
            switch self {
            case .draft: return "draft"
            case .sent: return "open"
            case .paid, .refunded, .partialRefund: return "paid"
            case .overdue: return "uncollectible"
            case .cancelled: return "void"
            }
        }
    }

    /// Modes de paiement supportés par Stripe Connect Express + saisie cash
    /// hors plateforme (rare mais possible pour les tips terrain).
    /// L2-31 — Ajout `check` et `wireTransfer` (cas IV mobile : factures pro
    /// avec règlement à 30j par chèque ou virement).
    enum PaymentMethod: String, CaseIterable, Codable {
        case card
        case applePay = "apple_pay"
        case googlePay = "google_pay"
        case ach
        case cash
        case check
        case wireTransfer = "wire_transfer"
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
    /// L2-14 — id UUID stable. Avant : synthétique `"\(description)-\(quantity)"`
    /// → deux items identiques (deux "Vitamin C × 1") collisionnaient l'id et
    /// SwiftUI ForEach loguait un warning + état UI partagé.
    let id: String
    let description: String
    let quantity: Int
    let price: Double

    init(id: String = UUID().uuidString, description: String, quantity: Int, price: Double) {
        self.id = id
        self.description = description
        self.quantity = quantity
        self.price = price
    }

    private enum CodingKeys: String, CodingKey { case id, description, quantity, price }

    /// Décode tolérant : `id` absent → UUID généré (rétrocompat avec payloads
    /// historiques qui n'avaient pas d'id).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.description = try c.decode(String.self, forKey: .description)
        self.quantity = try c.decode(Int.self, forKey: .quantity)
        self.price = try c.decode(Double.self, forKey: .price)
    }
}

// MARK: - PaymentMethod helpers

extension Invoice.PaymentMethod {
    /// P-14 — Libellé d'affichage pour le PDF de facture et toute UI exposant
    /// le mode de paiement à la nurse / au client. Centralise les chaînes
    /// pour éviter les divergences (typos, casse) entre PDF, écran et serveur.
    var displayName: String {
        switch self {
        case .card: return "Card"
        case .applePay: return "Apple Pay"
        case .googlePay: return "Google Pay"
        case .ach: return "ACH"
        case .cash: return "Cash"
        case .check: return "Check"
        case .wireTransfer: return "Wire Transfer"
        case .other: return "Other"
        }
    }
}
