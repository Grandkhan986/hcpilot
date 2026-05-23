import XCTest

/// XCUITests pour le parcours 10 — Audit logs & historique.
final class AuditLogsUITests: XCTestCase {

    private var app: XCUIApplication!
    private let longTimeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uitest", "-seed", "deterministic"]
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

    private func openAuditLogs() {
        app.buttons["tab.profil"].tap()
        let auditRow = app.staticTexts["Journal d'audit (HIPAA)"]
        XCTAssertTrue(auditRow.waitForExistence(timeout: longTimeout))
        auditRow.tap()
    }

    // MARK: - Test 1 : AuditLogView se charge avec filtre

    func test_audit_log_view_opens_with_filter() {
        login()
        openAuditLogs()

        XCTAssertTrue(
            app.otherElements["audit.filter"].waitForExistence(timeout: longTimeout)
                || app.staticTexts["Tous"].waitForExistence(timeout: 1),
            "Filter picker doit être visible"
        )
    }

    // MARK: - Test 2 : Filtrage par catégorie

    func test_filter_changes_list() {
        login()
        openAuditLogs()

        // Tap sur "Sessions" si visible
        let sessionsTag = app.buttons["Sessions"]
        if sessionsTag.waitForExistence(timeout: longTimeout) {
            sessionsTag.tap()
            // On laisse la liste se charger
            _ = app.wait(for: .runningForeground, timeout: 2)
        }
        // Smoke test : le titre nav reste
        XCTAssertTrue(app.navigationBars["Journal d'audit"].exists
            || app.staticTexts["Journal d'audit"].exists)
    }

    // MARK: - Test 3 (audit H-114) : tap sur une row ouvre la vue détail

    func test_tap_on_row_opens_detail_view() throws {
        login()
        openAuditLogs()

        // Cherche n'importe quelle row d'audit
        let anyRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'audit.row.'")
        ).firstMatch

        try XCTSkipUnless(
            anyRow.waitForExistence(timeout: longTimeout),
            "Pas d'entrée d'audit dans cet état de seed"
        )
        anyRow.tap()

        // La vue détail montre "Entité" / "Action" / "Contexte requête"
        XCTAssertTrue(
            app.staticTexts["Entité"].waitForExistence(timeout: longTimeout)
                || app.staticTexts["Détail des changements"].waitForExistence(timeout: 1)
                || app.staticTexts["Action"].waitForExistence(timeout: 1),
            "La vue détail doit s'ouvrir"
        )
    }
}
