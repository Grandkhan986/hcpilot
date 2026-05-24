import XCTest
@testable import HCPilotApp

/// P-12 — Idempotence de InvoiceService.generateInvoiceForCompletedSession.
/// Garantit qu'un retry / double-tap / restart au milieu du flow ne produit
/// pas de doublons (même invoiceId, même invoiceNumber, sans incrémenter le
/// compteur séquentiel).
@MainActor
final class InvoiceServiceIdempotenceTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        InvoiceLocalStore.shared.resetForTests()
    }

    override func tearDown() async throws {
        InvoiceLocalStore.shared.resetForTests()
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeSession(id: String, total: Double = 175) -> Session {
        Session(
            id: id,
            clientId: "pat_001",
            nurseId: "usr_001",
            clientName: "Jean Martin",
            formulationName: "Myers_Cocktail",
            formulationInventoryId: nil,
            status: .completed,
            scheduledAt: Date(timeIntervalSince1970: 1716393600),
            createdAt: Date(timeIntervalSince1970: 1716393600),
            address: "12 Rue de la Paix",
            latitude: 48.86,
            longitude: 2.33,
            totalAmount: total,
            estimatedDuration: 60,
            startedAt: nil,
            completedAt: nil,
            ivStartTime: nil,
            ivEndTime: nil,
            preVitals: nil,
            duringVitals: nil,
            postVitals: nil,
            dripRate: nil,
            clinicalNotes: nil,
            photosPaths: [],
            cancelledAt: nil,
            cancellationReason: nil,
            updatedAt: nil
        )
    }

    private func generate(_ session: Session) async throws -> Invoice {
        try await InvoiceService.shared.generateInvoiceForCompletedSession(
            session,
            practiceName: "Wellness IV",
            nurseFullName: "Marie Dupont",
            clientFullName: session.clientName,
            clientAddress: nil
        )
    }

    // MARK: - Tests

    /// Premier appel pour une session → invoice nouvellement créée.
    /// Deuxième appel pour LA MÊME session → exact même invoice (id, numéro, montant).
    func test_idempotent_same_session_returns_same_invoice() async throws {
        let s = makeSession(id: "vis_X")
        let i1 = try await generate(s)
        let i2 = try await generate(s)

        XCTAssertEqual(i1.id, i2.id, "L'invoiceId doit être identique entre les 2 appels")
        XCTAssertEqual(i1.invoiceNumber, i2.invoiceNumber, "Le numéro de facture doit être identique")
        XCTAssertEqual(i1.total, i2.total)
        XCTAssertEqual(i1.sessionId, i2.sessionId)
    }

    /// Le compteur de numéro ne doit pas s'incrémenter sur l'appel idempotent.
    /// Après 2 generate() pour la même session, le prochain numéro libre doit
    /// être 00002 (et non 00003).
    func test_counter_not_incremented_on_idempotent_call() async throws {
        let s = makeSession(id: "vis_Y")
        let i1 = try await generate(s)
        XCTAssertTrue(i1.invoiceNumber.hasSuffix("00001"), "Première invoice = numéro 1")

        _ = try await generate(s)  // retry idempotent

        // Le prochain numéro libre (pour une autre session) doit être 00002.
        let next = InvoiceLocalStore.shared.nextInvoiceNumber(for: Date(timeIntervalSince1970: 1716393600))
        XCTAssertTrue(next.hasSuffix("00002"),
                     "Le compteur ne doit pas s'incrémenter sur le retry idempotent (attendu 00002, eu \(next))")
    }

    /// Deux sessions distinctes → deux invoices distinctes avec numéros différents.
    func test_distinct_sessions_produce_distinct_invoices() async throws {
        let sA = makeSession(id: "vis_A", total: 175)
        let sB = makeSession(id: "vis_B", total: 250)

        let iA = try await generate(sA)
        let iB = try await generate(sB)

        XCTAssertNotEqual(iA.id, iB.id)
        XCTAssertNotEqual(iA.invoiceNumber, iB.invoiceNumber)
        XCTAssertEqual(iA.total, 175)
        XCTAssertEqual(iB.total, 250)
        // Les numéros sont séquentiels : iA = 1, iB = 2.
        XCTAssertTrue(iA.invoiceNumber.hasSuffix("00001"))
        XCTAssertTrue(iB.invoiceNumber.hasSuffix("00002"))
    }

    /// loadInvoice(forSession:) doit retrouver l'invoice après une génération
    /// même sans repasser par InvoiceService (utile pour les UI views qui
    /// veulent afficher la facture sans la régénérer).
    func test_load_invoice_for_session_after_generation() async throws {
        let s = makeSession(id: "vis_Z")
        let original = try await generate(s)

        let reloaded = InvoiceLocalStore.shared.loadInvoice(forSession: s.id)
        XCTAssertNotNil(reloaded)
        XCTAssertEqual(reloaded?.id, original.id)
        XCTAssertEqual(reloaded?.invoiceNumber, original.invoiceNumber)
        XCTAssertEqual(reloaded?.total, original.total)
    }

    /// Sanity : pas d'invoice pour une session non encore générée.
    func test_load_invoice_returns_nil_when_no_generation_yet() {
        XCTAssertNil(InvoiceLocalStore.shared.loadInvoice(forSession: "never_generated"))
        XCTAssertNil(InvoiceLocalStore.shared.invoiceIdForSession("never_generated"))
    }
}
