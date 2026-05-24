import XCTest
@testable import HCPilotApp

/// Audit H10 — round-trip Codable de Invoice avec tip/travel_fee/payment_method/refund.
final class InvoiceCodableTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func test_invoice_decodes_with_new_fields() throws {
        let json = """
        {
          "id": "inv_1",
          "client_id": "cli_1",
          "client_name": "Jane Doe",
          "session_id": "ses_1",
          "invoice_number": "INV-001",
          "status": "paid",
          "subtotal": 250.0,
          "tax": 20.0,
          "discount": 0.0,
          "tip_amount": 30.0,
          "travel_fee_amount": 25.0,
          "total": 325.0,
          "items": [{"description": "Myers IV", "quantity": 1, "price": 250.0}],
          "payment_method": "apple_pay",
          "due_date": "2026-05-22T00:00:00Z",
          "paid_at": "2026-05-22T14:00:00Z",
          "refunded_at": null,
          "refund_amount": null,
          "stripe_payment_intent_id": "pi_123",
          "created_at": "2026-05-20T10:00:00Z",
          "updated_at": null
        }
        """.data(using: .utf8)!

        let invoice = try decoder.decode(Invoice.self, from: json)
        XCTAssertEqual(invoice.tipAmount, 30.0)
        XCTAssertEqual(invoice.travelFeeAmount, 25.0)
        XCTAssertEqual(invoice.paymentMethod, .applePay)
        XCTAssertNil(invoice.refundedAt)
        XCTAssertEqual(invoice.status, .paid)
    }

    func test_invoice_decodes_refunded_status() throws {
        let json = """
        {
          "id": "inv_2",
          "client_id": "cli_2",
          "session_id": null,
          "invoice_number": "INV-002",
          "status": "partial_refund",
          "subtotal": null,
          "tax": null,
          "discount": null,
          "tip_amount": null,
          "travel_fee_amount": null,
          "total": 100.0,
          "items": null,
          "payment_method": "card",
          "due_date": "2026-05-22T00:00:00Z",
          "paid_at": "2026-05-22T14:00:00Z",
          "refunded_at": "2026-05-23T10:00:00Z",
          "refund_amount": 40.0,
          "stripe_payment_intent_id": null,
          "created_at": "2026-05-20T10:00:00Z",
          "updated_at": null
        }
        """.data(using: .utf8)!

        let invoice = try decoder.decode(Invoice.self, from: json)
        XCTAssertEqual(invoice.status, .partialRefund)
        XCTAssertEqual(invoice.refundAmount, 40.0)
        XCTAssertEqual(invoice.paymentMethod, .card)
    }

    // MARK: - P-14 — PaymentMethod displayName

    func test_payment_method_displayName_non_empty_for_all_cases() {
        for m in Invoice.PaymentMethod.allCases {
            XCTAssertFalse(m.displayName.isEmpty,
                          "displayName doit être non vide pour \(m)")
        }
    }

    func test_payment_method_displayName_cash() {
        XCTAssertEqual(Invoice.PaymentMethod.cash.displayName, "Cash")
    }

    func test_payment_method_displayName_apple_pay() {
        XCTAssertEqual(Invoice.PaymentMethod.applePay.displayName, "Apple Pay")
    }

    func test_payment_method_serializes_snake_case() throws {
        // Verifies the .applePay case round-trips as "apple_pay" via the
        // explicit rawValue mapping (not the encoder strategy, which only
        // touches keys, not values).
        let inv = Invoice(
            id: "x", clientId: "y", clientName: nil, sessionId: nil,
            invoiceNumber: "X", status: .paid,
            subtotal: nil, tax: nil, discount: nil,
            tipAmount: nil, travelFeeAmount: nil,
            total: 0,
            items: nil,
            paymentMethod: .applePay,
            dueDate: Date(timeIntervalSince1970: 0),
            paidAt: nil, refundedAt: nil, refundAmount: nil,
            stripePaymentIntentId: nil,
            invoicePdfPath: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: nil
        )
        let data = try encoder.encode(inv)
        let str = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(str.contains("\"payment_method\":\"apple_pay\""))
    }
}
