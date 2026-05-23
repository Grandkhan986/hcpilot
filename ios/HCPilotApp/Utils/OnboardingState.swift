import Foundation
import SwiftUI

/// Gate C-01 — vérifie si la nurse a complété son onboarding réglementaire
/// (licence + Medical Director actif + ≥1 standing order actif). Tant que ce
/// n'est pas le cas, ContentView bloque l'accès à AppMainView et force
/// l'affichage du SetupWizardView en plein écran.
///
/// Source de vérité : `GET /v1/compliance/dashboard`. On cache le résultat
/// dans UserDefaults pour le fast-path au boot (offline-friendly) ; un evaluate()
/// reéévalue depuis le backend dès qu'on est en ligne.
@MainActor
final class OnboardingState: ObservableObject {
    static let shared = OnboardingState()

    /// État courant. `nil` au boot avant la première évaluation.
    @Published var isComplete: Bool = false
    @Published var isEvaluating: Bool = false

    private let api = APIService.shared
    private let userDefaultsKey = "onboarding.completed"

    private init() {
        // Fast-path : on lit le cache local pour ne pas bloquer l'UI au boot.
        // L'évaluation backend confirme ou infirme dès le premier appel.
        isComplete = UserDefaults.standard.bool(forKey: userDefaultsKey)

        // Fork A Lot 1 — bypass du gate pour les UI tests qui doivent
        // accéder à AppMainView (Profile, etc.) sans passer par le wizard.
        // À ne pas confondre avec `-uitest` seul qui n'affecte que la
        // signature canned du consent flow.
        if ProcessInfo.processInfo.arguments.contains("-uitest-skipOnboarding") {
            isComplete = true
            UserDefaults.standard.set(true, forKey: userDefaultsKey)
            // Reset aussi la step persistée du wizard pour que les tests
            // qui ouvrent SetupWizardView en editFromProfile démarrent à
            // step 0 (Welcome).
            UserDefaults.standard.removeObject(forKey: "setup.lastStep")
        }
    }

    /// Évalue depuis le backend. Sur succès, met à jour le cache local.
    /// Sur échec (offline / 401), conserve le cache existant.
    func evaluate() async {
        isEvaluating = true
        defer { isEvaluating = false }
        do {
            let dash = try await api.getComplianceDashboard()
            let hasLicense = (dash.license?.licenseNumber?.isEmpty == false)
                && dash.license?.expirationDate != nil
            let hasActiveMD = dash.medicalDirector?.isActive ?? false
            let hasActiveSO = dash.standingOrders.contains { $0.isActive }
            let complete = hasLicense && hasActiveMD && hasActiveSO
            isComplete = complete
            UserDefaults.standard.set(complete, forKey: userDefaultsKey)
        } catch {
            // Offline ou erreur : on conserve l'état précédent. Si la nurse a
            // jamais complété son onboarding (cache = false), elle voit le
            // wizard ; sinon elle accède à l'app avec le cache.
        }
    }

    /// Reset complet — appelé au logout pour ne pas mélanger les caches
    /// entre comptes.
    func reset() {
        isComplete = false
        UserDefaults.standard.set(false, forKey: userDefaultsKey)
    }

    /// Marque complet manuellement après que SetupWizardView signale fin de
    /// flow. Sert à débloquer immédiatement l'UI sans attendre une nouvelle
    /// requête réseau.
    func markComplete() {
        isComplete = true
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
    }
}
