import XCTest

/// XCUITests pour le parcours 4 — Consentement signature flow.
/// Couvre :
/// - le rendu initial du wizard (Step 0 — sélection standing order)
/// - les a11y identifiers + structure des étapes
/// - le confirm dismiss à partir de la step 1 (skipped UI-T2)
///
/// Le parcours nominal complet (signature PencilKit + POST /consents) n'est
/// pas testable en XCUI standard sans tooling spécifique pour dessiner sur
/// PKCanvasView. À ré-activer une fois un harness de mock signature en place
/// (cf. TODO UI-T3).
final class ConsentSignatureUITests: XCTestCase {

    private var app: XCUIApplication!
    private let longTimeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uitest", "-uitest-skipOnboarding", "-seed", "deterministic"]
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

    /// Navigue vers une session du jour (depuis l'Accueil) et ouvre son détail.
    /// Utilise vis_001 (Myers Cocktail, status scheduled).
    private func openSessionDetail() {
        let tab = app.buttons["tab.accueil"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()

        let sessionLink = app.buttons["home.todaySession.vis_001"]
        if !sessionLink.waitForExistence(timeout: longTimeout) {
            app.swipeUp()
        }
        XCTAssertTrue(sessionLink.waitForExistence(timeout: 5), "Session vis_001 introuvable")
        sessionLink.tap()
    }

    /// Ouvre le wizard de consentement. Retourne false si le CTA n'est pas
    /// visible — cas où la session a déjà un consent signé d'une run
    /// précédente (le backend mock garde l'état entre tests).
    @discardableResult
    private func openConsentFlow() -> Bool {
        let cta = app.buttons["session.openConsentFlow"]
        guard cta.waitForExistence(timeout: longTimeout) else {
            return false
        }
        cta.tap()
        return true
    }

    // MARK: - Test 1 : Standing orders chargées ou empty state visible

    func test_consent_flow_shows_so_list_or_empty_state() throws {
        login()
        openSessionDetail()
        try XCTSkipUnless(openConsentFlow(), "Session déjà signée d'une run précédente")

        let anySO = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'consent.so.'")).firstMatch
        let emptyState = app.otherElements["consent.so.empty"]

        let appeared = anySO.waitForExistence(timeout: longTimeout)
            || emptyState.waitForExistence(timeout: 1)
        XCTAssertTrue(appeared, "Liste SO ou empty state doivent s'afficher")
    }

    // MARK: - Test 2 : Fermer depuis step 0 ne demande pas confirm

    func test_close_from_step0_dismisses_directly() throws {
        login()
        openSessionDetail()
        try XCTSkipUnless(openConsentFlow(), "Session déjà signée d'une run précédente")

        let close = app.buttons["consent.close"]
        XCTAssertTrue(close.waitForExistence(timeout: longTimeout))
        close.tap()

        XCTAssertFalse(
            app.buttons["Continuer"].waitForExistence(timeout: 1),
            "Pas de confirm sur step 0"
        )
    }

    // MARK: - Test 4 : parcours nominal complet via debug-fill signature
    //
    // Fork A Lot 1 / UI-T3 : ré-activé via bouton "Signature de test" injecté
    // dans SignatureStep quand `-uitest` est dans launchArguments. Le bouton
    // remplit canvasView.drawing avec un trait canned qui passe
    // isSignatureUsable (40×20pt minimum).
    func test_consent_full_flow_with_signature() throws {
        login()
        openSessionDetail()
        try XCTSkipUnless(openConsentFlow(), "Session déjà signée d'une run précédente")

        // Step 0 — sélectionner une SO
        let anySO = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'consent.so.'")
        ).firstMatch
        try XCTSkipUnless(
            anySO.waitForExistence(timeout: longTimeout),
            "Pas de standing order active dans le seed"
        )
        anySO.tap()

        // Step 1 — Continuer
        let textContinue = app.buttons["consent.text.continue"]
        XCTAssertTrue(textContinue.waitForExistence(timeout: longTimeout))
        textContinue.tap()

        // Step 2 — cocher tous les checkpoints
        let toggles = app.switches.matching(
            NSPredicate(format: "identifier BEGINSWITH 'consent.checkpoint.'")
        )
        for i in 0..<toggles.count {
            let t = toggles.element(boundBy: i)
            if t.exists { t.tap() }
        }
        let toSignature = app.buttons["consent.checkpoints.continue"]
        XCTAssertTrue(toSignature.waitForExistence(timeout: 3))
        toSignature.tap()

        // Step 3 — debug fill + confirm
        let debugFill = app.buttons["consent.signature.debugFill"]
        XCTAssertTrue(
            debugFill.waitForExistence(timeout: longTimeout),
            "Le bouton debug signature doit être présent en mode -uitest"
        )
        debugFill.tap()

        let confirm = app.buttons["consent.signature.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertTrue(confirm.isEnabled, "Le confirm doit s'activer après debug fill")
        confirm.tap()

        // Alert succès "Consentement enregistré"
        XCTAssertTrue(
            app.alerts.staticTexts["Consentement enregistré"].waitForExistence(timeout: longTimeout)
                || app.staticTexts["Consentement enregistré"].waitForExistence(timeout: 2),
            "Le succès doit être affiché en alert"
        )
    }
}
