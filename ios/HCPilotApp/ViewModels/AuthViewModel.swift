import Foundation
import Alamofire

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var user: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sessionLocked = false  // affiche un toast après auto-logout par inactivité

    private let apiService = APIService.shared
    private var unauthorizedObserver: NSObjectProtocol?

    init() {
        // Restauration silencieuse de session si Keychain en a une.
        restoreSession()
        // Audit H15 — auto-logout sur 401 (token rejeté serveur).
        unauthorizedObserver = NotificationCenter.default.addObserver(
            forName: .hcpilotSessionUnauthorized,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Closure non-isolée → re-saute sur le main actor pour muter
            // l'état publié de AuthViewModel.
            Task { @MainActor [weak self] in
                guard let self = self, self.isAuthenticated else { return }
                self.sessionLocked = true
                self.isAuthenticated = false
                self.user = nil
            }
        }
    }

    deinit {
        if let obs = unauthorizedObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func login(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Veuillez remplir tous les champs."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await apiService.login(email: email, password: password)
            self.user = response.user
            self.isAuthenticated = true
            self.errorMessage = nil
            self.sessionLocked = false
            persistUserProfile(response.user)
        } catch {
            self.errorMessage = "Erreur: \(error.localizedDescription)"
        }
    }

    func logout() {
        apiService.clearToken()
        isAuthenticated = false
        user = nil
        sessionLocked = false
        // C-01 — reset le cache onboarding pour ne pas mélanger entre comptes.
        // ContentView observe isAuthenticated et appelle reset() de toute façon,
        // mais on le force ici aussi pour les flux directs (ProfileView.logout).
        OnboardingState.shared.reset()
    }

    /// Vérifie si la session est expirée par inactivité. À appeler au lancement
    /// et au retour foreground. Brief : "Auto-logout après 30 minutes (configurable)".
    func checkInactivityLock() {
        guard isAuthenticated else { return }
        guard let last = SecureStorage.shared.getDate(forKey: .lastActivity) else { return }
        let elapsed = Date().timeIntervalSince(last)
        if elapsed > SecuritySettings.inactivityTimeoutSeconds {
            print("[HCPilot] Session expirée par inactivité (\(Int(elapsed / 60)) min)")
            sessionLocked = true
            logout()
        }
    }

    /// Restauration au boot — utilisée par init() et après la création de
    /// l'AuthViewModel.
    private func restoreSession() {
        guard let token = SecureStorage.shared.getString(forKey: .authToken) else {
            isAuthenticated = false
            return
        }

        // Lock par inactivité avant restauration : si la session est trop vieille,
        // on purge tout et on présente le login.
        if let last = SecureStorage.shared.getDate(forKey: .lastActivity) {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed > SecuritySettings.inactivityTimeoutSeconds {
                sessionLocked = true
                apiService.clearToken()
                return
            }
        }

        apiService.setToken(token)
        if let data = SecureStorage.shared.getData(forKey: .userProfile),
           let restored = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.user = restored
        }
        isAuthenticated = true
    }

    private func persistUserProfile(_ user: UserProfile) {
        if let data = try? JSONEncoder().encode(user) {
            SecureStorage.shared.setData(data, forKey: .userProfile)
        }
    }
}
