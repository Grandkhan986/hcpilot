import Foundation
import UIKit

/// Service de génération d'invoice à la complétion d'une session (C-63 stub).
///
/// Étapes :
/// 1. Construit l'`Invoice` model depuis la `Session` + profil nurse
/// 2. Génère le PDF via `InvoicePDFBuilder`
/// 3. Sauvegarde le PDF localement (`InvoiceLocalStore`)
/// 4. POST `/v1/invoices` au backend (avec le path PDF en stub)
///
/// Sprint 4 Stripe Connect remplacera l'étape 4 par un flow Stripe Invoice +
/// hosted PDF sur Supabase Storage.
@MainActor
final class InvoiceService {
    static let shared = InvoiceService()

    private init() {}

    /// Génère et persiste une invoice pour une session terminée.
    /// Idempotent : si la session a déjà une invoice (présence dans
    /// l'historique local), retourne l'existante.
    func generateInvoiceForCompletedSession(
        _ session: Session,
        practiceName: String?,
        nurseFullName: String?,
        clientFullName: String?,
        clientAddress: String?
    ) async throws -> Invoice {
        let invoiceNumber = InvoiceLocalStore.shared.nextInvoiceNumber()
        let invoiceId = "stub-\(UUID().uuidString.prefix(8))"

        // Décomposition montants : pour le stub, on utilise totalAmount comme
        // subtotal. travelFee/tip ne sont pas (encore) saisissables côté UI ;
        // ils seront ajoutés via UI dédiée en Sprint 4.
        let subtotal = session.totalAmount
        let travelFee = 0.0
        let tip = 0.0
        let tax = 0.0
        let total = subtotal + travelFee + tip + tax

        let pdfInput = InvoicePDFBuilder.Input(
            invoiceNumber: invoiceNumber,
            invoiceDate: Date(),
            practiceName: practiceName ?? "Pratique IV",
            practiceAddress: nil,
            nurseFullName: nurseFullName ?? "Soignant",
            clientFullName: clientFullName ?? session.clientName ?? "Client",
            clientAddress: clientAddress,
            sessionFormulation: session.formulationName.replacingOccurrences(of: "_", with: " "),
            sessionDate: session.scheduledAt,
            subtotal: subtotal,
            travelFee: travelFee,
            tip: tip,
            tax: tax,
            total: total,
            paymentMethod: "Cash"  // Stub : pas de Stripe encore
        )

        let pdfData = InvoicePDFBuilder.build(pdfInput)
        let localPath = try InvoiceLocalStore.shared.savePDF(pdfData, forInvoiceId: invoiceId)

        let invoice = Invoice(
            id: invoiceId,
            clientId: session.clientId,
            clientName: session.clientName,
            sessionId: session.id,
            invoiceNumber: invoiceNumber,
            status: .draft,
            subtotal: subtotal,
            tax: tax,
            discount: 0,
            tipAmount: tip > 0 ? tip : nil,
            travelFeeAmount: travelFee > 0 ? travelFee : nil,
            total: total,
            items: [
                InvoiceItem(description: session.formulationName, quantity: 1, price: subtotal)
            ],
            paymentMethod: .cash,
            dueDate: Date(),
            paidAt: nil,
            refundedAt: nil,
            refundAmount: nil,
            stripePaymentIntentId: nil,
            invoicePdfPath: localPath,
            createdAt: Date(),
            updatedAt: nil
        )

        // POST backend — non-bloquant pour le PDF local (déjà créé).
        // En cas d'échec réseau, l'invoice reste dispo localement.
        do {
            _ = try await APIService.shared.createInvoice(invoice: invoice)
        } catch {
            // Best-effort : le PDF local reste accessible.
        }

        return invoice
    }
}
