import Foundation
import Security

/// Wrapper Keychain pour les éléments sensibles : token JWT, profil utilisateur,
/// timestamp de dernière activité. Brief HIPAA §Sécurité :
/// "Keychain pour tokens / Pas de stockage de PHI dans NSUserDefaults".
///
/// Accessibilité : `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
///   - Lisible uniquement quand l'appareil a été déverrouillé au moins une fois
///     depuis le boot.
///   - Non synchronisé via iCloud (ThisDevice).
enum SecureStorageKey: String {
    case authToken = "hcpilot.auth_token"
    case userProfile = "hcpilot.user_profile"
    case lastActivity = "hcpilot.last_activity"
}

final class SecureStorage {
    static let shared = SecureStorage()
    private init() {}

    private let service = "com.hcpilot.app"

    // MARK: - String

    func setString(_ value: String, forKey key: SecureStorageKey) {
        save(data: Data(value.utf8), key: key)
    }

    func getString(forKey key: SecureStorageKey) -> String? {
        guard let data = load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Data (pour JSON)

    func setData(_ value: Data, forKey key: SecureStorageKey) {
        save(data: value, key: key)
    }

    func getData(forKey key: SecureStorageKey) -> Data? {
        load(key: key)
    }

    // MARK: - Date

    func setDate(_ date: Date, forKey key: SecureStorageKey) {
        setString(String(date.timeIntervalSince1970), forKey: key)
    }

    func getDate(forKey key: SecureStorageKey) -> Date? {
        guard let s = getString(forKey: key),
              let interval = TimeInterval(s) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    // MARK: - Suppression

    func remove(_ key: SecureStorageKey) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Purge l'ensemble de la session (logout).
    func clearSession() {
        remove(.authToken)
        remove(.userProfile)
        remove(.lastActivity)
    }

    // MARK: - Bas niveau

    private func save(data: Data, key: SecureStorageKey) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        // SecItemAdd échoue si l'item existe déjà → on update plutôt
        let updateAttrs: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
        if status == errSecItemNotFound {
            var addAttrs = baseQuery
            addAttrs[kSecValueData as String] = data
            addAttrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(addAttrs as CFDictionary, nil)
        }
    }

    private func load(key: SecureStorageKey) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }
}

/// Préférences de sécurité non-sensibles (UserDefaults).
/// Brief : "Auto-logout après 30 minutes d'inactivité (configurable)".
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
}
