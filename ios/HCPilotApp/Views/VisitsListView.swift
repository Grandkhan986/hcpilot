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
                    List {
                        ForEach(viewModel.filteredVisits) { visit in
                            NavigationLink(destination: VisitDetailView(visit: visit, onAction: { viewModel.refresh() })) {
                                VisitListItem(visit: visit)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if visit.status != .completed && visit.status != .cancelled {
                                    Button(role: .destructive) {
                                        Task { await viewModel.cancel(visit) }
                                    } label: {
                                        Label("Annuler", systemImage: "xmark.circle")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { viewModel.refresh() }
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        NavigationLink(destination: RouteMapView()) {
                            Image(systemName: "map")
                        }
                        Button(action: { showNewVisitSheet = true }) {
                            Image(systemName: "plus")
                        }
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
                (visit.client_name?.lowercased().contains(searchTerm.lowercased()) ?? false) ||
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

    func cancel(_ visit: Visit) async {
        do {
            try await apiService.deleteVisit(id: visit.id)
            await fetchData()
        } catch {
            errorMessage = "Erreur annulation : \(error.localizedDescription)"
        }
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
                if visits[i].client_name == nil,
                   let patient = patients.first(where: { $0.id == visits[i].client_id }) {
                    visits[i].client_name = patient.full_name
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
    @State private var showEditForm = false
    @State private var showCancelConfirm = false
    @State private var showConsentFlow = false
    @State private var consent: ConsentSummary?
    @State private var consentLoading = true
    @State private var pdfData: Data?
    @State private var showPDF = false
    @State private var showLotUsageSheet = false
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Patient Info
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(visit.client_name?.prefix(2) ?? "?").uppercased())
                                .foregroundColor(.white)
                                .font(.caption2)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(visit.client_name ?? "Client")
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

                // Consentement
                consentSection

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
                            Text("Commencer la session")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                    if visit.status == .in_progress {
                        Button(action: { showLotUsageSheet = true }) {
                            Text("Terminer la session")
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if visit.status != .completed && visit.status != .cancelled {
                        Button { showEditForm = true } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        Button(role: .destructive) { showCancelConfirm = true } label: {
                            Label("Annuler la session", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditForm) {
            VisitFormView(visit: visit) { onAction() }
        }
        .sheet(isPresented: $showConsentFlow) {
            ConsentFlowView(
                visit: visit,
                patientName: visit.client_name ?? "Client",
                nurseName: authViewModel.user?.full_name ?? "Soignant"
            ) {
                Task { await loadConsent() }
                onAction()
            }
        }
        .sheet(isPresented: $showPDF) {
            if let data = pdfData {
                PDFPreviewView(data: data)
            }
        }
        .sheet(isPresented: $showLotUsageSheet) {
            LotUsageSheet(
                visit: visit,
                preferredProductName: consent?.formulation_name,
                onCompleted: { onAction() }
            )
        }
        .alert("Annuler cette session ?", isPresented: $showCancelConfirm) {
            Button("Non", role: .cancel) { }
            Button("Oui, annuler", role: .destructive) { cancelVisit() }
        } message: {
            Text("La visite sera marquée comme annulée. Cette action est traçée pour l'audit.")
        }
        .task { await loadConsent() }
    }

    // MARK: - Consent section

    @ViewBuilder
    private var consentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                Text("Consentement").font(.headline)
            }
            if consentLoading {
                ProgressView().padding(.vertical, 8)
            } else if let consent {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Signé · \(consent.formulation_name)")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("Signé le \(String(consent.signed_at.prefix(19).replacingOccurrences(of: "T", with: " ")))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let lat = consent.signed_latitude, let lng = consent.signed_longitude {
                            Text(String(format: "📍 %.4f, %.4f", lat, lng))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if consent.has_pdf {
                        Button {
                            Task { await openPDF(consentId: consent.id) }
                        } label: {
                            Label("PDF", systemImage: "doc.richtext")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if visit.status == .scheduled || visit.status == .in_progress {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Consentement non signé")
                            .font(.subheadline).fontWeight(.semibold)
                    }
                    Text("Recueillez le consentement éclairé avant de démarrer l'intervention.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        showConsentFlow = true
                    } label: {
                        HStack {
                            Image(systemName: "signature")
                            Text("Recueillir le consentement").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Aucun consentement enregistré pour cette visite.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
        }
    }

    private func loadConsent() async {
        consentLoading = true
        defer { consentLoading = false }
        do {
            consent = try await APIService.shared.getConsent(forVisit: visit.id)
        } catch {
            consent = nil
        }
    }

    private func openPDF(consentId: String) async {
        do {
            pdfData = try await APIService.shared.getConsentPDF(consentId: consentId)
            showPDF = true
        } catch {
            print("Erreur PDF: \(error)")
        }
    }

    private func cancelVisit() {
        Task {
            do {
                try await APIService.shared.deleteVisit(id: visit.id)
                onAction()
            } catch {
                print("Erreur annulation: \(error)")
            }
        }
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

    @State private var patients: [Patient] = []
    @State private var selectedPatientId: String = ""
    @State private var serviceType = "IV_Hydration"
    @State private var scheduledAt: Date = Date()
    @State private var address = ""
    @State private var notes = ""
    @State private var estimatedDuration: Int = 60
    @State private var totalAmount: String = "0"
    @State private var errorMessage: String?
    @State private var isLoadingPatients = true

    let serviceTypes = ["IV_Hydration", "Post_Op", "Primary_Care", "Vaccination", "Consultation"]

    private var selectedPatient: Patient? {
        patients.first(where: { $0.id == selectedPatientId })
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Client")) {
                    if isLoadingPatients {
                        HStack { ProgressView(); Text("Chargement…").foregroundStyle(.secondary) }
                    } else if patients.isEmpty {
                        Text("Aucun patient actif — créez d'abord un patient.")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Picker("Client", selection: $selectedPatientId) {
                            ForEach(patients) { p in
                                Text(p.full_name).tag(p.id)
                            }
                        }
                        .onChange(of: selectedPatientId) { _, newId in
                            // Auto-remplit l'adresse depuis le patient sélectionné
                            // si l'utilisateur n'a pas encore tapé une adresse custom.
                            if let p = patients.first(where: { $0.id == newId }),
                               address.isEmpty || patients.contains(where: { $0.address == address }) {
                                address = p.address ?? ""
                            }
                        }
                    }
                }

                Section(header: Text("Service")) {
                    Picker("Type de service", selection: $serviceType) {
                        ForEach(serviceTypes, id: \.self) { type in
                            Text(type.replacingOccurrences(of: "_", with: " ")).tag(type)
                        }
                    }
                    DatePicker("Date", selection: $scheduledAt, displayedComponents: [.date, .hourAndMinute])
                    Stepper("Durée : \(estimatedDuration) min", value: $estimatedDuration, in: 15...240, step: 15)
                }

                Section(header: Text("Adresse")) {
                    TextField("Adresse", text: $address, axis: .vertical)
                        .lineLimit(1...3)
                    if let p = selectedPatient, p.address != address, !address.isEmpty {
                        Text("⚠ Adresse différente de l'adresse du patient")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Section(header: Text("Détails")) {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Montant (€)", text: $totalAmount)
                        .keyboardType(.decimalPad)
                }

                if let error = errorMessage {
                    Section { Text(error).foregroundColor(.red).font(.caption) }
                }
            }
            .navigationTitle("Nouvelle session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { createVisit() }
                        .disabled(selectedPatientId.isEmpty || address.isEmpty)
                }
            }
            .task { await loadPatients() }
        }
    }

    private func loadPatients() async {
        isLoadingPatients = true
        defer { isLoadingPatients = false }
        do {
            patients = try await APIService.shared.getPatients(archived: false)
            if selectedPatientId.isEmpty, let first = patients.first {
                selectedPatientId = first.id
                address = first.address ?? ""
            }
        } catch {
            errorMessage = "Impossible de charger les patients : \(error.localizedDescription)"
        }
    }

    private func createVisit() {
        guard let patient = selectedPatient else { return }
        // Si l'adresse est inchangée par rapport à celle du patient, on laisse
        // le backend copier ses coords. Si l'adresse a été éditée, on envoie nil
        // pour les coords — le backend re-géocodera si un token Mapbox est dispo.
        let useCustomAddress = address != (patient.address ?? "")
        let total = Double(totalAmount.replacingOccurrences(of: ",", with: ".")) ?? 0

        let newVisit = Visit(
            id: UUID().uuidString,
            client_id: patient.id,
            client_name: patient.full_name,
            service_type: serviceType,
            status: .scheduled,
            scheduled_at: scheduledAt,
            created_at: Date(),
            address: address,
            latitude: useCustomAddress ? nil : patient.latitude,
            longitude: useCustomAddress ? nil : patient.longitude,
            notes: notes.isEmpty ? nil : notes,
            total: total,
            estimated_duration: estimatedDuration,
            copay: nil,
            insurance_claimed: nil,
            started_at: nil,
            completed_at: nil
        )
        Task {
            do {
                _ = try await APIService.shared.createVisit(visit: newVisit)
                onCreated()
                dismiss()
            } catch {
                errorMessage = "Erreur : \(error.localizedDescription)"
            }
        }
    }
}

import PDFKit

/// Visualiseur PDF natif (PDFKit) avec bouton share intégré.
struct PDFPreviewView: View {
    let data: Data
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            PDFViewWrapper(data: data)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Consentement")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Fermer") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: temporaryURL()) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }

    /// PDFKit + ShareLink ont besoin d'une URL — on écrit dans un fichier
    /// temporaire à la volée pour le partage.
    private func temporaryURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("consent-\(UUID().uuidString).pdf")
        try? data.write(to: url)
        return url
    }
}

private struct PDFViewWrapper: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.document = PDFDocument(data: data)
        return v
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.dataRepresentation() != data {
            uiView.document = PDFDocument(data: data)
        }
    }
}

#Preview {
    VisitsListView()
        .environmentObject(AuthViewModel())
}
