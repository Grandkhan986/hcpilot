import Foundation

/// Cache de réponses HTTP sur disque, protégé par FileProtection iOS.
/// Brief §Gestion offline : "Sessions du jour et demain, clients récents,
/// catalogue formulations, stock courant".
///
/// On stocke la réponse brute (Data) + un timestamp. À la lecture, l'APIService
/// re-décode avec son JSONDecoder maison (gère le custom date strategy).
final class OfflineCache {
    static let shared = OfflineCache()
    private init() { _ = cacheDirectory }  // create dir on init

    private lazy var cacheDirectory: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("HCPilotCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        // FileProtection : décryptable seulement après le 1er unlock du device
        // (HIPAA-friendly, le contenu reste verrouillé tant que l'utilisateur
        // n'a pas saisi son code après un cold boot).
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: dir.path
        )
        return dir
    }()

    /// Sauvegarde la réponse brute pour un endpoint. Écriture synchrone — le
    /// volume est faible (quelques KB par endpoint) et la déterminisme aide les
    /// tests + garantit que la prochaine lecture trouve bien la donnée.
    func save(_ data: Data, for endpoint: String) {
        let key = sanitize(endpoint)
        let payload: [String: Any] = [
            "saved_at": ISO8601DateFormatter().string(from: Date()),
            "data": data.base64EncodedString(),
        ]
        guard let encoded = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let url = cacheDirectory.appendingPathComponent("\(key).json")
        try? encoded.write(to: url, options: [
            .atomic,
            .completeFileProtectionUntilFirstUserAuthentication,
        ])
    }

    /// Renvoie la réponse cachée + son horodatage (ou nil si absente).
    func load(for endpoint: String) -> (data: Data, savedAt: Date)? {
        let key = sanitize(endpoint)
        let url = cacheDirectory.appendingPathComponent("\(key).json")
        guard let raw = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
              let savedAtStr = json["saved_at"] as? String,
              let dataB64 = json["data"] as? String,
              let data = Data(base64Encoded: dataB64),
              let savedAt = ISO8601DateFormatter().date(from: savedAtStr)
        else { return nil }
        return (data, savedAt)
    }

    func clear() {
        // On vide le contenu mais on garde le dossier — sinon les saves
        // ultérieurs échouent silencieusement (parent absent).
        if let entries = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for url in entries {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    /// Convertit un endpoint (`/sessions?archived=true`) en nom de fichier safe.
    private func sanitize(_ endpoint: String) -> String {
        endpoint
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "?", with: "-")
            .replacingOccurrences(of: "&", with: "-")
            .replacingOccurrences(of: "=", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}
