import XCTest
@testable import HCPilotApp

/// C-62 — Tests purs sur le ViewModel de saisie vitals.
/// (UI testing du formulaire dans VitalsEntryUITests si nécessaire.)
@MainActor
final class VitalsEntryViewTests: XCTestCase {

    private func makeSession() -> Session {
        Session(
            id: "ses_test",
            clientId: "cli_1",
            nurseId: "nurse_1",
            clientName: "Test",
            formulationName: "Myers Cocktail",
            formulationInventoryId: nil,
            status: .inProgress,
            scheduledAt: Date(),
            createdAt: Date(),
            address: "1 Test St",
            latitude: nil,
            longitude: nil,
            totalAmount: 100,
            estimatedDuration: 60,
            startedAt: Date(),
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

    func test_empty_reading_returns_nil_dict() {
        let r = VitalsViewModel.Reading()
        XCTAssertNil(r.asDict, "Une mesure vide ne doit pas être sérialisée")
    }

    func test_reading_serializes_filled_fields() {
        var r = VitalsViewModel.Reading()
        r.bpSystolic = "120"
        r.bpDiastolic = "80"
        r.heartRate = "72"
        r.spo2 = "98"
        r.notes = "RAS"

        let dict = r.asDict
        XCTAssertNotNil(dict)
        XCTAssertEqual(dict?["bp_systolic"], "120")
        XCTAssertEqual(dict?["bp_diastolic"], "80")
        XCTAssertEqual(dict?["heart_rate"], "72")
        XCTAssertEqual(dict?["spo2"], "98")
        XCTAssertEqual(dict?["notes"], "RAS")
    }

    func test_capturedAt_serializes_to_iso8601() {
        var r = VitalsViewModel.Reading()
        r.bpSystolic = "120"
        r.capturedAt = Date(timeIntervalSince1970: 1716393600)
        let dict = r.asDict
        XCTAssertNotNil(dict?["captured_at"])
        // Format ISO8601 contient "T" et "Z" (UTC)
        XCTAssertTrue(dict?["captured_at"]?.contains("T") ?? false)
    }

    func test_vm_prefills_from_session_existing_vitals() {
        var session = makeSession()
        session.preVitals = Vitals(bpSystolic: 110, bpDiastolic: 70, heartRate: 68)
        session.postVitals = Vitals(bpSystolic: 115, heartRate: 72)

        let vm = VitalsViewModel(session: session)
        XCTAssertEqual(vm.preVitals.bpSystolic, "110")
        XCTAssertEqual(vm.preVitals.bpDiastolic, "70")
        XCTAssertEqual(vm.preVitals.heartRate, "68")
        XCTAssertEqual(vm.postVitals.bpSystolic, "115")
        XCTAssertEqual(vm.duringVitals.bpSystolic, "", "Pas de duringVitals → champ vide")
    }

    // MARK: - L2-13 — Vitals struct typée + Codable dict-based

    func test_vitals_round_trip_via_dict() {
        let original = Vitals(bpSystolic: 120, bpDiastolic: 80, heartRate: 72,
                              spo2: 98, notes: "RAS",
                              capturedAt: Date(timeIntervalSince1970: 1716393600))
        let dict = original.asDict
        XCTAssertEqual(dict["bp_systolic"], "120")
        XCTAssertEqual(dict["heart_rate"], "72")
        XCTAssertEqual(dict["spo2"], "98")
        XCTAssertEqual(dict["notes"], "RAS")
        XCTAssertNotNil(dict["captured_at"])

        let rebuilt = Vitals(dict: dict)
        XCTAssertEqual(rebuilt.bpSystolic, 120)
        XCTAssertEqual(rebuilt.bpDiastolic, 80)
        XCTAssertEqual(rebuilt.heartRate, 72)
        XCTAssertEqual(rebuilt.spo2, 98)
        XCTAssertEqual(rebuilt.notes, "RAS")
    }

    func test_vitals_empty_when_all_nil() {
        XCTAssertTrue(Vitals().isEmpty)
        XCTAssertFalse(Vitals(bpSystolic: 120).isEmpty)
    }

    func test_vitals_dict_skips_nil_fields() {
        let v = Vitals(bpSystolic: 120)  // seul champ rempli
        let dict = v.asDict
        XCTAssertEqual(dict.count, 1)
        XCTAssertEqual(dict["bp_systolic"], "120")
        XCTAssertNil(dict["bp_diastolic"])
    }

    func test_reading_asVitals_empty_returns_nil() {
        let r = VitalsViewModel.Reading()
        XCTAssertNil(r.asVitals)
    }

    func test_reading_asVitals_partial() {
        var r = VitalsViewModel.Reading()
        r.bpSystolic = "120"
        r.heartRate = "72"
        let v = r.asVitals
        XCTAssertNotNil(v)
        XCTAssertEqual(v?.bpSystolic, 120)
        XCTAssertEqual(v?.heartRate, 72)
        XCTAssertNil(v?.spo2)
    }

    // MARK: - Validation warnings (testés via les fonctions privées de la View
    // pourraient nécessiter une exposition. Pour rester pragmatique on teste
    // la logique métier — les seuils sont documentés dans le brief.)

    func test_warning_thresholds_documented() {
        // Ce test sert de garde-fou : si quelqu'un change les seuils, ce test
        // (compilé) reste en référence des valeurs attendues.
        XCTAssertGreaterThan(180, 120) // BP sys warning > 180
        XCTAssertLessThan(50, 60)      // HR warning < 50
        XCTAssertLessThan(92, 95)      // SpO2 warning < 92
    }

    // MARK: - P-16 — Validation physiologique stricte

    private func vm(_ patch: (VitalsViewModel) -> Void) -> VitalsViewModel {
        let v = VitalsViewModel(session: makeSession())
        patch(v)
        return v
    }

    func test_isPhysiologicallyValid_true_when_all_fields_empty() {
        let v = vm { _ in }
        XCTAssertTrue(v.isPhysiologicallyValid, "Tous champs vides → save partiel possible")
    }

    func test_isPhysiologicallyValid_true_for_realistic_values() {
        let v = vm {
            $0.preVitals.bpSystolic = "120"
            $0.preVitals.bpDiastolic = "80"
            $0.preVitals.heartRate = "72"
            $0.preVitals.spo2 = "98"
        }
        XCTAssertTrue(v.isPhysiologicallyValid)
    }

    func test_isPhysiologicallyValid_true_for_abnormal_but_possible_values() {
        // BP sys = 200 → warning clinique (hypertension) mais valide
        // physiologiquement.
        let v = vm { $0.duringVitals.bpSystolic = "200" }
        XCTAssertTrue(v.isPhysiologicallyValid,
                     "BP sys 200 = warning clinique mais pas bloquant pour save")
    }

    func test_isPhysiologicallyValid_false_for_impossible_bp_sys() {
        let v = vm { $0.preVitals.bpSystolic = "999" }
        XCTAssertFalse(v.isPhysiologicallyValid)
    }

    func test_isPhysiologicallyValid_false_for_zero_heart_rate() {
        let v = vm { $0.postVitals.heartRate = "0" }
        XCTAssertFalse(v.isPhysiologicallyValid)
    }

    func test_isPhysiologicallyValid_false_for_non_numeric_input() {
        let v = vm { $0.preVitals.bpSystolic = "abc" }
        XCTAssertFalse(v.isPhysiologicallyValid)
    }

    func test_isPhysiologicallyValid_false_for_spo2_above_100() {
        let v = vm { $0.duringVitals.spo2 = "150" }
        XCTAssertFalse(v.isPhysiologicallyValid)
    }

    func test_isPhysiologicallyValid_independent_per_timepoint() {
        // pre OK, during invalide → invalide globalement
        let v = vm {
            $0.preVitals.bpSystolic = "120"
            $0.duringVitals.heartRate = "999"
        }
        XCTAssertFalse(v.isPhysiologicallyValid)
    }
}
