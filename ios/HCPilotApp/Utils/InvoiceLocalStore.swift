import Foundation

/// Stockage local des PDFs de facture (C-63 stub).
///
/// Le backend mock n'a pas de file storage. On stocke donc le PDF dans le
/// sandbox FileManager (Documents/Invoices/) et on garde une map locale
/// `invoice.pdf.paths` (UserDefaults) : `invoiceId → filename`. À terme,
/// Supabase Storage remplacera ce mécanisme.
///
/// Compteur de numéro de facture séquentiel persisté localement aussi —
/// idéalement côté backend, mais hors scope du stub.
@MainActor
final class InvoiceLocalStore {
    static let shared = InvoiceLocalStore()

    private let pathsKey = "invoice.pdf.paths"
    private let counterKey = "invoice.lastNumber"

    private init() {}

    /// Répertoire de stockage des PDFs.
    private var invoicesDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Invoices", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Génère le prochain numéro de facture séquentiel, format INV-YYYY-XXXXX.
    /// Le compteur est local — en production il viendra du backend.
    func nextInvoiceNumber(for date: Date = Date()) -> String {
        let current = UserDefaults.standard.integer(forKey: counterKey)
        let next = current + 1
        UserDefaults.standard.set(next, forKey: counterKey)
        let year = Calendar.current.component(.year, from: date)
        return String(format: "INV-%04d-%05d", year, next)
    }

    /// Sauvegarde le PDF et retourne le chemin local (filename relatif au dir).
    @discardableResult
    func savePDF(_ data: Data, forInvoiceId invoiceId: String) throws -> String {
        let filename = "\(invoiceId).pdf"
        let url = invoicesDir.appendingPathComponent(filename)
        try data.write(to: url, options: [
            .atomic,
            .completeFileProtectionUntilFirstUserAuthentication,
        ])
        // Persiste la map
        var map = UserDefaults.standard.dictionary(forKey: pathsKey) as? [String: String] ?? [:]
        map[invoiceId] = filename
        UserDefaults.standard.set(map, forKey: pathsKey)
        return url.path
    }

    /// Lit le PDF d'une facture si stocké localement.
    func loadPDF(forInvoiceId invoiceId: String) -> Data? {
        let map = UserDefaults.standard.dictionary(forKey: pathsKey) as? [String: String] ?? [:]
        guard let filename = map[invoiceId] else { return nil }
        let url = invoicesDir.appendingPathComponent(filename)
        return try? Data(contentsOf: url)
    }

    /// Pour les tests : reset compteur + map. À NE PAS appeler en prod.
    func resetForTests() {
        UserDefaults.standard.removeObject(forKey: pathsKey)
        UserDefaults.standard.removeObject(forKey: counterKey)
        try? FileManager.default.removeItem(at: invoicesDir)
    }
}
