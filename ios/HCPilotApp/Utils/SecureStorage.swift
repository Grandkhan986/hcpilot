import Foundation
import LocalAuthentication
import Security
import os.log

/// Wrapper Keychain pour les éléments sensibles : token JWT, profil utilisateur,
/// timestamp de dernière activité. Brief HIPAA §Sécurité :
/// "Keychain pour tokens / Pas de stockage de PHI dans NSUserDefaults".
///
/// Accessibilité actuelle : `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
///   - Lisible uniquement quand l'appareil a été déverrouillé au moins une fois
///     depuis le boot.
///   - Non synchronisé via iCloud (ThisDevice).
///
/// Audit M3 — en production HIPAA, basculer vers
/// `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` qui impose la présence d'un
/// passcode. Le helper `SecuritySettings.deviceHasPasscode()` permet de notifier
/// l'utilisateur si son téléphone n'a pas de passcode configuré.
enum SecureStorageKey: String {
    case authToken = "hcpilot.auth_token"
    case userProfile = "hcpilot.user_profile"
    case lastActivity = "hcpilot.last_activity"
}

enum SecureStorageError: Error {
    case writeFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case decodeFailed

    var localizedDescription: String {
        switch self {
        case .writeFailed(let s): return "Keychain write failed (OSStatus \(s))"
        case .readFailed(let s):  return "Keychain read failed (OSStatus \(s))"
        case .deleteFailed(let s): return "Keychain delete failed (OSStatus \(s))"
        case .decodeFailed: return "Keychain decode failed"
        }
    }
}

final class SecureStorage {
    static let shared = SecureStorage()
    private init() {}

    /// Audit B3 : bundle identifier dynamique (au lieu de hardcodé) pour
    /// supporter d'éventuelles cibles différentes (TestFlight, debug, prod).
    private let service = Bundle.main.bundleIdentifier ?? "com.hcpilot.app"

    private let logger = Logger(subsystem: "com.hcpilot.app", category: "SecureStorage")

    // MARK: - String

    @discardableResult
    func setString(_ value: String, forKey key: SecureStorageKey) -> Result<Void, SecureStorageError> {
        save(data: Data(value.utf8), key: key)
    }

    func getString(forKey key: SecureStorageKey) -> String? {
        guard case .success(let data) = loadResult(key: key),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    // MARK: - Data (JSON)

    @discardableResult
    func setData(_ value: Data, forKey key: SecureStorageKey) -> Result<Void, SecureStorageError> {
        save(data: value, key: key)
    }

    func getData(forKey key: SecureStorageKey) -> Data? {
        if case .success(let data) = loadResult(key: key) { return data }
        return nil
    }

    // MARK: - Date

    @discardableResult
    func setDate(_ date: Date, forKey key: SecureStorageKey) -> Result<Void, SecureStorageError> {
        setString(String(date.timeIntervalSince1970), forKey: key)
    }

    func getDate(forKey key: SecureStorageKey) -> Date? {
        guard let s = getString(forKey: key),
              let interval = TimeInterval(s) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    // MARK: - Suppression

    @discardableResult
    func remove(_ key: SecureStorageKey) -> Result<Void, SecureStorageError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return .success(())
        }
        logger.error("SecItemDelete failed: \(status, privacy: .public) for \(key.rawValue, privacy: .public)")
        return .failure(.deleteFailed(status))
    }

    /// Purge l'ensemble de la session (logout).
    func clearSession() {
        _ = remove(.authToken)
        _ = remove(.userProfile)
        _ = remove(.lastActivity)
    }

    // MARK: - Bas niveau

    private func save(data: Data, key: SecureStorageKey) -> Result<Void, SecureStorageError> {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        let updateAttrs: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
        if updateStatus == errSecSuccess { return .success(()) }
        if updateStatus == errSecItemNotFound {
            var addAttrs = baseQuery
            addAttrs[kSecValueData as String] = data
            addAttrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addAttrs as CFDictionary, nil)
            if addStatus == errSecSuccess { return .success(()) }
            logger.error("SecItemAdd failed: \(addStatus, privacy: .public) for \(key.rawValue, privacy: .public)")
            return .failure(.writeFailed(addStatus))
        }
        logger.error("SecItemUpdate failed: \(updateStatus, privacy: .public) for \(key.rawValue, privacy: .public)")
        return .failure(.writeFailed(updateStatus))
    }

    private func loadResult(key: SecureStorageKey) -> Result<Data, SecureStorageError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return .success(data)
        }
        if status == errSecItemNotFound {
            // Pas une erreur — juste pas de valeur.
            return .failure(.readFailed(status))
        }
        logger.error("SecItemCopyMatching failed: \(status, privacy: .public) for \(key.rawValue, privacy: .public)")
        return .failure(.readFailed(status))
    }
}

/// Préférences de sécurité (UserDefaults).
/// Brief : "Auto-logout après 30 minutes d'inactivité (configurable)".
///
/// Audit M4 — `inactivityTimeoutMinutes` est dans UserDefaults parce que c'est
/// une préférence d'UX, pas un PHI. Toutefois UserDefaults peut être sauvegardé
/// via iCloud Backup en clair. Pour HIPAA production, on déplacera cette valeur
/// dans le Keychain (clé dédiée) si on veut prévenir toute exfiltration via
/// restore d'un backup compromis. Pour le MVP, c'est acceptable (valeur non
/// sensible, juste un nombre de minutes).
enum SecuritySettings {
    private static let timeoutKey = "hcpilot.inactivity_timeout_minutes"
    static let defaultTimeoutMinutes = 30

    static var inactivityTimeoutMinutes: Int {
        get {
            let v = UserDefaults.standard.integer(forKey: timeoutKey)
            return v > 0 ? v : defaultTimeoutMinutes
        }
        set {
            UserDefaults.standard.set(newValue, forKey: timeoutKey)
        }
    }

    static var inactivityTimeoutSeconds: TimeInterval {
        TimeInterval(inactivityTimeoutMinutes * 60)
    }

    /// Audit M3 — vérifie si le téléphone a un passcode/Face ID/Touch ID
    /// configuré. À appeler après login : si false, suggérer à l'utilisateur
    /// d'activer un passcode dans Réglages iOS.
    /// Brief §HIPAA : "Stockage local sécurisé".
    static func deviceHasPasscode() -> Bool {
        var error: NSError?
        let ctx = LAContext()
        // `.deviceOwnerAuthentication` couvre passcode + biométrie.
        return ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
}
