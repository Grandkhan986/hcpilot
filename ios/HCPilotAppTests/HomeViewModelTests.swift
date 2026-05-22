import XCTest
@testable import HCPilotApp

/// Tests purs (sans backend) sur les calculs métier du HomeViewModel.
/// Couvre brief §refonte Home — worst-of compliance et split today/upcoming.
final class HomeViewModelTests: XCTestCase {

    // MARK: - worst(of:) — pire statut de conformité

    func test_worstOf_empty_returns_ok() {
        XCTAssertEqual(HomeViewModel.worst(of: []), .ok)
    }

    func test_worstOf_all_ok_returns_ok() {
        XCTAssertEqual(HomeViewModel.worst(of: [.ok, .ok, .ok]), .ok)
    }

    func test_worstOf_warning_among_ok_returns_warning() {
        XCTAssertEqual(HomeViewModel.worst(of: [.ok, .warning, .ok]), .warning)
    }

    func test_worstOf_critical_dominates_warning() {
        XCTAssertEqual(HomeViewModel.worst(of: [.warning, .critical, .ok]), .critical)
    }

    func test_worstOf_expired_dominates_critical() {
        XCTAssertEqual(HomeViewModel.worst(of: [.critical, .expired, .warning]), .expired)
    }

    func test_worstOf_unknown_treated_as_ok() {
        XCTAssertEqual(HomeViewModel.worst(of: [.unknown, .unknown]), .ok)
    }

    // MARK: - Split today / upcoming

    @MainActor
    func test_split_today_vs_upcoming() {
        let vm = HomeViewModel()
        let cal = Calendar.current
        let today9h = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        let today14h = cal.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today9h)!
        let dayAfter = cal.date(byAdding: .day, value: 2, to: today9h)!

        vm.todaySessions = [
            makeSession(id: "a", at: today9h),
            makeSession(id: "b", at: today14h),
        ]
        vm.upcomingSessions = [
            makeSession(id: "c", at: tomorrow),
            makeSession(id: "d", at: dayAfter),
        ]

        XCTAssertEqual(vm.todaySessions.count, 2)
        XCTAssertEqual(vm.upcomingSessions.count, 2)
        XCTAssertTrue(vm.todaySessions.allSatisfy { Calendar.current.isDateInToday($0.scheduledAt) })
        XCTAssertFalse(vm.upcomingSessions.contains { Calendar.current.isDateInToday($0.scheduledAt) })
    }

    // MARK: - Greeting

    @MainActor
    func test_displayName_md_uses_dr_lastname() {
        let vm = HomeViewModel()
        vm.firstName = "Marie"
        vm.lastName = "Dupont"
        vm.licenseType = "MD"
        XCTAssertEqual(vm.displayName, "Dr. Dupont")
    }

    @MainActor
    func test_displayName_rn_uses_firstname_only() {
        let vm = HomeViewModel()
        vm.firstName = "Sarah"
        vm.lastName = "Johnson"
        vm.licenseType = "RN"
        XCTAssertEqual(vm.displayName, "Sarah")
    }

    @MainActor
    func test_displayName_lpn_uses_firstname_only() {
        let vm = HomeViewModel()
        vm.firstName = "Alex"
        vm.lastName = "Smith"
        vm.licenseType = "LPN"
        XCTAssertEqual(vm.displayName, "Alex")
    }

    @MainActor
    func test_displayName_falls_back_when_empty() {
        let vm = HomeViewModel()
        XCTAssertEqual(vm.displayName, "soignant")
    }

    // MARK: - Start button state

    @MainActor
    func test_startButton_no_session_today() {
        let vm = HomeViewModel()
        vm.todaySessions = []
        if case .noSessionToday = vm.startButtonState { return }
        XCTFail("Expected .noSessionToday")
    }

    @MainActor
    func test_startButton_in_progress_returns_continue() {
        let vm = HomeViewModel()
        var s = makeSession(id: "a", at: Date())
        s.status = .inProgress
        vm.todaySessions = [s]
        if case .continueSession = vm.startButtonState { return }
        XCTFail("Expected .continueSession")
    }

    @MainActor
    func test_startButton_all_completed_returns_dayCompleted() {
        let vm = HomeViewModel()
        var s = makeSession(id: "a", at: Date())
        s.status = .completed
        vm.todaySessions = [s]
        if case .dayCompleted = vm.startButtonState { return }
        XCTFail("Expected .dayCompleted")
    }

    @MainActor
    func test_startButton_scheduled_returns_startDay() {
        let vm = HomeViewModel()
        let s = makeSession(id: "a", at: Date())
        vm.todaySessions = [s]
        if case .startDay = vm.startButtonState { return }
        XCTFail("Expected .startDay")
    }

    // MARK: - Helpers

    private func makeSession(id: String, at date: Date) -> Session {
        Session(
            id: id,
            clientId: "cli_1",
            nurseId: "nurse_1",
            clientName: "Test Client",
            formulationName: "Myers Cocktail",
            formulationInventoryId: nil,
            status: .scheduled,
            scheduledAt: date,
            createdAt: Date(),
            address: "1 Test St",
            latitude: nil,
            longitude: nil,
            totalAmount: 100,
            estimatedDuration: 60,
            startedAt: nil,
            completedAt: nil,
            ivStartTime: nil,
            ivEndTime: nil,
            preVitals: nil,
            duringVitals: nil,
            postVitals: nil,
            dripRate: nil,
            clinicalNotes: nil,
            photosPaths: [],
            cancelledAt: nil,
            cancellationReason: nil,
            updatedAt: nil
        )
    }
}
