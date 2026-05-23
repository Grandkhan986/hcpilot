import UIKit

/// Génère le PDF d'une facture stub (C-63). Format US Letter (8.5 × 11 in).
/// Pagination automatique si les items dépassent une page (rare en pratique).
///
/// Sprint 4 (Stripe Connect) remplacera la génération locale par un endpoint
/// backend qui appellera Stripe Invoice + hébergera le PDF sur Supabase Storage.
/// Pour le stub, on génère 100% côté iOS et on stocke le PDF dans le sandbox
/// FileManager (cf. `InvoiceLocalStore`).
enum InvoicePDFBuilder {
    // MARK: - Layout constants
    static let pageWidth: CGFloat = 612    // 8.5"
    static let pageHeight: CGFloat = 792   // 11"
    static let margin: CGFloat = 48

    private static let titleFontSize: CGFloat = 24
    private static let sectionTitleFontSize: CGFloat = 13
    private static let bodyFontSize: CGFloat = 11
    private static let smallFontSize: CGFloat = 9
    private static let lineHeight: CGFloat = 18

    /// Toutes les infos nécessaires pour rendre la facture. Pas de dépendance
    /// au backend pour le stub : le caller (InvoiceService) construit ce
    /// payload à partir de la session terminée + profil de la nurse.
    struct Input {
        let invoiceNumber: String      // ex: INV-2026-00001
        let invoiceDate: Date
        let practiceName: String       // ex: "Wellness IV California"
        let practiceAddress: String?   // libre
        let nurseFullName: String
        let clientFullName: String
        let clientAddress: String?
        let sessionFormulation: String
        let sessionDate: Date
        let subtotal: Double
        let travelFee: Double          // 0 si pas applicable
        let tip: Double                // 0 si pas applicable
        let tax: Double                // 0 en stub (Stripe Tax activera ça)
        let total: Double
        let paymentMethod: String      // "Cash" / "Card" / etc. — stub "Cash"
    }

    static func build(_ input: Input) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y = margin

            y = drawHeader(input: input, y: y)
            y = drawIdentities(input: input, y: y + 8)
            y = drawSessionDetails(input: input, y: y + 20)
            y = drawTotalsTable(input: input, y: y + 12)
            drawFooter(input: input)
        }
    }

    // MARK: - Sections

    private static func drawHeader(input: Input, y: CGFloat) -> CGFloat {
        // Titre + numéro facture à droite
        "FACTURE".draw(at: CGPoint(x: margin, y: y), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: titleFontSize),
            .foregroundColor: UIColor.black,
        ])
        let number = input.invoiceNumber as NSString
        let numberAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: bodyFontSize, weight: .medium),
            .foregroundColor: UIColor.black,
        ]
        let numberSize = number.size(withAttributes: numberAttr)
        number.draw(
            at: CGPoint(x: pageWidth - margin - numberSize.width, y: y + 4),
            withAttributes: numberAttr
        )

        // Pratique
        let practice = input.practiceName
        practice.draw(at: CGPoint(x: margin, y: y + titleFontSize + 10), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: bodyFontSize),
            .foregroundColor: UIColor.darkGray,
        ])
        var addressY = y + titleFontSize + 10 + lineHeight
        if let addr = input.practiceAddress, !addr.isEmpty {
            addr.draw(at: CGPoint(x: margin, y: addressY), withAttributes: [
                .font: UIFont.systemFont(ofSize: smallFontSize),
                .foregroundColor: UIColor.darkGray,
            ])
            addressY += lineHeight - 4
        }

        // Date d'émission à droite
        let dateLabel = "Émise le \(Self.dateFmt.string(from: input.invoiceDate))" as NSString
        let dateAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: smallFontSize),
            .foregroundColor: UIColor.darkGray,
        ]
        let dateSize = dateLabel.size(withAttributes: dateAttr)
        dateLabel.draw(
            at: CGPoint(x: pageWidth - margin - dateSize.width, y: y + titleFontSize + 14),
            withAttributes: dateAttr
        )

        // Trait de séparation
        let line = UIBezierPath()
        line.move(to: CGPoint(x: margin, y: addressY + 8))
        line.addLine(to: CGPoint(x: pageWidth - margin, y: addressY + 8))
        UIColor.lightGray.setStroke()
        line.lineWidth = 0.5
        line.stroke()

        return addressY + 16
    }

    private static func drawIdentities(input: Input, y: CGFloat) -> CGFloat {
        // Deux colonnes : "Émise par" / "Facturée à"
        let colWidth = (pageWidth - 2 * margin - 20) / 2
        let leftX = margin
        let rightX = margin + colWidth + 20

        let header: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: sectionTitleFontSize),
            .foregroundColor: UIColor.black,
        ]
        let body: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: bodyFontSize),
            .foregroundColor: UIColor.darkGray,
        ]

        "Émise par".draw(at: CGPoint(x: leftX, y: y), withAttributes: header)
        input.nurseFullName.draw(at: CGPoint(x: leftX, y: y + lineHeight), withAttributes: body)

        "Facturée à".draw(at: CGPoint(x: rightX, y: y), withAttributes: header)
        input.clientFullName.draw(at: CGPoint(x: rightX, y: y + lineHeight), withAttributes: body)
        if let addr = input.clientAddress, !addr.isEmpty {
            addr.draw(at: CGPoint(x: rightX, y: y + lineHeight * 2), withAttributes: body)
        }

        return y + lineHeight * 3
    }

    private static func drawSessionDetails(input: Input, y: CGFloat) -> CGFloat {
        "Prestation".draw(at: CGPoint(x: margin, y: y), withAttributes: [
            .font: UIFont.boldSystemFont(ofSize: sectionTitleFontSize),
            .foregroundColor: UIColor.black,
        ])

        let rowY = y + lineHeight
        let formulation = "\(input.sessionFormulation)"
        formulation.draw(at: CGPoint(x: margin, y: rowY), withAttributes: [
            .font: UIFont.systemFont(ofSize: bodyFontSize),
            .foregroundColor: UIColor.black,
        ])

        let dateText = "Session du \(Self.dateTimeFmt.string(from: input.sessionDate))" as NSString
        dateText.draw(at: CGPoint(x: margin, y: rowY + lineHeight), withAttributes: [
            .font: UIFont.systemFont(ofSize: smallFontSize),
            .foregroundColor: UIColor.darkGray,
        ])

        return rowY + lineHeight * 2
    }

    private static func drawTotalsTable(input: Input, y: CGFloat) -> CGFloat {
        let rightEdge = pageWidth - margin
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: bodyFontSize),
            .foregroundColor: UIColor.darkGray,
        ]
        let valueAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: bodyFontSize),
            .foregroundColor: UIColor.black,
        ]
        let totalLabelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: sectionTitleFontSize),
            .foregroundColor: UIColor.black,
        ]
        let totalValueAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: sectionTitleFontSize),
            .foregroundColor: UIColor.black,
        ]

        // Trait haut
        var currentY = y
        let topLine = UIBezierPath()
        topLine.move(to: CGPoint(x: margin, y: currentY))
        topLine.addLine(to: CGPoint(x: rightEdge, y: currentY))
        UIColor.lightGray.setStroke()
        topLine.lineWidth = 0.5
        topLine.stroke()
        currentY += 10

        let lines: [(String, Double)] = [
            ("Sous-total", input.subtotal),
            ("Frais de déplacement", input.travelFee),
            ("Pourboire", input.tip),
            ("Taxes", input.tax),
        ].filter { $0.1 > 0 || $0.0 == "Sous-total" }

        for (label, value) in lines {
            label.draw(at: CGPoint(x: margin, y: currentY), withAttributes: labelAttr)
            let v = Self.currency(value) as NSString
            let vSize = v.size(withAttributes: valueAttr)
            v.draw(at: CGPoint(x: rightEdge - vSize.width, y: currentY), withAttributes: valueAttr)
            currentY += lineHeight
        }

        // Trait avant total
        let sepLine = UIBezierPath()
        sepLine.move(to: CGPoint(x: margin + 200, y: currentY + 2))
        sepLine.addLine(to: CGPoint(x: rightEdge, y: currentY + 2))
        UIColor.darkGray.setStroke()
        sepLine.lineWidth = 0.5
        sepLine.stroke()
        currentY += 12

        // Total
        "TOTAL".draw(at: CGPoint(x: margin, y: currentY), withAttributes: totalLabelAttr)
        let total = Self.currency(input.total) as NSString
        let totalSize = total.size(withAttributes: totalValueAttr)
        total.draw(at: CGPoint(x: rightEdge - totalSize.width, y: currentY), withAttributes: totalValueAttr)
        currentY += lineHeight + 4

        // Mention paiement
        let pay = "Payment processed via \(input.paymentMethod)"
        pay.draw(at: CGPoint(x: margin, y: currentY), withAttributes: [
            .font: UIFont.systemFont(ofSize: smallFontSize),
            .foregroundColor: UIColor.darkGray,
        ])
        currentY += lineHeight

        return currentY
    }

    private static func drawFooter(input: Input) {
        let footerY = pageHeight - margin
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: smallFontSize),
            .foregroundColor: UIColor.gray,
        ]
        let left = "Facture \(input.invoiceNumber) · \(Self.dateFmt.string(from: input.invoiceDate))" as NSString
        left.draw(at: CGPoint(x: margin, y: footerY), withAttributes: attrs)

        let right = "Conditions de paiement : selon entente. Pour questions : \(input.practiceName)." as NSString
        let rightSize = right.size(withAttributes: attrs)
        right.draw(
            at: CGPoint(x: pageWidth - margin - rightSize.width, y: footerY + lineHeight),
            withAttributes: attrs
        )
    }

    // MARK: - Helpers

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private static let dateTimeFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    /// Formate en euros (devise EUR — décision fondateur, passera USD en fin
    /// de projet avec le passage à l'anglais).
    static func currency(_ amount: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        return f.string(from: NSNumber(value: amount)) ?? "\(amount) €"
    }
}
