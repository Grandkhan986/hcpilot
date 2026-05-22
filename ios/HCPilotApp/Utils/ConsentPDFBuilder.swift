import UIKit

/// Generates the PDF of a signed consent via UIGraphicsPDFRenderer (PDFKit-friendly).
/// US Letter format (8.5 × 11 in). Automatic pagination when text overflows.
///
/// Audit C7/H21/H22/H23/H24 :
/// - All labels in English (target market = US nurses).
/// - HIPAA Notice of Privacy Practices section appended.
/// - Standing order version + IP address surfaced in metadata.
/// - Footer shows "Page X / Y" via two-pass rendering.
enum ConsentPDFBuilder {
    // MARK: - Layout constants
    static let pageWidth: CGFloat = 612    // 8.5"
    static let pageHeight: CGFloat = 792   // 11"
    static let margin: CGFloat = 48

    private static let headerFontSize: CGFloat = 18
    private static let identityFontSize: CGFloat = 13
    private static let sectionTitleFontSize: CGFloat = 14
    private static let bodyFontSize: CGFloat = 11
    private static let metadataFontSize: CGFloat = 10
    private static let footerFontSize: CGFloat = 9
    private static let lineHeight: CGFloat = 18
    private static let metadataLineHeight: CGFloat = 14
    private static let signatureMaxHeight: CGFloat = 100
    private static let signatureUnderlineWidth: CGFloat = 250

    private static let bodyFont = UIFont.systemFont(ofSize: bodyFontSize)

    /// HIPAA Notice of Privacy Practices summary. Brief §Compliance HIPAA.
    /// Full notice typically lives on the practice website; this PDF references
    /// the highlights so the signed copy is self-contained.
    private static let hipaaNotice = """
    This document is a medical record protected by the Health Insurance \
    Portability and Accountability Act (HIPAA). The provider may use and \
    disclose your protected health information (PHI) for treatment, payment, \
    and healthcare operations as permitted by law. You have the right to: \
    (1) access, inspect and obtain a copy of your PHI; (2) request amendments \
    to your record; (3) receive an accounting of disclosures; (4) request \
    restrictions on certain uses and disclosures; (5) file a complaint with \
    the provider or the U.S. Department of Health & Human Services without \
    fear of retaliation. A full Notice of Privacy Practices is available upon \
    request from your provider.
    """

    struct Input {
        let documentId: String
        let nurseName: String
        let clientName: String
        let formulationName: String
        let consentText: String
        let checkpoints: [ConsentCheckpoint]
        let signatureImage: UIImage
        let signedAt: Date
        let latitude: Double?
        let longitude: Double?
        let ipAddress: String?
        let standingOrderVersion: Int?
        let deviceInfo: [String: String]
    }

    /// Shared rendering context — owns the running `y` cursor so helpers can
    /// trigger page breaks without scattering inout params everywhere.
    private final class RenderContext {
        let pdf: UIGraphicsPDFRendererContext
        let totalPages: Int
        let documentId: String
        var pageIndex: Int = 0
        var y: CGFloat = margin

        init(pdf: UIGraphicsPDFRendererContext, totalPages: Int, documentId: String) {
            self.pdf = pdf
            self.totalPages = totalPages
            self.documentId = documentId
        }

        func startPage() {
            if pageIndex > 0 {
                drawFooter(documentId: documentId, page: pageIndex, total: totalPages)
            }
            pdf.beginPage()
            pageIndex += 1
            y = margin
        }

        func ensureRoom(_ needed: CGFloat) {
            if y + needed > pageHeight - margin {
                startPage()
            }
        }
    }

    static func build(_ input: Input) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let totalPages = countPages(input: input)

        return renderer.pdfData { pdfCtx in
            let ctx = RenderContext(pdf: pdfCtx, totalPages: totalPages, documentId: input.documentId)
            ctx.startPage()

            drawHeader(input: input, ctx: ctx)
            drawIdentity(input: input, ctx: ctx)

            drawSectionTitle("Informed Consent", ctx: ctx, topPadding: 0)
            drawWrappedText(input.consentText, font: bodyFont, ctx: ctx)

            drawSectionTitle("Acknowledged Checkpoints", ctx: ctx, topPadding: 12)
            for cp in input.checkpoints {
                drawCheckpoint(cp, ctx: ctx)
            }

            drawSectionTitle("Signature", ctx: ctx, topPadding: 16)
            drawSignature(input.signatureImage, ctx: ctx)

            drawSectionTitle("Metadata", ctx: ctx, topPadding: 12)
            drawMetadata(input: input, ctx: ctx)

            drawSectionTitle("Notice of Privacy Practices (HIPAA)", ctx: ctx, topPadding: 12)
            drawWrappedText(hipaaNotice, font: bodyFont, ctx: ctx)

            drawFooter(documentId: input.documentId, page: ctx.pageIndex, total: totalPages)
        }
    }

    // MARK: - Page counting

    /// Mirrors the rendering geometry exactly, but draws nothing. Used to pre-
    /// compute total pages so the footer can show "Page X / Y". Keep the
    /// arithmetic in sync with the draw* helpers below.
    private static func countPages(input: Input) -> Int {
        var page = 1
        var y = margin
        let usableWidth = pageWidth - 2 * margin
        let attrs: [NSAttributedString.Key: Any] = [.font: bodyFont]

        func feed(_ needed: CGFloat) {
            if y + needed > pageHeight - margin {
                page += 1
                y = margin
            }
        }

        func wrappedHeight(_ text: String) -> CGFloat {
            var total: CGFloat = 0
            for para in text.components(separatedBy: "\n") {
                let p = (para.isEmpty ? " " : para) as NSString
                total += ceil(p.boundingRect(
                    with: CGSize(width: usableWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attrs,
                    context: nil
                ).height) + 4
            }
            return total + 6
        }

        // Header + identity
        y += 60
        y += lineHeight * 3 + 8

        // Informed Consent
        feed(30); y += 22
        let consentH = wrappedHeight(input.consentText)
        for chunk in splitForPagination(totalHeight: consentH, lineApprox: lineHeight, usableHeight: pageHeight - margin) {
            feed(chunk); y += chunk
        }

        // Checkpoints
        feed(30); y += 22
        for _ in input.checkpoints {
            feed(24); y += 20
        }

        // Signature
        feed(30 + signatureMaxHeight + 10); y += 22
        y += signatureMaxHeight + 12

        // Metadata
        feed(30); y += 22
        let metadataLines = 4
            + input.deviceInfo.count
            + (input.ipAddress == nil ? 0 : 1)
            + (input.standingOrderVersion == nil ? 0 : 1)
        for _ in 0..<metadataLines {
            feed(metadataLineHeight + 2); y += metadataLineHeight
        }

        // HIPAA
        feed(30); y += 22
        let noticeH = wrappedHeight(hipaaNotice)
        for chunk in splitForPagination(totalHeight: noticeH, lineApprox: lineHeight, usableHeight: pageHeight - margin) {
            feed(chunk); y += chunk
        }

        return max(page, 1)
    }

    /// Splits a tall block into per-line increments so the page-counter "feed"
    /// can break at line boundaries the same way the real renderer does.
    private static func splitForPagination(totalHeight: CGFloat, lineApprox: CGFloat, usableHeight: CGFloat) -> [CGFloat] {
        var out: [CGFloat] = []
        var remaining = totalHeight
        let step = max(lineApprox, 14)
        while remaining > step {
            out.append(step)
            remaining -= step
        }
        if remaining > 0 { out.append(remaining) }
        return out
    }

    // MARK: - Sections

    private static func drawHeader(input: Input, ctx: RenderContext) {
        let title = "HCPilot — Informed Consent"
        title.draw(at: CGPoint(x: margin, y: ctx.y), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: headerFontSize),
            .foregroundColor: UIColor.black,
        ])
        let provider = "Provider: \(input.nurseName)"
        provider.draw(at: CGPoint(x: margin, y: ctx.y + 24), withAttributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray,
        ])
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: ctx.y + 46))
        line.addLine(to: CGPoint(x: pageWidth - margin, y: ctx.y + 46))
        UIColor.lightGray.setStroke()
        line.lineWidth = 0.5
        line.stroke()
        ctx.y += 60
    }

    private static func drawIdentity(input: Input, ctx: RenderContext) {
        let lines = [
            "Client: \(input.clientName)",
            "Formulation: \(input.formulationName)",
            "Signed on: \(formattedDate(input.signedAt))",
        ]
        for line in lines {
            line.draw(at: CGPoint(x: margin, y: ctx.y), withAttributes: [
                .font: UIFont.systemFont(ofSize: identityFontSize),
                .foregroundColor: UIColor.black,
            ])
            ctx.y += lineHeight
        }
        ctx.y += 8
    }

    private static func drawSectionTitle(_ title: String, ctx: RenderContext, topPadding: CGFloat) {
        ctx.y += topPadding
        ctx.ensureRoom(30)
        title.draw(at: CGPoint(x: margin, y: ctx.y), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: sectionTitleFontSize),
            .foregroundColor: UIColor.black,
        ])
        ctx.y += 22
    }

    private static func drawWrappedText(_ text: String, font: UIFont, ctx: RenderContext) {
        let usableWidth = pageWidth - 2 * margin
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
        ]
        for para in text.components(separatedBy: "\n") {
            let p = (para.isEmpty ? " " : para) as NSString
            let bounding = p.boundingRect(
                with: CGSize(width: usableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
            let height = ceil(bounding.height) + 4
            ctx.ensureRoom(height)
            p.draw(
                with: CGRect(x: margin, y: ctx.y, width: usableWidth, height: height),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
            ctx.y += height
        }
        ctx.y += 6
    }

    private static func drawCheckpoint(_ cp: ConsentCheckpoint, ctx: RenderContext) {
        ctx.ensureRoom(24)
        let box = UIBezierPath(rect: CGRect(x: margin, y: ctx.y + 2, width: 12, height: 12))
        UIColor.black.setStroke()
        box.lineWidth = 1
        box.stroke()
        if cp.accepted {
            let check = "✓" as NSString
            check.draw(at: CGPoint(x: margin + 1, y: ctx.y - 2), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black,
            ])
        }
        let label = cp.label as NSString
        label.draw(at: CGPoint(x: margin + 22, y: ctx.y + 1), withAttributes: [
            .font: UIFont.systemFont(ofSize: bodyFontSize),
            .foregroundColor: UIColor.black,
        ])
        ctx.y += 20
    }

    private static func drawSignature(_ image: UIImage, ctx: RenderContext) {
        let maxWidth: CGFloat = pageWidth - 2 * margin
        let ratio = image.size.width / max(image.size.height, 1)
        var width = maxWidth
        var height = width / max(ratio, 0.001)
        if height > signatureMaxHeight {
            height = signatureMaxHeight
            width = height * ratio
        }
        ctx.ensureRoom(height + 12)
        image.draw(in: CGRect(x: margin, y: ctx.y, width: width, height: height))
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: ctx.y + height + 2))
        line.addLine(to: CGPoint(x: margin + signatureUnderlineWidth, y: ctx.y + height + 2))
        UIColor.darkGray.setStroke()
        line.lineWidth = 0.5
        line.stroke()
        ctx.y += height + 12
    }

    private static func drawMetadata(input: Input, ctx: RenderContext) {
        var lines: [String] = []
        lines.append("Timestamp: \(formattedDate(input.signedAt))")
        if let lat = input.latitude, let lng = input.longitude {
            lines.append(String(format: "Geolocation: %.5f, %.5f", lat, lng))
        } else {
            lines.append("Geolocation: not available")
        }
        if let ip = input.ipAddress, !ip.isEmpty {
            lines.append("IP address: \(ip)")
        }
        if let v = input.standingOrderVersion {
            lines.append("Standing Order version: v\(v)")
        }
        lines.append("Document ID: \(input.documentId)")
        for (k, v) in input.deviceInfo.sorted(by: { $0.key < $1.key }) {
            lines.append("Device.\(k): \(v)")
        }
        for line in lines {
            ctx.ensureRoom(metadataLineHeight + 2)
            line.draw(at: CGPoint(x: margin, y: ctx.y), withAttributes: [
                .font: UIFont.systemFont(ofSize: metadataFontSize),
                .foregroundColor: UIColor.darkGray,
            ])
            ctx.y += metadataLineHeight
        }
    }

    private static func drawFooter(documentId: String, page: Int, total: Int) {
        let left = "Document ID: \(documentId)" as NSString
        let right = "Page \(page) / \(total)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: footerFontSize),
            .foregroundColor: UIColor.gray,
        ]
        let footerY = pageHeight - margin + 12
        left.draw(at: CGPoint(x: margin, y: footerY), withAttributes: attrs)
        let rightSize = right.size(withAttributes: attrs)
        right.draw(
            at: CGPoint(x: pageWidth - margin - rightSize.width, y: footerY),
            withAttributes: attrs
        )
    }

    private static func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateStyle = .full
        f.timeStyle = .medium
        return f.string(from: date)
    }
}
