import Foundation
import SwiftUI

/// État global de connectivité. Mis à jour par `APIService` à chaque appel API :
/// - succès → `isOffline = false`, `lastSyncAt = now`
/// - échec avec cache de secours → `isOffline = true`, `lastCachedAt = saved_at`
///
/// Les vues observent ce singleton pour afficher un bandeau "Mode hors-ligne".
@MainActor
final class ConnectivityState: ObservableObject {
    static let shared = ConnectivityState()
    private init() {}

    @Published var isOffline: Bool = false
    @Published var lastSyncAt: Date?
    /// Timestamp de la donnée cachée la plus ancienne utilisée pendant le mode offline.
    @Published var oldestCachedAt: Date?

    func markOnline() {
        isOffline = false
        lastSyncAt = Date()
        oldestCachedAt = nil
    }

    func markOffline(cachedAt: Date) {
        isOffline = true
        if let current = oldestCachedAt {
            if cachedAt < current { oldestCachedAt = cachedAt }
        } else {
            oldestCachedAt = cachedAt
        }
    }
}
