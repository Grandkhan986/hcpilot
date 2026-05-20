import UIKit

/// Génère le PDF d'un consentement signé via UIGraphicsPDFRenderer (PDFKit-friendly).
/// Format US Letter (8.5 × 11 in). Pagination automatique si le texte déborde.
enum ConsentPDFBuilder {
    static let pageWidth: CGFloat = 612   // 8.5"
    static let pageHeight: CGFloat = 792  // 11"
    static let margin: CGFloat = 48

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
        let deviceInfo: [String: String]
    }

    static func build(_ input: Input) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            var y = margin
            ctx.beginPage()

            y = drawHeader(input: input, ctx: ctx, y: y)
            y = drawIdentity(input: input, y: y)
            y = drawSectionTitle("Consentement", y: y, ctx: ctx)
            y = drawWrappedText(input.consentText, y: y, font: bodyFont, ctx: ctx)

            y = drawSectionTitle("Checkpoints validés", y: y + 12, ctx: ctx)
            for cp in input.checkpoints {
                y = drawCheckpoint(cp, y: y, ctx: ctx)
            }

            y = drawSectionTitle("Signature", y: y + 16, ctx: ctx)
            y = drawSignature(input.signatureImage, y: y, ctx: ctx)

            y = drawSectionTitle("Métadonnées", y: y + 12, ctx: ctx)
            y = drawMetadata(input: input, y: y, ctx: ctx)

            drawFooter(documentId: input.documentId, ctx: ctx)
        }
    }

    // MARK: - Sections

    private static func drawHeader(input: Input, ctx: UIGraphicsPDFRendererContext, y: CGFloat) -> CGFloat {
        let title = "HCPilot — Consentement éclairé"
        title.draw(at: CGPoint(x: margin, y: y), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black,
        ])
        let nurse = "Soignant : \(input.nurseName)"
        nurse.draw(at: CGPoint(x: margin, y: y + 24), withAttributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray,
        ])
        // Ligne de séparation
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: y + 46))
        line.addLine(to: CGPoint(x: pageWidth - margin, y: y + 46))
        UIColor.lightGray.setStroke()
        line.lineWidth = 0.5
        line.stroke()
        return y + 60
    }

    private static func drawIdentity(input: Input, y: CGFloat) -> CGFloat {
        let lines = [
            "Client : \(input.clientName)",
            "Formulation : \(input.formulationName)",
            "Signé le : \(formattedDate(input.signedAt))",
        ]
        var yy = y
        for line in lines {
            line.draw(at: CGPoint(x: margin, y: yy), withAttributes: [
                .font: UIFont.systemFont(ofSize: 13),
                .foregroundColor: UIColor.black,
            ])
            yy += 18
        }
        return yy + 8
    }

    private static func drawSectionTitle(_ title: String, y: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var yy = y
        if yy + 30 > pageHeight - margin {
            ctx.beginPage()
            yy = margin
        }
        title.draw(at: CGPoint(x: margin, y: yy), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black,
        ])
        return yy + 22
    }

    private static let bodyFont = UIFont.systemFont(ofSize: 11)

    private static func drawWrappedText(
        _ text: String,
        y: CGFloat,
        font: UIFont,
        ctx: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let paragraphs = text.components(separatedBy: "\n")
        var yy = y
        let usableWidth = pageWidth - 2 * margin
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
        ]
        for para in paragraphs {
            let p = (para.isEmpty ? " " : para) as NSString
            let bounding = p.boundingRect(
                with: CGSize(width: usableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
            let height = ceil(bounding.height) + 4
            if yy + height > pageHeight - margin {
                ctx.beginPage()
                yy = margin
            }
            p.draw(
                with: CGRect(x: margin, y: yy, width: usableWidth, height: height),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
            yy += height
        }
        return yy + 6
    }

    private static func drawCheckpoint(
        _ cp: ConsentCheckpoint,
        y: CGFloat,
        ctx: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var yy = y
        if yy + 24 > pageHeight - margin {
            ctx.beginPage()
            yy = margin
        }
        // Carré coché
        let box = UIBezierPath(rect: CGRect(x: margin, y: yy + 2, width: 12, height: 12))
        UIColor.black.setStroke()
        box.lineWidth = 1
        box.stroke()
        if cp.accepted {
            let check = "✓" as NSString
            check.draw(at: CGPoint(x: margin + 1, y: yy - 2), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black,
            ])
        }
        let label = cp.label as NSString
        label.draw(at: CGPoint(x: margin + 22, y: yy + 1), withAttributes: [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black,
        ])
        return yy + 20
    }

    private static func drawSignature(
        _ image: UIImage,
        y: CGFloat,
        ctx: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        let maxHeight: CGFloat = 100
        let maxWidth: CGFloat = pageWidth - 2 * margin
        let ratio = image.size.width / max(image.size.height, 1)
        var width = maxWidth
        var height = width / max(ratio, 0.001)
        if height > maxHeight {
            height = maxHeight
            width = height * ratio
        }
        var yy = y
        if yy + height + 10 > pageHeight - margin {
            ctx.beginPage()
            yy = margin
        }
        image.draw(in: CGRect(x: margin, y: yy, width: width, height: height))
        // Trait sous la signature
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: yy + height + 2))
        line.addLine(to: CGPoint(x: margin + 250, y: yy + height + 2))
        UIColor.darkGray.setStroke()
        line.lineWidth = 0.5
        line.stroke()
        return yy + height + 12
    }

    private static func drawMetadata(
        input: Input,
        y: CGFloat,
        ctx: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var lines: [String] = []
        lines.append("Horodatage : \(formattedDate(input.signedAt))")
        if let lat = input.latitude, let lng = input.longitude {
            lines.append(String(format: "Géolocalisation : %.5f, %.5f", lat, lng))
        } else {
            lines.append("Géolocalisation : non disponible")
        }
        for (k, v) in input.deviceInfo.sorted(by: { $0.key < $1.key }) {
            lines.append("Device.\(k) : \(v)")
        }
        var yy = y
        for line in lines {
            if yy + 16 > pageHeight - margin {
                ctx.beginPage()
                yy = margin
            }
            line.draw(at: CGPoint(x: margin, y: yy), withAttributes: [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray,
            ])
            yy += 14
        }
        return yy
    }

    private static func drawFooter(documentId: String, ctx: UIGraphicsPDFRendererContext) {
        let text = "Document ID : \(documentId)" as NSString
        text.draw(at: CGPoint(x: margin, y: pageHeight - margin + 12), withAttributes: [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.gray,
        ])
    }

    private static func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .full
        f.timeStyle = .medium
        return f.string(from: date)
    }
}
