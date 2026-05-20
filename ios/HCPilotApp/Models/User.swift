import Foundation

/// Profil utilisateur (nurse) — renvoyé par /auth/login et /users/me.
/// Champs métier ajoutés au fur et à mesure des sprints (license, NPI, MD).
struct UserProfile: Codable {
    let id: String
    let email: String
    let full_name: String
    let role: String?
    let specialty: String?
    let phone: String?
    let avatar_url: String?
    let settings: UserSettings?
}

/// Préférences utilisateur. Renommage `SMSNotifications` → `smsNotifications`
/// (audit H4 : acronymes en majuscules à traiter comme un seul mot).
/// `showPriceHistory` retiré : vestige insurance/EMR, sans pertinence en private pay.
struct UserSettings: Codable {
    let notifications: Bool?
    let emailNotifications: Bool?
    let smsNotifications: Bool?
    let darkMode: Bool?
    let autoOptimizeRoutes: Bool?

    enum CodingKeys: String, CodingKey {
        case notifications
        case emailNotifications = "email_notifications"
        case smsNotifications = "sms_notifications"
        case darkMode = "dark_mode"
        case autoOptimizeRoutes = "auto_optimize_routes"
    }
}
