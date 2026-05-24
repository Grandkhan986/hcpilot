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
    /// Idempotent (P-12) : si la session a déjà une invoice (rebuild possible
    /// depuis InvoiceLocalStore), retourne l'existante sans incrémenter le
    /// compteur de numéro ni régénérer le PDF.
    func generateInvoiceForCompletedSession(
        _ session: Session,
        practiceName: String?,
        nurseFullName: String?,
        clientFullName: String?,
        clientAddress: String?
    ) async throws -> Invoice {
        // Idempotence (P-12) : court-circuit si une invoice existe déjà pour
        // cette session. Évite les doublons de numéro et les incréments parasites
        // du compteur lors d'un retry ou d'un double-tap.
        if let existing = InvoiceLocalStore.shared.loadInvoice(forSession: session.id) {
            return existing
        }

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

        // P-14 — paymentMethod passe par l'enum (stub = .cash en attendant
        // Stripe Sprint 4). Le PDF utilise displayName pour éviter les
        // strings hardcodées qui divergent du model Invoice.
        let paymentMethod: Invoice.PaymentMethod = .cash

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
            paymentMethod: paymentMethod.displayName
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
            currency: "USD",
            items: [
                InvoiceItem(description: session.formulationName, quantity: 1, price: subtotal)
            ],
            paymentMethod: paymentMethod,
            dueDate: Date(),
            paidAt: nil,
            refundedAt: nil,
            refundAmount: nil,
            stripePaymentIntentId: nil,
            invoicePdfPath: localPath,
            createdAt: Date(),
            updatedAt: nil
        )

        // Persiste l'invoice localement AVANT le POST backend pour garantir
        // l'idempotence côté client même si le réseau échoue (le prochain appel
        // pour cette session sera court-circuité).
        InvoiceLocalStore.shared.recordInvoice(invoice, forSession: session.id)

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
