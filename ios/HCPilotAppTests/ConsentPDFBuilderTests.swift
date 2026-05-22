import XCTest
import PDFKit
import UIKit
@testable import HCPilotApp

/// Audit C7 / H21-H24 — Tests du builder PDF de consentement.
final class ConsentPDFBuilderTests: XCTestCase {

    private func makeInput(
        ip: String? = "192.168.1.42",
        version: Int? = 3,
        consentText: String = "Sample consent text."
    ) -> ConsentPDFBuilder.Input {
        let img = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 60)).image { ctx in
            UIColor.black.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 10, y: 30))
            path.addLine(to: CGPoint(x: 190, y: 30))
            path.stroke()
        }
        return ConsentPDFBuilder.Input(
            documentId: "doc-test-123",
            nurseName: "Jane Smith RN",
            clientName: "Acme Client",
            formulationName: "Myers Cocktail",
            consentText: consentText,
            checkpoints: [
                ConsentCheckpoint(id: "cp1", label: "I understand the procedure.", accepted: true),
                ConsentCheckpoint(id: "cp2", label: "I disclose my medical history.", accepted: true),
            ],
            signatureImage: img,
            signedAt: Date(timeIntervalSince1970: 1716393600),
            latitude: 37.7749,
            longitude: -122.4194,
            ipAddress: ip,
            standingOrderVersion: version,
            deviceInfo: ["model": "iPhone16,2", "system": "iOS 18.4"]
        )
    }

    func test_build_produces_valid_pdf_data() {
        let data = ConsentPDFBuilder.build(makeInput())
        XCTAssertFalse(data.isEmpty)
        let doc = PDFDocument(data: data)
        XCTAssertNotNil(doc)
        XCTAssertGreaterThanOrEqual(doc?.pageCount ?? 0, 1)
    }

    func test_build_contains_english_labels() {
        let data = ConsentPDFBuilder.build(makeInput())
        let text = PDFDocument(data: data)?.string ?? ""
        XCTAssertTrue(text.contains("Informed Consent"), "PDF should be in English")
        XCTAssertTrue(text.contains("Client:"))
        XCTAssertTrue(text.contains("Formulation:"))
        XCTAssertTrue(text.contains("Signed on:"))
        XCTAssertTrue(text.contains("Acknowledged Checkpoints"))
        XCTAssertTrue(text.contains("Metadata"))
        // No French residue (audit C7)
        XCTAssertFalse(text.contains("Soignant"))
        XCTAssertFalse(text.contains("Consentement"))
        XCTAssertFalse(text.contains("Horodatage"))
    }

    func test_build_includes_hipaa_notice() {
        let data = ConsentPDFBuilder.build(makeInput())
        let text = PDFDocument(data: data)?.string ?? ""
        XCTAssertTrue(text.contains("Notice of Privacy Practices"))
        XCTAssertTrue(text.contains("HIPAA"))
    }

    func test_build_includes_ip_and_so_version() {
        let data = ConsentPDFBuilder.build(makeInput(ip: "192.168.1.42", version: 7))
        let text = PDFDocument(data: data)?.string ?? ""
        XCTAssertTrue(text.contains("IP address: 192.168.1.42"))
        XCTAssertTrue(text.contains("Standing Order version: v7"))
    }

    func test_build_omits_ip_when_nil() {
        let data = ConsentPDFBuilder.build(makeInput(ip: nil, version: nil))
        let text = PDFDocument(data: data)?.string ?? ""
        XCTAssertFalse(text.contains("IP address:"))
        XCTAssertFalse(text.contains("Standing Order version:"))
    }

    func test_build_paginates_long_consent() {
        // Force overflow: ~30 paragraphs of body text should spill onto a 2nd page
        let longText = String(repeating: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ", count: 80)
        let data = ConsentPDFBuilder.build(makeInput(consentText: longText))
        let doc = PDFDocument(data: data)
        XCTAssertNotNil(doc)
        XCTAssertGreaterThan(doc?.pageCount ?? 0, 1, "Long consent should paginate")
        // Footer numbering present (audit H24)
        let text = doc?.string ?? ""
        XCTAssertTrue(text.contains("Page 1 /"))
    }
}
