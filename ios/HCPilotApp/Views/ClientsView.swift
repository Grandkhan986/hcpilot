import SwiftUI

struct ClientsView: View {
    @StateObject private var viewModel = ClientsViewModel()
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
                } else if viewModel.filteredClients.isEmpty {
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
                        ForEach(viewModel.filteredClients) { client in
                            NavigationLink(destination: ClientDetailView(
                                client: client,
                                onChanged: { viewModel.refresh() }
                            )) {
                                ClientListItem(client: client)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if client.isArchived {
                                    Button {
                                        Task { await viewModel.restore(client) }
                                    } label: {
                                        Label("Restaurer", systemImage: "tray.and.arrow.up")
                                    }
                                    .tint(.green)
                                } else {
                                    Button(role: .destructive) {
                                        Task { await viewModel.archive(client) }
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
                ClientFormView(mode: .create) { viewModel.refresh() }
            }
            .onAppear { viewModel.load() }
        }
    }
}

struct ClientListItem: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(client.isArchived ? Color.gray : Color.blue)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(client.initials)
                        .foregroundColor(.white)
                        .font(.caption)
                        .fontWeight(.bold)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(client.full_name)
                    .font(.headline)
                    .foregroundStyle(client.isArchived ? .secondary : .primary)
                if let phone = client.phone {
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if client.isArchived {
                Text("Archivé")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            } else if let gender = client.gender {
                Text(gender == "M" ? "Homme" : "Femme")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ClientDetailView: View {
    let client: Client
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

                if client.isArchived {
                    archiveBanner
                }

                contactCard

                if !client.medical_conditions.isEmpty {
                    medicalCard(history: client.medical_conditions.joined(separator: ", "))
                }

                if !client.allergies.isEmpty {
                    allergiesCard(allergies: client.allergies.joined(separator: ", "))
                }

                if !client.medications.isEmpty {
                    medicationsCard(medications: client.medications)
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
                    if !client.isArchived {
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
            ClientFormView(mode: .edit(client)) {
                onChanged()
                actionInfo = "Modifications enregistrées."
            }
        }
        .alert("Archiver ce client ?", isPresented: $showArchiveConfirm) {
            Button("Annuler", role: .cancel) { }
            Button("Archiver", role: .destructive) { Task { await archive() } }
        } message: {
            Text("Le client sera déplacé vers les archives. Toutes ses sessions planifiées seront supprimées définitivement. Les sessions terminées ou en cours sont conservées dans la fiche d'archive.")
        }
    }

    private var header: some View {
        HStack {
            Circle()
                .fill(client.isArchived ? Color.gray : Color.blue)
                .frame(width: 64, height: 64)
                .overlay(
                    Text(client.initials)
                        .foregroundColor(.white)
                        .font(.title3)
                        .fontWeight(.bold)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(client.full_name)
                    .font(.title2)
                    .fontWeight(.bold)
                if let gender = client.gender, let dob = client.date_of_birth {
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
            if let date = client.archived_at {
                Text("le \(date, style: .date)")
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
            if let phone = client.phone {
                InfoRow(icon: "phone", label: "Téléphone", value: phone)
            }
            if let email = client.email {
                InfoRow(icon: "envelope", label: "Email", value: email)
            }
            if !client.full_address.isEmpty {
                InfoRow(icon: "location", label: "Adresse", value: client.full_address)
            }
            if let access = client.access_notes, !access.isEmpty {
                InfoRow(icon: "key", label: "Accès", value: access)
            }
            if let name = client.emergency_contact_name, !name.isEmpty {
                let phone = client.emergency_contact_phone ?? ""
                InfoRow(icon: "exclamationmark.bubble", label: "Contact urgence", value: "\(name) \(phone)".trimmingCharacters(in: .whitespaces))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func medicationsCard(medications: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "pills.fill").foregroundColor(.blue)
                Text("Médication en cours").font(.headline)
            }
            ForEach(medications, id: \.self) { med in
                HStack(spacing: 8) {
                    Text("•")
                    Text(med).font(.subheadline)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.08))
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
            let r = try await APIService.shared.archiveClient(id: client.id)
            onChanged()
            if r.deleted_scheduled_sessions > 0 {
                let s = r.deleted_scheduled_sessions > 1 ? "s" : ""
                actionInfo = "\(r.deleted_scheduled_sessions) session\(s) planifiée\(s) supprimée\(s)."
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
            dismiss()
        } catch {
            actionError = "Erreur : \(error.localizedDescription)"
        }
    }

    private func restore() async {
        do {
            try await APIService.shared.restoreClient(id: client.id)
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
class ClientsViewModel: ObservableObject {
    @Published var clients: [Client] = []
    @Published var searchTerm = ""
    @Published var isLoading = false
    @Published var showArchived = false
    @Published var lastActionInfo: String?

    private let apiService = APIService.shared

    var filteredClients: [Client] {
        guard !searchTerm.isEmpty else { return clients }
        return clients.filter {
            $0.full_name.lowercased().contains(searchTerm.lowercased()) ||
            ($0.phone?.contains(searchTerm) ?? false)
        }
    }

    func load() { Task { await fetchClients() } }
    func refresh() { Task { await fetchClients() } }

    private func fetchClients() async {
        isLoading = true
        do {
            clients = try await apiService.getClients(archived: showArchived)
        } catch {
            clients = []
        }
        isLoading = false
    }

    func archive(_ client: Client) async {
        do {
            let r = try await apiService.archiveClient(id: client.id)
            if r.deleted_scheduled_sessions > 0 {
                lastActionInfo = "Client archivé, \(r.deleted_scheduled_sessions) session(s) planifiée(s) supprimée(s)."
            } else {
                lastActionInfo = "Client archivé."
            }
            await fetchClients()
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            lastActionInfo = nil
        } catch {
            lastActionInfo = "Erreur archivage : \(error.localizedDescription)"
        }
    }

    func restore(_ client: Client) async {
        do {
            try await apiService.restoreClient(id: client.id)
            lastActionInfo = "Client restauré."
            await fetchClients()
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            lastActionInfo = nil
        } catch {
            lastActionInfo = "Erreur restauration : \(error.localizedDescription)"
        }
    }
}

#Preview {
    ClientsView()
}
