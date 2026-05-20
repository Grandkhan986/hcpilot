import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var connectivity = ConnectivityState.shared
    @StateObject private var mutationQueue = MutationQueue.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if authViewModel.isAuthenticated {
                    AppMainView()
                } else {
                    LoginView()
                        .overlay(alignment: .top) {
                            if authViewModel.sessionLocked {
                                sessionLockedBanner
                                    .padding(.top, 50)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                }
            }

            // Bandeau global : visible quand on sert des données du cache
            // (brief §Gestion offline).
            if connectivity.isOffline && authViewModel.isAuthenticated {
                offlineBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .environmentObject(authViewModel)
        .environmentObject(connectivity)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Au retour foreground, on revérifie la session (brief : auto-logout
                // après inactivité). Si la dernière activité date de plus que le
                // seuil configuré, l'utilisateur revoit le login.
                authViewModel.checkInactivityLock()
            }
        }
        .animation(.easeInOut, value: authViewModel.sessionLocked)
        .animation(.easeInOut, value: connectivity.isOffline)
    }

    private var offlineBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
            VStack(alignment: .leading, spacing: 2) {
                Text("Mode hors-ligne").font(.caption).fontWeight(.semibold)
                if let cached = connectivity.oldestCachedAt {
                    Text("Données du \(formatRelative(cached))")
                        .font(.caption2)
                        .opacity(0.85)
                }
                if mutationQueue.count > 0 {
                    Text("\(mutationQueue.count) action\(mutationQueue.count > 1 ? "s" : "") en attente")
                        .font(.caption2)
                        .opacity(0.9)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.95))
        .foregroundStyle(.white)
        .padding(.top, 50)  // sous la dynamic island
    }

    private func formatRelative(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .none
        f.timeStyle = .short
        // Si > 1 jour, montre la date courte
        if Date().timeIntervalSince(date) > 86_400 {
            f.dateStyle = .short
        }
        return f.string(from: date)
    }

    private var sessionLockedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield.fill")
            Text("Session verrouillée par inactivité")
                .font(.caption).fontWeight(.semibold)
        }
        .padding(10)
        .background(Color.orange.opacity(0.95))
        .foregroundStyle(.white)
        .clipShape(Capsule())
        .shadow(radius: 4)
    }
}

#Preview {
    ContentView()
}
