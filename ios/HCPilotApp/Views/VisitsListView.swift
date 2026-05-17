import SwiftUI

struct VisitsListView: View {
    @StateObject private var viewModel = VisitsViewModel()
    @State private var showNewVisitSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBar(text: $viewModel.searchTerm)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Picker("Filtre", selection: $viewModel.filter) {
                    Text("Tous").tag("all")
                    Text("Programmées").tag("scheduled")
                    Text("En cours").tag("in_progress")
                    Text("Terminées").tag("completed")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.top, 8)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    List(viewModel.filteredVisits) { visit in
                        NavigationLink(destination: VisitDetailView(visit: visit, onAction: { viewModel.refresh() })) {
                            VisitListItem(visit: visit)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Visites")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewVisitSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewVisitSheet) {
                NewVisitView(onCreated: { viewModel.refresh() })
            }
            .onAppear { viewModel.load() }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Rechercher...", text: $text)
                .keyboardType(.default)
                .autocorrectionDisabled()
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - VisitsViewModel

@MainActor
class VisitsViewModel: ObservableObject {
    @Published var visits: [Visit] = []
    @Published var patients: [Patient] = []
    @Published var searchTerm = ""
    @Published var filter = "all"
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    var filteredVisits: [Visit] {
        visits.filter { visit in
            let matchesSearch = searchTerm.isEmpty ||
                (visit.patient_name?.lowercased().contains(searchTerm.lowercased()) ?? false) ||
                visit.service_type.lowercased().contains(searchTerm.lowercased())
            let matchesFilter = filter == "all" || visit.status.rawValue == filter
            return matchesSearch && matchesFilter
        }
    }

    func load() {
        Task { await fetchData() }
    }

    func refresh() {
        Task { await fetchData() }
    }

    private func fetchData() async {
        isLoading = true
        do {
            async let v = apiService.getVisits()
            async let p = apiService.getPatients()
            visits = try await v
            patients = try await p
            // Enrich visits with patient names
            for i in visits.indices {
                if visits[i].patient_name == nil,
                   let patient = patients.first(where: { $0.id == visits[i].patient_id }) {
                    visits[i].patient_name = patient.full_name
                }
            }
        } catch {
            errorMessage = "Erreur: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

// MARK: - VisitDetailView

struct VisitDetailView: View {
    let visit: Visit
    var onAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Patient Info
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(visit.patient_name?.prefix(2) ?? "?").uppercased())
                                .foregroundColor(.white)
                                .font(.caption2)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(visit.patient_name ?? "Patient")
                            .font(.headline)
                        Text(visit.service_type.replacingOccurrences(of: "_", with: " "))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Status
                HStack {
                    StatusBadge(status: visit.status)
                    Spacer()
                    Text(visit.scheduled_at, formatter: Self.dateFormatter)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Address
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.red)
                    Text(visit.address)
                        .font(.subheadline)
                }

                // Notes
                if let notes = visit.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Total
                HStack {
                    Spacer()
                    Text(String(format: "Total: %.2f €", visit.total))
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Actions
                VStack(spacing: 8) {
                    if visit.status == .scheduled {
                        Button(action: { startVisit() }) {
                            Text("Commencer la visite")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    if visit.status == .in_progress {
                        Button(action: { completeVisit() }) {
                            Text("Terminer la visite")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Détail")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func startVisit() {
        Task {
            do {
                _ = try await APIService.shared.startVisit(visitId: visit.id)
                onAction()
            } catch {
                print("Erreur démarrage: \(error)")
            }
        }
    }

    private func completeVisit() {
        Task {
            do {
                _ = try await APIService.shared.completeVisit(visitId: visit.id)
                onAction()
            } catch {
                print("Erreur terminaison: \(error)")
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "fr_FR")
        return f
    }()
}

struct StatusBadge: View {
    let status: Visit.VisitStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            Text(label)
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(bgColor)
        .foregroundColor(fgColor)
        .cornerRadius(4)
    }

    private var iconName: String {
        switch status {
        case .completed: return "checkmark.circle.fill"
        case .in_progress: return "clock.fill"
        case .cancelled: return "xmark.circle.fill"
        default: return "calendar.circle.fill"
        }
    }

    private var label: String {
        switch status {
        case .scheduled: return "Planifiée"
        case .in_progress: return "En cours"
        case .completed: return "Terminée"
        case .cancelled: return "Annulée"
        }
    }

    private var bgColor: Color {
        switch status {
        case .completed: return Color.green.opacity(0.2)
        case .in_progress: return Color.blue.opacity(0.2)
        case .cancelled: return Color.red.opacity(0.2)
        default: return Color.gray.opacity(0.2)
        }
    }

    private var fgColor: Color {
        switch status {
        case .completed: return .green
        case .in_progress: return .blue
        case .cancelled: return .red
        default: return .gray
        }
    }
}

// MARK: - NewVisitView

struct NewVisitView: View {
    @Environment(\.dismiss) var dismiss
    var onCreated: () -> Void
    @State private var patientName = ""
    @State private var serviceType = "IV_Hydration"
    @State private var address = ""
    @State private var notes = ""
    @State private var errorMessage: String?

    let serviceTypes = ["IV_Hydration", "Post_Op", "Primary_Care", "Vaccination", "Consultation"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Patient")) {
                    TextField("Nom du patient", text: $patientName)
                }

                Section(header: Text("Service")) {
                    Picker("Type de service", selection: $serviceType) {
                        ForEach(serviceTypes, id: \.self) { type in
                            Text(type.replacingOccurrences(of: "_", with: " "))
                                .tag(type)
                        }
                    }
                }

                Section(header: Text("Adresse")) {
                    TextField("Adresse", text: $address)
                }

                Section(header: Text("Notes")) {
                    TextField("Notes supplémentaires", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Nouvelle Visite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { createVisit() }
                        .disabled(patientName.isEmpty || address.isEmpty)
                }
            }
        }
    }

    private func createVisit() {
        let newVisit = Visit(
            id: UUID().uuidString,
            patient_id: "temp",
            patient_name: patientName,
            service_type: serviceType,
            status: .scheduled,
            scheduled_at: Date(),
            created_at: Date(),
            address: address,
            notes: notes.isEmpty ? nil : notes,
            total: 0,
            estimated_duration: 60,
            copay: nil,
            insurance_claimed: nil
        )
        Task {
            do {
                _ = try await APIService.shared.createVisit(visit: newVisit)
                onCreated()
                dismiss()
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    VisitsListView()
        .environmentObject(AuthViewModel())
}
