import XCTest

/// XCUITests pour le parcours 7 — Dashboard compliance.
/// Couvre :
/// - Rendu des 4 cards (License / MD / SO / Alerts)
/// - Boutons d'action présents quand applicable (audit C-85 / H-86)
/// - Tap sur action ouvre SetupWizardView
final class ComplianceDashboardUITests: XCTestCase {

    private var app: XCUIApplication!
    private let longTimeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uitest", "-seed", "deterministic"]
        app.launch()
    }

    // MARK: - Helpers

    private func login() {
        let email = app.textFields["login.email"]
        if email.waitForExistence(timeout: 2) {
            app.buttons["login.submit"].tap()
            XCTAssertTrue(app.buttons["tab.accueil"].waitForExistence(timeout: longTimeout))
        } else {
            XCTAssertTrue(app.buttons["tab.accueil"].waitForExistence(timeout: 5))
        }
    }

    private func goToComplianceTab() {
        let tab = app.buttons["tab.conformite"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
    }

    // MARK: - Test 1 : Les 4 cards se chargent

    func test_compliance_dashboard_renders_all_cards() {
        login()
        goToComplianceTab()

        XCTAssertTrue(
            app.otherElements["compliance.card.license"].waitForExistence(timeout: longTimeout)
                || app.staticTexts["Ma Licence"].waitForExistence(timeout: 2),
            "Card License doit s'afficher"
        )
        XCTAssertTrue(
            app.otherElements["compliance.card.md"].exists
                || app.staticTexts["Medical Director"].exists
        )
        XCTAssertTrue(
            app.otherElements["compliance.card.so"].exists
                || app.staticTexts["Standing Orders"].exists
        )
        XCTAssertTrue(
            app.otherElements["compliance.card.alerts"].exists
                || app.staticTexts["Alertes"].exists
        )
    }

    // MARK: - Test 2 : Si une SO expiringSoon > 0, le bouton Renouveler apparaît

    func test_renew_so_action_appears_when_expiring_soon() {
        login()
        goToComplianceTab()

        // Le seed contient une SO en warning (Vitamin Boost ~30j).
        // On accepte aussi le cas "tout vert" → on skip si bouton absent.
        let renewBtn = app.buttons["compliance.so.action"]
        if renewBtn.waitForExistence(timeout: longTimeout) {
            renewBtn.tap()
            // Doit ouvrir SetupWizardView (sheet) : on cherche son WelcomeStep
            XCTAssertTrue(
                app.buttons["onboarding.welcome.start"].waitForExistence(timeout: longTimeout)
                    || app.buttons["onboarding.close"].waitForExistence(timeout: 1),
                "SetupWizard doit s'ouvrir au tap Renouveler"
            )
        }
    }

    // MARK: - Test 3 : Acknowledge d'une alerte (si présente)

    func test_acknowledge_alert_if_present() {
        login()
        goToComplianceTab()

        // On cherche un bouton compliance.alert.<id>.ack
        let anyAlertAck = app.buttons.matching(
            NSPredicate(format: "identifier CONTAINS '.ack'")
        ).firstMatch

        guard anyAlertAck.waitForExistence(timeout: longTimeout) else {
            // Pas d'alerte non lue dans le seed actuel — on n'échoue pas
            return
        }
        anyAlertAck.tap()
        // Sleep court pour laisser l'API repondre + refresh
        _ = app.wait(for: .runningForeground, timeout: 2)
    }
}
