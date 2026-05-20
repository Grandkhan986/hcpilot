import XCTest
@testable import HCPilotApp

/// Brief §HIPAA — Auto-logout 30 min configurable. Tests des seuils.
final class SecuritySettingsTests: XCTestCase {
    private let timeoutKey = "hcpilot.inactivity_timeout_minutes"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: timeoutKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: timeoutKey)
        super.tearDown()
    }

    func test_defaultTimeoutIs30Minutes() {
        XCTAssertEqual(SecuritySettings.inactivityTimeoutMinutes, 30)
        XCTAssertEqual(SecuritySettings.inactivityTimeoutSeconds, 30 * 60)
    }

    func test_overridePersistsInUserDefaults() {
        SecuritySettings.inactivityTimeoutMinutes = 15
        XCTAssertEqual(SecuritySettings.inactivityTimeoutMinutes, 15)
        XCTAssertEqual(SecuritySettings.inactivityTimeoutSeconds, 15 * 60)
    }

    func test_zeroOrNegativeFallsBackToDefault() {
        UserDefaults.standard.set(0, forKey: timeoutKey)
        // 0 is interpreted as "not set" → fallback to default
        XCTAssertEqual(SecuritySettings.inactivityTimeoutMinutes, 30)
    }
}
