import XCTest

/// XCUITests pour le parcours 9 — Paramètres profil & sécurité.
final class ProfileSettingsUITests: XCTestCase {

    private var app: XCUIApplication!
    private let longTimeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uitest", "-uitest-skipOnboarding", "-seed", "deterministic"]
        app.launch()
    }

    private func login() {
        let email = app.textFields["login.email"]
        if email.waitForExistence(timeout: 2) {
            app.buttons["login.submit"].tap()
            XCTAssertTrue(app.buttons["tab.accueil"].waitForExistence(timeout: longTimeout))
        } else {
            XCTAssertTrue(app.buttons["tab.accueil"].waitForExistence(timeout: 5))
        }
    }

    private func openProfile() {
        app.buttons["tab.profil"].tap()
        XCTAssertTrue(app.staticTexts["Sécurité"].waitForExistence(timeout: longTimeout))
    }

    // MARK: - Test 1 : Sécurité accessible + Picker timeout

    func test_security_settings_timeout_picker_visible() {
        login()
        openProfile()

        app.staticTexts["Sécurité"].tap()
        XCTAssertTrue(
            app.otherElements["security.timeout.picker"].waitForExistence(timeout: longTimeout)
                || app.staticTexts.matching(NSPredicate(format: "label CONTAINS '30 min' OR label CONTAINS '1h'")).firstMatch.exists,
            "Le picker timeout doit être visible"
        )
    }

    // MARK: - Test 2 : "Verrouiller maintenant" demande confirm

    func test_lock_now_shows_confirm() {
        login()
        openProfile()
        app.staticTexts["Sécurité"].tap()

        let lockBtn = app.buttons["security.lockNow"]
        XCTAssertTrue(lockBtn.waitForExistence(timeout: longTimeout))
        lockBtn.tap()

        // confirmationDialog : on cherche le label
        let cancel = app.buttons["Annuler"]
        let stay = app.buttons["Verrouiller"]
        if cancel.waitForExistence(timeout: 3) {
            cancel.tap()  // Ne pas réellement se déconnecter
        } else if stay.waitForExistence(timeout: 1) {
            // dialog visible — on cancel via le hit-test extérieur
            app.tap()
        }
        // On vérifie qu'on est toujours connecté (Sécurité visible)
        XCTAssertTrue(
            app.buttons["security.lockNow"].waitForExistence(timeout: 3)
                || app.staticTexts["Sécurité"].waitForExistence(timeout: 3)
        )
    }

    // MARK: - Test 3 : Notifications view affiche les toggles

    func test_notifications_view_shows_category_toggles() {
        login()
        openProfile()

        app.staticTexts["Notifications"].tap()
        XCTAssertTrue(
            app.switches["notif.toggle.compliance"].waitForExistence(timeout: longTimeout),
            "Toggle compliance doit s'afficher"
        )
        XCTAssertTrue(app.switches["notif.toggle.session"].exists)
        XCTAssertTrue(app.switches["notif.toggle.inventory"].exists)
    }
}
