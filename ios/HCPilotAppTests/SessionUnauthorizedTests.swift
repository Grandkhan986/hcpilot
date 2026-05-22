import XCTest
@testable import HCPilotApp

/// Audit H15 — vérifie que la notification d'auto-logout sur 401 fonctionne
/// et qu'AuthViewModel y réagit en repassant sur l'écran de login.
final class SessionUnauthorizedTests: XCTestCase {

    @MainActor
    func test_notification_flips_session_locked_when_authenticated() async {
        let vm = AuthViewModel()
        // Force un état "authentifié" sans passer par l'API réelle.
        vm.isAuthenticated = true
        vm.user = nil
        vm.sessionLocked = false

        NotificationCenter.default.post(name: .hcpilotSessionUnauthorized, object: nil)

        // L'observer hop sur le main actor via Task — laisser tourner la run loop.
        let started = Date()
        while !vm.sessionLocked && Date().timeIntervalSince(started) < 1.0 {
            try? await Task.sleep(nanoseconds: 20_000_000) // 20 ms
        }

        XCTAssertTrue(vm.sessionLocked, "401 doit verrouiller la session")
        XCTAssertFalse(vm.isAuthenticated, "401 doit repasser sur l'écran de login")
    }

    @MainActor
    func test_notification_ignored_when_not_authenticated() async {
        let vm = AuthViewModel()
        vm.isAuthenticated = false
        vm.sessionLocked = false

        NotificationCenter.default.post(name: .hcpilotSessionUnauthorized, object: nil)
        try? await Task.sleep(nanoseconds: 100_000_000) // 100 ms

        XCTAssertFalse(vm.sessionLocked, "Un 401 reçu hors session doit être ignoré")
    }

    func test_api_error_unauthorized_has_localized_description() {
        let error: Error = APIError.unauthorized
        XCTAssertEqual(error.localizedDescription, "Session expirée, veuillez vous reconnecter")
    }
}
