import XCTest
@testable import HCPilotApp

/// C-01 — Tests du gate first-launch onboarding.
///
/// Tests purs sur la logique de `OnboardingState` :
/// - Cache UserDefaults pour fast-boot
/// - reset() au logout
/// - markComplete() au callback du wizard
///
/// Le test du wiring ContentView (qui affiche le wizard) est dans
/// `OnboardingGateUITests.swift` (parcours XCUI).
@MainActor
final class OnboardingGateTests: XCTestCase {

    private let cacheKey = "onboarding.completed"
    private let stepKey = "setup.lastStep"

    override func setUp() async throws {
        try await super.setUp()
        // Reset cache pour repartir propre — la classe OnboardingState est
        // un singleton qui mute UserDefaults, on lit/écrit donc le même store.
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: stepKey)
        OnboardingState.shared.reset()
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: stepKey)
        OnboardingState.shared.reset()
        try await super.tearDown()
    }

    // MARK: - Cache UserDefaults

    func test_initial_state_is_false_when_no_cache() {
        OnboardingState.shared.reset()
        XCTAssertFalse(OnboardingState.shared.isComplete)
    }

    func test_markComplete_persists_in_cache() {
        OnboardingState.shared.markComplete()
        XCTAssertTrue(OnboardingState.shared.isComplete)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: cacheKey))
    }

    func test_reset_clears_cache() {
        OnboardingState.shared.markComplete()
        XCTAssertTrue(OnboardingState.shared.isComplete)

        OnboardingState.shared.reset()
        XCTAssertFalse(OnboardingState.shared.isComplete)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: cacheKey))
    }

    // MARK: - SetupWizardViewModel — persistance step

    func test_step_change_persists_to_user_defaults() {
        let vm = SetupWizardViewModel()
        XCTAssertEqual(vm.step, 0)

        vm.step = 2
        XCTAssertEqual(UserDefaults.standard.integer(forKey: stepKey), 2)

        vm.step = 3
        XCTAssertEqual(UserDefaults.standard.integer(forKey: stepKey), 3)
    }

    func test_step_4_done_does_not_persist() {
        let vm = SetupWizardViewModel()
        vm.step = 2  // persist step 2
        XCTAssertEqual(UserDefaults.standard.integer(forKey: stepKey), 2)

        vm.step = 4  // Done — ne doit pas écraser la step persistée
        // La step 4 n'est pas re-persistée → la valeur sauvegardée reste 2
        // (Done est l'écran de récap, on ne veut pas rouvrir dessus)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: stepKey), 2)
    }

    func test_clearPersistedStep_removes_key() {
        UserDefaults.standard.set(2, forKey: stepKey)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: stepKey), 2)

        let vm = SetupWizardViewModel()
        vm.clearPersistedStep()
        XCTAssertEqual(UserDefaults.standard.integer(forKey: stepKey), 0)
    }

    func test_new_viewmodel_resumes_at_persisted_step() {
        UserDefaults.standard.set(2, forKey: stepKey)

        let vm = SetupWizardViewModel()
        XCTAssertEqual(vm.step, 2, "Le wizard doit reprendre à la step persistée")
    }

    func test_new_viewmodel_starts_at_zero_if_no_persisted_step() {
        UserDefaults.standard.removeObject(forKey: stepKey)

        let vm = SetupWizardViewModel()
        XCTAssertEqual(vm.step, 0, "Sans persistance, démarrage à Welcome (step 0)")
    }

    func test_new_viewmodel_ignores_invalid_persisted_step() {
        // Step 4 (Done) ne doit pas être restaurée — on repart à 0.
        UserDefaults.standard.set(4, forKey: stepKey)

        let vm = SetupWizardViewModel()
        XCTAssertEqual(vm.step, 0, "Step Done ne doit pas être restaurée")
    }
}
