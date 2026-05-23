import XCTest

/// XCUITests pour le parcours 1 — Onboarding wizard.
/// Couvre le parcours nominal (Welcome → License → MD → Standing Order → Done)
/// + variantes : empty validation et confirm dismiss avec données partielles.
///
/// Notes d'implémentation :
/// - Les tests parlent au backend réel (FastAPI mock sur localhost:8000).
///   Timeouts larges (10 s+) pour absorber la latence du premier POST.
/// - Les boutons à l'intérieur d'un `Form > Section` voient leur
///   `accessibilityIdentifier` porté par le cell parent (limitation SwiftUI).
///   On query donc par label texte plutôt que par identifier sur ces éléments.
/// - Le simulateur garde le token en Keychain entre relances → `login()`
///   est résilient (no-op si déjà authentifié).
final class OnboardingUITests: XCTestCase {

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
            XCTAssertTrue(
                app.buttons["tab.accueil"].waitForExistence(timeout: longTimeout),
                "Login a échoué — tab bar non visible"
            )
        } else {
            XCTAssertTrue(
                app.buttons["tab.accueil"].waitForExistence(timeout: 5),
                "Ni login ni tab bar — état app inattendu"
            )
        }
    }

    private func goToProfileTab() {
        let tab = app.buttons["tab.profil"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.tap()
    }

    private func openWizard() {
        let opener = app.buttons["profile.openSetupWizard"]
        XCTAssertTrue(opener.waitForExistence(timeout: 5))
        opener.tap()
    }

    private func tapWelcomeStart() {
        let welcomeStart = app.buttons["onboarding.welcome.start"]
        XCTAssertTrue(welcomeStart.waitForExistence(timeout: 5), "WelcomeStep doit s'afficher")
        welcomeStart.tap()
    }

    private func type(into field: XCUIElement, text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
    }

    private func dismissKeyboard() {
        app.navigationBars.firstMatch.tap()
    }

    /// Bouton « Continuer » de la page courante. Dans Form/Section,
    /// l'identifier est sur le cell — on filtre par label texte.
    private var visibleContinueButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == 'Continuer'")).firstMatch
    }

    // MARK: - Test 1 : parcours nominal complet
    //
    // Connu fragile : la transition de TabView paginée + les POST séquentiels
    // au backend rendent l'attente du bouton « Continuer » de la step
    // suivante peu déterministe sans mock réseau. À ré-activer une fois le
    // mock APIService en place (cf. audit-parcours/TODO-improvements.md UI-T1).
    func test_onboarding_nominal_flow_reaches_done() throws {
        try XCTSkipIf(true, "TabView paginée + backend live = flaky. Voir TODO UI-T1.")

        login()
        goToProfileTab()
        openWizard()
        tapWelcomeStart()

        // Step 1 — License
        type(into: app.textFields["onboarding.firstName"], text: "Sarah")
        type(into: app.textFields["onboarding.lastName"], text: "Johnson")
        type(into: app.textFields["onboarding.licenseNumber"], text: "RN-CA-2024-99887")
        dismissKeyboard()

        XCTAssertTrue(visibleContinueButton.waitForExistence(timeout: 5))
        XCTAssertTrue(visibleContinueButton.isEnabled, "Continuer License doit être actif")
        visibleContinueButton.tap()

        // Step 2 — Medical Director (champs préfixés .md.)
        let mdFirst = app.textFields["onboarding.md.firstName"]
        XCTAssertTrue(mdFirst.waitForExistence(timeout: longTimeout), "MD step doit s'ouvrir")
        type(into: mdFirst, text: "James")
        type(into: app.textFields["onboarding.md.lastName"], text: "Patterson")
        type(into: app.textFields["onboarding.md.email"], text: "md.patterson@example.com")
        type(into: app.textFields["onboarding.md.licenseNumber"], text: "MD-CA-2022-A1234")
        dismissKeyboard()

        XCTAssertTrue(visibleContinueButton.waitForExistence(timeout: 5))
        XCTAssertTrue(visibleContinueButton.isEnabled)
        visibleContinueButton.tap()

        // Step 3 — Standing Order
        XCTAssertTrue(
            visibleContinueButton.waitForExistence(timeout: longTimeout),
            "SO step doit s'ouvrir après création MD"
        )
        visibleContinueButton.tap()

        // Step 4 — Done : on identifie le titre par son label texte (plus
        // robuste qu'identifier sur Text dans un VStack).
        XCTAssertTrue(
            app.staticTexts["Configuration terminée"].waitForExistence(timeout: longTimeout),
            "DoneStep doit être atteinte"
        )
    }

    // MARK: - Test 2 : la validation bloque le passage de la step License

    func test_license_step_does_not_advance_when_required_fields_empty() {
        login()
        goToProfileTab()
        openWizard()
        tapWelcomeStart()

        // Form chargé ?
        XCTAssertTrue(
            app.textFields["onboarding.firstName"].waitForExistence(timeout: 5)
        )

        // Tap sur « Continuer » sans rien saisir — devrait être un no-op
        // (.disabled). On vérifie en attendant 2 s la step MD qui ne doit
        // PAS apparaître.
        if visibleContinueButton.exists {
            // tap may be a no-op if disabled — that's exactly ce qu'on veut tester
            visibleContinueButton.tap()
        }
        XCTAssertFalse(
            app.textFields["onboarding.md.firstName"].waitForExistence(timeout: 2),
            "MD step ne doit PAS apparaître si les champs License sont vides"
        )
    }

    // MARK: - Test 3 : confirm dismiss quand données partielles non envoyées
    //
    // Connu fragile : SwiftUI `confirmationDialog` ne semble pas exposer ses
    // boutons de façon fiable aux requêtes XCUI dans iOS 18+. À investiguer
    // (changer pour `alert(...)` ? interroger `.dialogs[...]`?). Voir TODO UI-T2.
    func test_close_with_unsaved_work_shows_confirm() throws {
        try XCTSkipIf(true, "Query confirmationDialog flaky en XCUI. Voir TODO UI-T2.")

        login()
        goToProfileTab()
        openWizard()
        tapWelcomeStart()

        type(into: app.textFields["onboarding.firstName"], text: "Sarah")
        dismissKeyboard()

        app.buttons["onboarding.close"].tap()

        // Le confirmationDialog : SwiftUI le surface en sheet sur iOS récent.
        // On essaie plusieurs containers + une query directe sur le bouton.
        let buttonLabel = "Continuer la configuration"
        let stayInSheet = app.sheets.buttons[buttonLabel]
        let stayInAlert = app.alerts.buttons[buttonLabel]
        let stayAnywhere = app.buttons[buttonLabel]

        let appeared = stayInSheet.waitForExistence(timeout: longTimeout)
            || stayInAlert.waitForExistence(timeout: 1)
            || stayAnywhere.waitForExistence(timeout: 1)
        XCTAssertTrue(appeared, "Le dialog de confirmation doit s'afficher")

        if stayInSheet.exists { stayInSheet.tap() }
        else if stayInAlert.exists { stayInAlert.tap() }
        else { stayAnywhere.tap() }

        XCTAssertTrue(
            app.textFields["onboarding.firstName"].waitForExistence(timeout: 5),
            "Le wizard doit rester ouvert après « Continuer la configuration »"
        )
    }

    // MARK: - Test 4 : close sans saisie ne demande PAS confirmation

    func test_close_without_work_does_not_show_confirm() {
        login()
        goToProfileTab()
        openWizard()

        XCTAssertTrue(app.buttons["onboarding.welcome.start"].waitForExistence(timeout: 5))
        app.buttons["onboarding.close"].tap()

        XCTAssertFalse(
            app.buttons["Continuer la configuration"].waitForExistence(timeout: 1),
            "Pas de confirm quand aucune saisie"
        )
        XCTAssertTrue(app.buttons["profile.openSetupWizard"].waitForExistence(timeout: 3))
    }
}
