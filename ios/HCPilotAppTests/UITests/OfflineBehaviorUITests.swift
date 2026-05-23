import XCTest

/// XCUITests pour le parcours 8 — Comportement offline.
///
/// Limitation : XCUI ne fournit pas d'API native pour couper le réseau du
/// simulateur. Pour tester le drain end-to-end, il faudrait :
///   - soit un toggle "mock network offline" derrière un launchArgument
///   - soit le Network Link Conditioner (process externe, fragile en CI)
///
/// On se limite ici à :
///   - vérifier l'accès à MutationQueueView depuis Profil
///   - vérifier la présence du badge sync sur le Home
///   - vérifier le confirm sur "Vider la file" (si la queue n'est pas vide)
final class OfflineBehaviorUITests: XCTestCase {

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

    // MARK: - Test 1 : Sync badge présent sur Home

    func test_home_shows_sync_status_badge() {
        login()
        app.buttons["tab.accueil"].tap()
        // Le badge est dans le header (à droite). On vérifie la présence d'au
        // moins un label "Sync" ou "À jour" ou "Hors-ligne".
        let anyText = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'Sync' OR label CONTAINS[c] 'jour' OR label CONTAINS[c] 'ors-ligne'")
        ).firstMatch
        XCTAssertTrue(anyText.waitForExistence(timeout: longTimeout))
    }

    // MARK: - Test 2 : Accès MutationQueueView depuis Profil

    func test_profile_opens_mutation_queue_view() {
        login()
        app.buttons["tab.profil"].tap()

        // Le NavigationLink "File de synchronisation" n'a pas d'identifier dédié,
        // on tape sur le label.
        let queueRow = app.staticTexts["File de synchronisation"]
        XCTAssertTrue(queueRow.waitForExistence(timeout: longTimeout))
        queueRow.tap()

        // L'écran cible doit afficher le connectivity row
        XCTAssertTrue(
            app.otherElements["mutationQueue.connectivity"].waitForExistence(timeout: longTimeout)
                || app.staticTexts["En ligne"].waitForExistence(timeout: 1)
                || app.staticTexts["Hors-ligne"].waitForExistence(timeout: 1)
        )
    }

    // MARK: - Test 3 : Confirm sur "Vider la file" si queue non vide (skip si vide)

    func test_clear_queue_shows_confirm_when_non_empty() throws {
        login()
        app.buttons["tab.profil"].tap()
        app.staticTexts["File de synchronisation"].tap()

        let clear = app.buttons["mutationQueue.clear"]
        try XCTSkipUnless(
            clear.waitForExistence(timeout: longTimeout),
            "Queue vide à ce stade du run — pas de bouton Vider"
        )
        clear.tap()

        // Fork A Lot 1 / UI-T2 : alert au lieu de confirmationDialog → queryable.
        XCTAssertTrue(
            app.alerts.buttons["Vider"].waitForExistence(timeout: longTimeout),
            "L'alerte de confirmation doit s'afficher"
        )
        // Cancel pour ne pas réellement vider la queue
        app.alerts.buttons["Annuler"].tap()
    }
}
