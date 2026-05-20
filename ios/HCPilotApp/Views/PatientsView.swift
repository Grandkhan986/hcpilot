import SwiftUI

struct PatientsView: View {
    @StateObject private var viewModel = PatientsViewModel()
    @State private var showCreateForm = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Visibilité", selection: $viewModel.showArchived) {
                    Text("Actifs").tag(false)
                    Text("Archives").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: viewModel.showArchived) { _, _ in viewModel.refresh() }

                SearchBar(text: $viewModel.searchTerm)
                    .padding(.horizontal)
                    .padding(.top, 8)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if viewModel.filteredPatients.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: viewModel.showArchived ? "archivebox" : "person.3")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(viewModel.showArchived ? "Aucun client archivé" : "Aucun client")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.filteredPatients) { patient in
                            NavigationLink(destination: PatientDetailView(
                                patient: patient,
                                onChanged: { viewModel.refresh() }
                            )) {
                                PatientListItem(patient: patient)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if patient.isArchived {
                                    Button {
                                        Task { await viewModel.restore(patient) }
                                    } label: {
                                        Label("Restaurer", systemImage: "tray.and.arrow.up")
                                    }
                                    .tint(.green)
                                } else {
                                    Button(role: .destructive) {
                                        Task { await viewModel.archive(patient) }
                                    } label: {
                                        Label("Archiver", systemImage: "archivebox")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { viewModel.refresh() }
                }

                if let info = viewModel.lastActionInfo {
                    Text(info)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
            }
            .navigationTitle("Clients")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !viewModel.showArchived {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button { showCreateForm = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateForm) {
                PatientFormView(mode: .create) { viewModel.refresh() }
            }
            .onAppear { viewModel.load() }
        }
    }
}

struct PatientListItem: View {
    let patient: Patient

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(patient.isArchived ? Color.gray : Color.blue)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(patient.initials)
                        .foregroundColor(.white)
                        .font(.caption)
                        .fontWeight(.bold)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(patient.full_name)
                    .font(.headline)
                    .foregroundStyle(patient.isArchived ? .secondary : .primary)
                if let phone = patient.phone {
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if patient.isArchived {
                Text("Archivé")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            } else if let gender = patient.gender {
                Text(gender == "M" ? "Homme" : "Femme")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct PatientDetailView: View {
    let patient: Patient
    var onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showEditForm = false
    @State private var showArchiveConfirm = false
    @State private var actionError: String?
    @State private var actionInfo: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if patient.isArchived {
                    archiveBanner
                }

                contactCard

                if let history = patient.medical_history, !history.isEmpty {
                    medicalCard(history: history)
                }

                if let allergies = patient.allergies, !allergies.isEmpty {
                    allergiesCard(allergies: allergies)
                }

                if let info = actionInfo {
                    Text(info).font(.caption).foregroundStyle(.blue).padding(.horizontal)
                }
                if let err = actionError {
                    Text(err).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }
            }
            .padding()
        }
        .navigationTitle("Fiche client")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if !patient.isArchived {
                        Button { showEditForm = true } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showArchiveConfirm = true
                        } label: {
                            Label("Archiver", systemImage: "archivebox")
                        }
                    } else {
                        Button { Task { await restore() } } label: {
                            Label("Restaurer", systemImage: "tray.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditForm) {
            PatientFormView(mode: .edit(patient)) {
                onChanged()
                actionInfo = "Modifications enregistrées."
            }
        }
        .alert("Archiver ce client ?", isPresented: $showArchiveConfirm) {
            Button("Annuler", role: .cancel) { }
            Button("Archiver", role: .destructive) { Task { await archive() } }
        } message: {
            Text("Le patient sera déplacé vers les archives. Toutes ses visites planifiées seront supprimées définitivement. Les visites terminées ou en cours sont conservées dans la fiche d'archive.")
        }
    }

    private var header: some View {
        HStack {
            Circle()
                .fill(patient.isArchived ? Color.gray : Color.blue)
                .frame(width: 64, height: 64)
                .overlay(
                    Text(patient.initials)
                        .foregroundColor(.white)
                        .font(.title3)
                        .fontWeight(.bold)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(patient.full_name)
                    .font(.title2)
                    .fontWeight(.bold)
                if let gender = patient.gender, let dob = patient.date_of_birth {
                    Text("\(gender == "M" ? "Homme" : "Femme") · \(dob)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
    }

    private var archiveBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "archivebox.fill")
            Text("Client archivé")
                .fontWeight(.semibold)
            if let date = patient.archived_at {
                Text("le \(String(date.prefix(10)))")
            }
            Spacer()
        }
        .font(.caption)
        .padding(10)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(10)
    }

    private var contactCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let phone = patient.phone {
                InfoRow(icon: "phone", label: "Téléphone", value: phone)
            }
            if let email = patient.email {
                InfoRow(icon: "envelope", label: "Email", value: email)
            }
            if let address = patient.address {
                InfoRow(icon: "location", label: "Adresse", value: address)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func medicalCard(history: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Antécédents médicaux").font(.headline)
            Text(history).font(.subheadline).foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func allergiesCard(allergies: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle").foregroundColor(.red)
                Text("Allergies").font(.headline)
            }
            Text(allergies).font(.subheadline).foregroundColor(.red)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    private func archive() async {
        do {
            let r = try await APIService.shared.archivePatient(id: patient.id)
            onChanged()
            if r.deleted_scheduled_visits > 0 {
                let s = r.deleted_scheduled_visits > 1 ? "s" : ""
                actionInfo = "\(r.deleted_scheduled_visits) visite\(s) planifiée\(s) supprimée\(s)."
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
            dismiss()
        } catch {
            actionError = "Erreur : \(error.localizedDescription)"
        }
    }

    private func restore() async {
        do {
            try await APIService.shared.restorePatient(id: patient.id)
            onChanged()
            dismiss()
        } catch {
            actionError = "Erreur : \(error.localizedDescription)"
        }
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundColor(.secondary)
                Text(value).font(.subheadline)
            }
        }
    }
}

@MainActor
class PatientsViewModel: ObservableObject {
    @Published var patients: [Patient] = []
    @Published var searchTerm = ""
    @Published var isLoading = false
    @Published var showArchived = false
    @Published var lastActionInfo: String?

    private let apiService = APIService.shared

    var filteredPatients: [Patient] {
        guard !searchTerm.isEmpty else { return patients }
        return patients.filter {
            $0.full_name.lowercased().contains(searchTerm.lowercased()) ||
            ($0.phone?.contains(searchTerm) ?? false)
        }
    }

    func load() { Task { await fetchPatients() } }
    func refresh() { Task { await fetchPatients() } }

    private func fetchPatients() async {
        isLoading = true
        do {
            patients = try await apiService.getPatients(archived: showArchived)
        } catch {
            patients = []
        }
        isLoading = false
    }

    func archive(_ patient: Patient) async {
        do {
            let r = try await apiService.archivePatient(id: patient.id)
            if r.deleted_scheduled_visits > 0 {
                lastActionInfo = "Client archivé, \(r.deleted_scheduled_visits) visite(s) planifiée(s) supprimée(s)."
            } else {
                lastActionInfo = "Client archivé."
            }
            await fetchPatients()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            lastActionInfo = nil
        } catch {
            lastActionInfo = "Erreur archivage : \(error.localizedDescription)"
        }
    }

    func restore(_ patient: Patient) async {
        do {
            try await apiService.restorePatient(id: patient.id)
            lastActionInfo = "Patient restauré."
            await fetchPatients()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            lastActionInfo = nil
        } catch {
            lastActionInfo = "Erreur restauration : \(error.localizedDescription)"
        }
    }
}

#Preview {
    PatientsView()
}
