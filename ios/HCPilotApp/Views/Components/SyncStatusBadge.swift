import SwiftUI

/// Badge discret affiché dans le header de l'écran d'accueil (brief §refonte
/// Home — indicateur sync/connectivité). Lit `ConnectivityState` et
/// `MutationQueue` pour donner une visibilité immédiate sur l'état réseau.
struct SyncStatusBadge: View {
    @ObservedObject private var connectivity = ConnectivityState.shared
    @ObservedObject private var queue = MutationQueue.shared
    /// Permet à l'écran qui hôte le badge de signaler une sync en cours.
    let isSyncing: Bool

    init(isSyncing: Bool = false) {
        self.isSyncing = isSyncing
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Statut de synchronisation : \(label)")
    }

    // MARK: - State

    private enum SyncState {
        case syncing
        case offlineWithPending
        case offline
        case onlineFresh(minutes: Int)
        case online
    }

    private var state: SyncState {
        if isSyncing { return .syncing }
        if connectivity.isOffline {
            return queue.count > 0 ? .offlineWithPending : .offline
        }
        if let last = connectivity.lastSyncAt {
            let minutes = Int(Date().timeIntervalSince(last) / 60)
            return .onlineFresh(minutes: max(minutes, 0))
        }
        return .online
    }

    private var icon: String {
        switch state {
        case .syncing: return "arrow.triangle.2.circlepath"
        case .offlineWithPending: return "exclamationmark.triangle.fill"
        case .offline: return "wifi.slash"
        case .onlineFresh, .online: return "checkmark.circle.fill"
        }
    }

    private var tint: Color {
        switch state {
        case .syncing: return .blue
        case .offlineWithPending: return .red
        case .offline: return .orange
        case .onlineFresh, .online: return .green
        }
    }

    private var label: String {
        switch state {
        case .syncing:
            return "Synchronisation…"
        case .offlineWithPending:
            return "Hors-ligne, \(queue.count) en attente"
        case .offline:
            return "Hors-ligne"
        case .onlineFresh(let minutes):
            if minutes < 1 { return "Sync à l'instant" }
            if minutes < 60 { return "Sync il y a \(minutes)m" }
            return "Sync il y a \(minutes / 60)h"
        case .online:
            return "À jour"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SyncStatusBadge()
        SyncStatusBadge(isSyncing: true)
    }
    .padding()
}
