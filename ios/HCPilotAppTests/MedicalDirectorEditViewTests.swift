import XCTest
@testable import HCPilotApp

/// H-104 — Tests purs sur le ViewModel d'édition MD (renouvellement contrat,
/// validation, init depuis modèle).
@MainActor
final class MedicalDirectorEditViewTests: XCTestCase {

    private func makeMD(
        contractEnd: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    ) -> MedicalDirectorInfo {
        MedicalDirectorInfo(
            id: "md_test",
            nurseId: "usr_001",
            firstName: "James",
            lastName: "Patterson",
            email: "md@example.com",
            licenseNumber: "MD-CA-2022-A1234",
            stateCode: "CA",
            contractStartDate: Date(timeIntervalSince1970: 1700000000),
            contractEndDate: contractEnd,
            auditFrequencyDays: 30,
            nextAuditDate: nil,
            isActive: true,
            contractStatus: nil,
            nextAuditStatus: nil
        )
    }

    func test_init_prefills_from_md() {
        let md = makeMD()
        let vm = MedicalDirectorEditViewModel(md: md)
        XCTAssertEqual(vm.firstName, "James")
        XCTAssertEqual(vm.lastName, "Patterson")
        XCTAssertEqual(vm.email, "md@example.com")
        XCTAssertEqual(vm.licenseNumber, "MD-CA-2022-A1234")
        XCTAssertEqual(vm.stateCode, "CA")
        XCTAssertEqual(vm.auditFrequencyDays, 30)
    }

    func test_renew_contract_adds_12_months() {
        let original = Date(timeIntervalSince1970: 1716393600)  // 2024-05-22
        let md = makeMD(contractEnd: original)
        let vm = MedicalDirectorEditViewModel(md: md)
        XCTAssertEqual(vm.contractEnd, original)

        vm.renewContract()
        let expected = Calendar.current.date(byAdding: .year, value: 1, to: original)
        XCTAssertEqual(vm.contractEnd, expected, "Renouvellement ajoute exactement +1 an")
    }

    func test_renew_contract_chained() {
        let original = Date(timeIntervalSince1970: 1716393600)
        let md = makeMD(contractEnd: original)
        let vm = MedicalDirectorEditViewModel(md: md)

        vm.renewContract()
        vm.renewContract()  // +2 ans cumulés
        let expected = Calendar.current.date(byAdding: .year, value: 2, to: original)
        XCTAssertEqual(vm.contractEnd, expected)
    }

    func test_validation_rejects_invalid_email() {
        let md = makeMD()
        let vm = MedicalDirectorEditViewModel(md: md)
        vm.email = "not-an-email"
        XCTAssertFalse(vm.isValid)
    }

    func test_validation_rejects_invalid_license() {
        let md = makeMD()
        let vm = MedicalDirectorEditViewModel(md: md)
        vm.licenseNumber = "ab"  // < 4 chars
        XCTAssertFalse(vm.isValid)
    }

    func test_validation_rejects_contract_end_before_start() {
        let md = makeMD()
        let vm = MedicalDirectorEditViewModel(md: md)
        // Force contractEnd avant contractStart
        vm.contractStart = Date(timeIntervalSince1970: 1750000000)
        vm.contractEnd = Date(timeIntervalSince1970: 1700000000)
        XCTAssertFalse(vm.isValid)
    }

    func test_validation_passes_with_valid_data() {
        let md = makeMD()
        let vm = MedicalDirectorEditViewModel(md: md)
        XCTAssertTrue(vm.isValid)
    }
}
