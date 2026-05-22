import XCTest
@testable import HCPilotApp

/// Tests des validateurs (audit M1) — règles métier réutilisables.
final class ValidatorsTests: XCTestCase {

    // MARK: - Email

    func test_email_accepts_valid() {
        XCTAssertTrue(Validators.isValidEmail("nurse@hcpilot.com"))
        XCTAssertTrue(Validators.isValidEmail("first.last+tag@example.co.uk"))
    }

    func test_email_rejects_invalid() {
        XCTAssertFalse(Validators.isValidEmail(""))
        XCTAssertFalse(Validators.isValidEmail("not-an-email"))
        XCTAssertFalse(Validators.isValidEmail("missing@tld"))
        XCTAssertFalse(Validators.isValidEmail("@nodomain.com"))
    }

    // MARK: - Phone US

    func test_phone_us_accepts_10_digits() {
        XCTAssertTrue(Validators.isValidPhoneUS("5551234567"))
        XCTAssertTrue(Validators.isValidPhoneUS("(555) 123-4567"))
    }

    func test_phone_us_accepts_11_digits_with_country_code() {
        XCTAssertTrue(Validators.isValidPhoneUS("15551234567"))
        XCTAssertTrue(Validators.isValidPhoneUS("1 (555) 123-4567"))
    }

    func test_phone_us_rejects_wrong_length() {
        XCTAssertFalse(Validators.isValidPhoneUS(""))
        XCTAssertFalse(Validators.isValidPhoneUS("123"))
        XCTAssertFalse(Validators.isValidPhoneUS("123456789"))   // 9 chiffres
        XCTAssertFalse(Validators.isValidPhoneUS("25551234567")) // 11 chiffres mais pas 1
    }

    func test_phone_us_formats_brief_style() {
        XCTAssertEqual(Validators.formattedPhoneUS("5551234567"), "(555) 123-4567")
        XCTAssertEqual(Validators.formattedPhoneUS("15551234567"), "(555) 123-4567")
        // Pas une longueur US valide : retourne tel quel
        XCTAssertEqual(Validators.formattedPhoneUS("12345"), "12345")
        XCTAssertEqual(Validators.formattedPhoneUS(""), "")
    }

    // MARK: - Age

    func test_adult_accepts_18_plus() {
        let ref = ISO8601DateFormatter().date(from: "2026-05-22T12:00:00Z")!
        let cal = Calendar(identifier: .gregorian)
        let dob18 = cal.date(byAdding: .year, value: -18, to: ref)!
        let dob50 = cal.date(byAdding: .year, value: -50, to: ref)!
        XCTAssertTrue(Validators.isAdult(dateOfBirth: dob18, on: ref))
        XCTAssertTrue(Validators.isAdult(dateOfBirth: dob50, on: ref))
    }

    func test_adult_rejects_minor() {
        let ref = ISO8601DateFormatter().date(from: "2026-05-22T12:00:00Z")!
        let cal = Calendar(identifier: .gregorian)
        let dob17 = cal.date(byAdding: .year, value: -17, to: ref)!
        XCTAssertFalse(Validators.isAdult(dateOfBirth: dob17, on: ref))
    }

    func test_adult_from_string() {
        XCTAssertEqual(Validators.isAdult(dateOfBirthString: "1990-01-01"), true)
        XCTAssertEqual(Validators.isAdult(dateOfBirthString: "2025-01-01"), false)
        XCTAssertNil(Validators.isAdult(dateOfBirthString: "not-a-date"))
    }

    // MARK: - Licence + state

    func test_license_number_format() {
        XCTAssertTrue(Validators.isValidLicenseNumber("RN-CA-2024-12345"))
        XCTAssertTrue(Validators.isValidLicenseNumber("NP123"))
        XCTAssertFalse(Validators.isValidLicenseNumber(""))
        XCTAssertFalse(Validators.isValidLicenseNumber("RN1"))    // < 4 chars
        XCTAssertFalse(Validators.isValidLicenseNumber("RN 123")) // espace interdit
    }

    func test_state_code_format() {
        XCTAssertTrue(Validators.isValidStateCode("CA"))
        XCTAssertTrue(Validators.isValidStateCode("tx"))   // uppercased par la func
        XCTAssertFalse(Validators.isValidStateCode("California"))
        XCTAssertFalse(Validators.isValidStateCode("C1"))
    }

    // MARK: - NPI

    func test_npi_format() {
        XCTAssertTrue(Validators.isValidNPI("1234567890"))
        XCTAssertTrue(Validators.isValidNPI("1234-567-890"))  // tirets tolérés
        XCTAssertFalse(Validators.isValidNPI("123456789"))    // 9 chiffres
        XCTAssertFalse(Validators.isValidNPI("12345678901"))  // 11
    }
}
