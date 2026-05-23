import XCTest
import PDFKit
@testable import HCPilotApp

/// C-63 — Tests du builder PDF de facture + store local (numéro séquentiel,
/// stockage filesystem).
@MainActor
final class InvoicePDFBuilderTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        InvoiceLocalStore.shared.resetForTests()
    }

    override func tearDown() async throws {
        InvoiceLocalStore.shared.resetForTests()
        try await super.tearDown()
    }

    // MARK: - PDF generation

    private func makeInput(
        invoiceNumber: String = "INV-2026-00001",
        subtotal: Double = 175,
        travelFee: Double = 0,
        tip: Double = 0
    ) -> InvoicePDFBuilder.Input {
        InvoicePDFBuilder.Input(
            invoiceNumber: invoiceNumber,
            invoiceDate: Date(timeIntervalSince1970: 1716393600),
            practiceName: "Wellness IV California",
            practiceAddress: "100 Main St, San Francisco, CA",
            nurseFullName: "Marie Dupont",
            clientFullName: "Jean Martin",
            clientAddress: "12 Rue de la Paix, 75002 Paris",
            sessionFormulation: "Myers Cocktail",
            sessionDate: Date(timeIntervalSince1970: 1716393600),
            subtotal: subtotal,
            travelFee: travelFee,
            tip: tip,
            tax: 0,
            total: subtotal + travelFee + tip,
            paymentMethod: "Cash"
        )
    }

    func test_pdf_generation_minimal_session() {
        let data = InvoicePDFBuilder.build(makeInput())
        XCTAssertFalse(data.isEmpty)
        let doc = PDFDocument(data: data)
        XCTAssertNotNil(doc)
        XCTAssertGreaterThanOrEqual(doc?.pageCount ?? 0, 1)
    }

    func test_pdf_contains_invoice_number_and_total() {
        let data = InvoicePDFBuilder.build(makeInput(invoiceNumber: "INV-2026-00042", subtotal: 250))
        let text = PDFDocument(data: data)?.string ?? ""
        XCTAssertTrue(text.contains("INV-2026-00042"))
        XCTAssertTrue(text.contains("Marie Dupont"))
        XCTAssertTrue(text.contains("Jean Martin"))
        XCTAssertTrue(text.contains("Myers Cocktail"))
        XCTAssertTrue(text.contains("250") || text.contains("250,00") || text.contains("250.00"),
                      "Le montant doit apparaître dans le PDF")
    }

    func test_pdf_includes_travel_fee_and_tip_lines() {
        let data = InvoicePDFBuilder.build(makeInput(subtotal: 175, travelFee: 25, tip: 30))
        let text = PDFDocument(data: data)?.string ?? ""
        XCTAssertTrue(text.contains("Frais de déplacement"))
        XCTAssertTrue(text.contains("Pourboire"))
    }

    // MARK: - InvoiceLocalStore

    func test_invoice_number_auto_increments() {
        let n1 = InvoiceLocalStore.shared.nextInvoiceNumber(for: Date(timeIntervalSince1970: 1716393600))  // 2024-05-22
        let n2 = InvoiceLocalStore.shared.nextInvoiceNumber(for: Date(timeIntervalSince1970: 1716393600))
        let n3 = InvoiceLocalStore.shared.nextInvoiceNumber(for: Date(timeIntervalSince1970: 1716393600))

        XCTAssertEqual(n1, "INV-2024-00001")
        XCTAssertEqual(n2, "INV-2024-00002")
        XCTAssertEqual(n3, "INV-2024-00003")
    }

    func test_save_and_load_pdf_for_invoice_id() throws {
        let payload = "fake-pdf-content".data(using: .utf8)!
        _ = try InvoiceLocalStore.shared.savePDF(payload, forInvoiceId: "inv-test-42")

        let loaded = InvoiceLocalStore.shared.loadPDF(forInvoiceId: "inv-test-42")
        XCTAssertEqual(loaded, payload, "Le PDF doit être ré-lisible après save")
    }

    func test_load_returns_nil_for_unknown_invoice() {
        XCTAssertNil(InvoiceLocalStore.shared.loadPDF(forInvoiceId: "nope-not-saved"))
    }
}
