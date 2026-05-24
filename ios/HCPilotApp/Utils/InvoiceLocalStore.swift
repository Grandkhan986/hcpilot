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
///
/// P-12 — idempotence par session : on persiste aussi le mapping
/// `sessionId → invoiceId` et la métadonnée Invoice sérialisée, pour
/// renvoyer la même invoice si la génération est appelée 2 fois pour la
/// même session (cas réels : retry après freeze, redémarrage app, double-tap).
@MainActor
final class InvoiceLocalStore {
    static let shared = InvoiceLocalStore()

    private let pathsKey = "invoice.pdf.paths"
    private let counterKey = "invoice.lastNumber"
    private let sessionToInvoiceKey = "invoice.sessionMap"
    private let invoicesMetadataKey = "invoice.metadata"

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

    // MARK: - P-12 idempotence

    /// Retourne l'invoiceId existant pour une session si elle en a déjà une.
    /// Sert à garantir l'idempotence de InvoiceService.generateInvoiceForCompletedSession.
    func invoiceIdForSession(_ sessionId: String) -> String? {
        let map = UserDefaults.standard.dictionary(forKey: sessionToInvoiceKey) as? [String: String] ?? [:]
        return map[sessionId]
    }

    /// Persiste l'Invoice complète + lie la session à l'invoiceId. À appeler
    /// après une génération réussie pour que les appels suivants soient idempotents.
    func recordInvoice(_ invoice: Invoice, forSession sessionId: String) {
        // 1. Lier sessionId → invoiceId
        var sessionMap = UserDefaults.standard.dictionary(forKey: sessionToInvoiceKey) as? [String: String] ?? [:]
        sessionMap[sessionId] = invoice.id
        UserDefaults.standard.set(sessionMap, forKey: sessionToInvoiceKey)

        // 2. Stocker la métadonnée Invoice sérialisée pour rebuild fidèle.
        // On stocke en base64-of-JSON dans UserDefaults : compact, sans
        // dépendance file system supplémentaire.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let blob = try? encoder.encode(invoice),
              let str = String(data: blob, encoding: .utf8) else {
            return
        }
        var metaMap = UserDefaults.standard.dictionary(forKey: invoicesMetadataKey) as? [String: String] ?? [:]
        metaMap[invoice.id] = str
        UserDefaults.standard.set(metaMap, forKey: invoicesMetadataKey)
    }

    /// Retourne l'Invoice persistée pour une session, ou nil si jamais générée.
    /// Le rebuild est fidèle (numéro, montants, dates d'origine) — pas de
    /// recalcul depuis la Session.
    func loadInvoice(forSession sessionId: String) -> Invoice? {
        guard let invoiceId = invoiceIdForSession(sessionId) else { return nil }
        let metaMap = UserDefaults.standard.dictionary(forKey: invoicesMetadataKey) as? [String: String] ?? [:]
        guard let str = metaMap[invoiceId],
              let data = str.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Invoice.self, from: data)
    }

    /// Pour les tests : reset compteur + map. À NE PAS appeler en prod.
    func resetForTests() {
        UserDefaults.standard.removeObject(forKey: pathsKey)
        UserDefaults.standard.removeObject(forKey: counterKey)
        UserDefaults.standard.removeObject(forKey: sessionToInvoiceKey)
        UserDefaults.standard.removeObject(forKey: invoicesMetadataKey)
        try? FileManager.default.removeItem(at: invoicesDir)
    }
}
