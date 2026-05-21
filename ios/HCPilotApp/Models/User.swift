import Foundation

/// Profil utilisateur (nurse) — renvoyé par /auth/login et /users/me.
/// Aligné brief : camelCase Swift, snake_case JSON via APIService global strategy.
struct UserProfile: Codable {
    let id: String
    let email: String
    let fullName: String
    let role: String?
    let specialty: String?
    let phone: String?
    let avatarUrl: String?
    let settings: UserSettings?
}

/// Préférences utilisateur. Audit H4 : SMSNotifications → smsNotifications
/// (acronyme = 1 mot). `showPriceHistory` retiré (vestige insurance/EMR).
struct UserSettings: Codable {
    let notifications: Bool?
    let emailNotifications: Bool?
    let smsNotifications: Bool?
    let darkMode: Bool?
    let autoOptimizeRoutes: Bool?
}
