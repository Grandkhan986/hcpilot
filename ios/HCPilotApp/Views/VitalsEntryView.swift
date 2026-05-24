import SwiftUI

/// C-62 — Saisie structurée des paramètres vitaux pendant une session IV.
///
/// 3 sections horodatées (Pré-IV / Mi-IV / Post-IV). Chaque section a :
/// - Systolic BP (validation 70-200)
/// - Diastolic BP (validation 40-130)
/// - Heart rate (validation 40-180)
/// - SpO2 (validation 80-100, optionnel)
/// - Notes courtes
/// - Horodatage automatique via "Capturer maintenant"
///
/// Validation : warning visuel inline si valeurs anormales (BP sys >180/<90,
/// HR >120/<50, SpO2 <92). Persistance via `SessionPatch(preVitals/duringVitals/postVitals)`.
struct VitalsEntryView: View {
    let session: Session
    var onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: VitalsViewModel
    /// P-17 — message du warning à afficher dans l'alert. `.help(...)` n'a
    /// aucun effet sur iPhone, on passe par un Button + Alert pour rester
    /// accessible (notamment VoiceOver).
    @State private var helpMessage: String? = nil

    init(session: Session, onSaved: @escaping () -> Void) {
        self.session = session
        self.onSaved = onSaved
        _vm = StateObject(wrappedValue: VitalsViewModel(session: session))
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Renseignez les paramètres vitaux avant, pendant et après la perfusion. Les valeurs anormales sont signalées en orange.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                vitalsSection(title: "Avant l'IV", binding: $vm.preVitals, id: "pre")
                vitalsSection(title: "Pendant l'IV", binding: $vm.duringVitals, id: "during")
                vitalsSection(title: "Après l'IV", binding: $vm.postVitals, id: "post")

                if !vm.isPhysiologicallyValid {
                    Section {
                        Text("Valeurs hors plage physiologique. Vérifiez vos saisies avant d'enregistrer.")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("vitals.physioError")
                    }
                }

                if let err = vm.errorMessage {
                    Section { Text(err).font(.caption).foregroundStyle(.red) }
                }

                Section {
                    Button {
                        Task {
                            await vm.save()
                            if vm.errorMessage == nil {
                                onSaved()
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Enregistrer").fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .disabled(vm.isSaving || !vm.isPhysiologicallyValid)
                    .accessibilityIdentifier("vitals.save")
                }
            }
            .navigationTitle("Paramètres vitaux")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                        .accessibilityIdentifier("vitals.cancel")
                }
            }
            .alert("Attention", isPresented: .constant(helpMessage != nil)) {
                Button("OK") { helpMessage = nil }
            } message: {
                Text(helpMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func vitalsSection(title: String, binding: Binding<VitalsViewModel.Reading>, id: String) -> some View {
        let reading = binding.wrappedValue
        Section {
            // Horodatage
            HStack {
                Image(systemName: "clock")
                if let t = reading.capturedAt {
                    Text("Capturé le \(t, formatter: VitalsViewModel.timeFmt)")
                        .font(.caption)
                } else {
                    Text("Non capturé").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Capturer maintenant") {
                    binding.wrappedValue.capturedAt = Date()
                }
                .font(.caption)
                .accessibilityIdentifier("vitals.\(id).capture")
            }

            // Systolic
            vitalsField(
                label: "TA sys.",
                placeholder: "120",
                unit: "mmHg",
                value: binding.bpSystolic,
                warning: bpSystolicWarning(reading.bpSystolic),
                identifier: "vitals.\(id).bpSys"
            )

            // Diastolic
            vitalsField(
                label: "TA dia.",
                placeholder: "80",
                unit: "mmHg",
                value: binding.bpDiastolic,
                warning: bpDiastolicWarning(reading.bpDiastolic),
                identifier: "vitals.\(id).bpDia"
            )

            // HR
            vitalsField(
                label: "Pouls",
                placeholder: "72",
                unit: "bpm",
                value: binding.heartRate,
                warning: hrWarning(reading.heartRate),
                identifier: "vitals.\(id).hr"
            )

            // SpO2
            vitalsField(
                label: "SpO₂",
                placeholder: "98",
                unit: "%",
                value: binding.spo2,
                warning: spo2Warning(reading.spo2),
                identifier: "vitals.\(id).spo2"
            )

            // Notes
            TextField("Notes", text: binding.notes, axis: .vertical)
                .lineLimit(1...2)
                .accessibilityIdentifier("vitals.\(id).notes")
        } header: {
            Text(title)
        }
    }

    @ViewBuilder
    private func vitalsField(
        label: String,
        placeholder: String,
        unit: String,
        value: Binding<String>,
        warning: String?,
        identifier: String
    ) -> some View {
        HStack {
            Text(label).frame(width: 70, alignment: .leading).font(.subheadline)
            TextField(placeholder, text: value)
                .keyboardType(.numberPad)
                .accessibilityIdentifier(identifier)
            Text(unit).foregroundStyle(.secondary).font(.caption)
            // P-17 — `.help(...)` n'a aucun effet sur iPhone. On utilise un
            // Button + alert pour rendre le warning accessible (touch + VoiceOver).
            if let w = warning {
                Button {
                    helpMessage = w
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("vitals.warning.\(identifier)")
                .accessibilityLabel("Avertissement : \(w)")
            }
        }
    }

    // MARK: - Validation warnings

    private func bpSystolicWarning(_ s: String) -> String? {
        guard let v = Int(s) else { return nil }
        if v > 180 { return "Hypertension : >180" }
        if v < 90 { return "Hypotension : <90" }
        return nil
    }

    private func bpDiastolicWarning(_ s: String) -> String? {
        guard let v = Int(s) else { return nil }
        if v > 110 { return "Diastolique élevée" }
        if v < 50 { return "Diastolique basse" }
        return nil
    }

    private func hrWarning(_ s: String) -> String? {
        guard let v = Int(s) else { return nil }
        if v > 120 { return "Tachycardie : >120" }
        if v < 50 { return "Bradycardie : <50" }
        return nil
    }

    private func spo2Warning(_ s: String) -> String? {
        guard let v = Int(s) else { return nil }
        if v < 92 { return "Hypoxémie : <92%" }
        return nil
    }
}

// MARK: - ViewModel

@MainActor
final class VitalsViewModel: ObservableObject {
    /// Une mesure horodatée. Tous les champs sont String pour conserver
    /// le placeholder vide ; conversion Int au save.
    struct Reading {
        var bpSystolic: String = ""
        var bpDiastolic: String = ""
        var heartRate: String = ""
        var spo2: String = ""
        var notes: String = ""
        var capturedAt: Date? = nil

        var isEmpty: Bool {
            bpSystolic.isEmpty && bpDiastolic.isEmpty
                && heartRate.isEmpty && spo2.isEmpty && notes.isEmpty
        }

        /// Sérialisation pour l'API : `[String: String]`. Convention de clés
        /// alignée backend (snake_case).
        var asDict: [String: String]? {
            guard !isEmpty else { return nil }
            var dict: [String: String] = [:]
            if !bpSystolic.isEmpty { dict["bp_systolic"] = bpSystolic }
            if !bpDiastolic.isEmpty { dict["bp_diastolic"] = bpDiastolic }
            if !heartRate.isEmpty { dict["heart_rate"] = heartRate }
            if !spo2.isEmpty { dict["spo2"] = spo2 }
            if !notes.isEmpty { dict["notes"] = notes }
            if let t = capturedAt {
                let f = ISO8601DateFormatter()
                dict["captured_at"] = f.string(from: t)
            }
            return dict
        }

        /// L2-13 — Conversion vers la struct typée `Vitals` côté Model.
        /// `nil` si la lecture est vide (saute le timepoint au save).
        var asVitals: Vitals? {
            guard !isEmpty else { return nil }
            return Vitals(
                bpSystolic: Int(bpSystolic),
                bpDiastolic: Int(bpDiastolic),
                heartRate: Int(heartRate),
                spo2: Int(spo2),
                notes: notes.isEmpty ? nil : notes,
                capturedAt: capturedAt
            )
        }
    }

    @Published var preVitals = Reading()
    @Published var duringVitals = Reading()
    @Published var postVitals = Reading()
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let session: Session
    private let api = APIService.shared

    /// P-16 — Validation physiologique stricte : empêche l'enregistrement de
    /// valeurs impossibles (saisie erronée évidente type "BP sys = 999",
    /// "HR = 0", ou chaîne non-numérique). Différent des warnings cliniques
    /// (hypertension, bradycardie...) qui sont info-only.
    ///
    /// Plages retenues volontairement larges pour ne pas bloquer un cas
    /// limite réel :
    /// - BP sys : 50–250 mmHg
    /// - BP dia : 20–150 mmHg
    /// - HR : 20–250 bpm
    /// - SpO2 : 50–100 %
    ///
    /// Un champ vide est considéré valide (la nurse peut enregistrer un
    /// timepoint partiel — par exemple seulement BP sans HR).
    var isPhysiologicallyValid: Bool {
        for reading in [preVitals, duringVitals, postVitals] {
            if !Self.isFieldValid(reading.bpSystolic, range: 50...250) { return false }
            if !Self.isFieldValid(reading.bpDiastolic, range: 20...150) { return false }
            if !Self.isFieldValid(reading.heartRate, range: 20...250) { return false }
            if !Self.isFieldValid(reading.spo2, range: 50...100) { return false }
        }
        return true
    }

    private static func isFieldValid(_ s: String, range: ClosedRange<Int>) -> Bool {
        if s.isEmpty { return true }   // champ vide = OK (saisie partielle)
        guard let v = Int(s) else { return false }   // non-numérique = invalide
        return range.contains(v)
    }

    init(session: Session) {
        self.session = session
        // Pré-remplit depuis les vitals existants si déjà saisis (édition).
        if let pre = session.preVitals { preVitals = Self.readingFrom(vitals: pre) }
        if let dur = session.duringVitals { duringVitals = Self.readingFrom(vitals: dur) }
        if let post = session.postVitals { postVitals = Self.readingFrom(vitals: post) }
    }

    static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static func readingFrom(vitals: Vitals) -> Reading {
        var r = Reading()
        r.bpSystolic = vitals.bpSystolic.map(String.init) ?? ""
        r.bpDiastolic = vitals.bpDiastolic.map(String.init) ?? ""
        r.heartRate = vitals.heartRate.map(String.init) ?? ""
        r.spo2 = vitals.spo2.map(String.init) ?? ""
        r.notes = vitals.notes ?? ""
        r.capturedAt = vitals.capturedAt
        return r
    }

    func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        let patch = APIService.SessionPatch(
            preVitals: preVitals.asVitals,
            duringVitals: duringVitals.asVitals,
            postVitals: postVitals.asVitals
        )
        do {
            _ = try await api.updateSession(id: session.id, patch: patch)
        } catch {
            errorMessage = "Erreur : \(error.localizedDescription)"
        }
    }
}
