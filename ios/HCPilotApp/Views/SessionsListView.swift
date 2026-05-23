import SwiftUI

struct SessionsListView: View {
    @StateObject private var viewModel = SessionsViewModel()
    @State private var showNewSessionSheet = false

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
                        ForEach(viewModel.filteredSessions) { session in
                            NavigationLink(destination: SessionDetailView(session: session, onAction: { viewModel.refresh() })) {
                                SessionListItem(session: session)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if session.status != .completed && session.status != .cancelled {
                                    Button(role: .destructive) {
                                        Task { await viewModel.cancel(session) }
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
                        Button(action: { showNewSessionSheet = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewSessionSheet) {
                NewSessionView(onCreated: { viewModel.refresh() })
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

// MARK: - SessionsViewModel

@MainActor
class SessionsViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var clients: [Client] = []
    @Published var searchTerm = ""
    @Published var filter = "all"
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService.shared

    var filteredSessions: [Session] {
        sessions.filter { session in
            let matchesSearch = searchTerm.isEmpty ||
                (session.clientName?.lowercased().contains(searchTerm.lowercased()) ?? false) ||
                session.formulationName.lowercased().contains(searchTerm.lowercased())
            let matchesFilter = filter == "all" || session.status.rawValue == filter
            return matchesSearch && matchesFilter
        }
    }

    func load() {
        Task { await fetchData() }
    }

    func refresh() {
        Task { await fetchData() }
    }

    func cancel(_ session: Session) async {
        do {
            try await apiService.deleteSession(id: session.id)
            await fetchData()
        } catch {
            errorMessage = "Erreur annulation : \(error.localizedDescription)"
        }
    }

    private func fetchData() async {
        isLoading = true
        do {
            async let v = apiService.getSessions()
            async let p = apiService.getClients()
            sessions = try await v
            clients = try await p
            // Enrich sessions with client names
            for i in sessions.indices {
                if sessions[i].clientName == nil,
                   let client = clients.first(where: { $0.id == sessions[i].clientId }) {
                    sessions[i].clientName = client.fullName
                }
            }
        } catch {
            errorMessage = "Erreur: \(error.localizedDescription)"
        }
        isLoading = false
    }
}

// MARK: - SessionDetailView

struct SessionDetailView: View {
    let session: Session
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
    // C-63 — invoice générée à la complétion de la session
    @State private var generatedInvoice: Invoice?
    @State private var invoicePdfData: Data?
    @State private var showInvoicePDF = false
    // C-62 — saisie des vitals
    @State private var showVitalsEntry = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Client Info
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(session.clientName?.prefix(2) ?? "?").uppercased())
                                .foregroundColor(.white)
                                .font(.caption2)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.clientName ?? "Client")
                            .font(.headline)
                        Text(session.formulationName.replacingOccurrences(of: "_", with: " "))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Status
                HStack {
                    StatusBadge(status: session.status)
                    Spacer()
                    Text(session.scheduledAt, formatter: Self.dateFormatter)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Address
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.red)
                    Text(session.address)
                        .font(.subheadline)
                }

                // Consentement
                consentSection

                // Notes
                if let notes = session.clinicalNotes, !notes.isEmpty {
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
                    Text(String(format: "Total: %.2f €", session.totalAmount))
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                // Actions
                VStack(spacing: 8) {
                    if session.status == .scheduled {
                        Button(action: { startSession() }) {
                            Text("Commencer la session")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .accessibilityIdentifier("session.start")
                    }

                    if session.status == .inProgress {
                        // C-62 — accès à VitalsEntryView pendant la session
                        Button(action: { showVitalsEntry = true }) {
                            HStack {
                                Image(systemName: "heart.text.square")
                                Text("Saisir les vitals").fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.pink.opacity(0.15))
                        .foregroundStyle(.pink)
                        .cornerRadius(8)
                        .accessibilityIdentifier("session.openVitals")

                        Button(action: { showLotUsageSheet = true }) {
                            Text("Terminer la session")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .accessibilityIdentifier("session.complete")
                    }

                    // C-63 — accès à la facture stub si la session a été
                    // complétée et qu'une invoice a été générée.
                    if session.status == .completed, let invoice = generatedInvoice {
                        Button {
                            invoicePdfData = InvoiceLocalStore.shared.loadPDF(forInvoiceId: invoice.id)
                            showInvoicePDF = invoicePdfData != nil
                        } label: {
                            HStack {
                                Image(systemName: "doc.richtext")
                                Text("Voir la facture (\(invoice.invoiceNumber))")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .accessibilityIdentifier("session.viewInvoice")
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showInvoicePDF) {
            if let data = invoicePdfData {
                PDFPreviewView(data: data)
            }
        }
        .sheet(isPresented: $showVitalsEntry) {
            VitalsEntryView(session: session) { onAction() }
        }
        .navigationTitle("Détail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if session.status != .completed && session.status != .cancelled {
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
            SessionFormView(session: session) { onAction() }
        }
        .sheet(isPresented: $showConsentFlow) {
            ConsentFlowView(
                session: session,
                clientName: session.clientName ?? "Client",
                nurseName: authViewModel.user?.fullName ?? "Soignant"
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
                session: session,
                preferredProductName: consent?.formulationName,
                onCompleted: {
                    // C-63 — déclenche la génération de l'invoice stub au
                    // moment où la session passe en completed. Best-effort :
                    // si la génération échoue, on n'empêche pas le flow.
                    Task {
                        await generateInvoiceIfNeeded()
                        onAction()
                    }
                }
            )
        }
        .alert("Annuler cette session ?", isPresented: $showCancelConfirm) {
            Button("Non", role: .cancel) { }
            Button("Oui, annuler", role: .destructive) { cancelSession() }
        } message: {
            Text("La session sera marquée comme annulée. Cette action est traçée pour l'audit.")
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
                        Text("Signé · \(consent.formulationName)")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("Signé \(consent.signedAt, formatter: Self.consentDateFmt)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let lat = consent.signedLatitude, let lng = consent.signedLongitude {
                            Text(String(format: "📍 %.4f, %.4f", lat, lng))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if consent.hasPdf {
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
            } else if session.status == .scheduled || session.status == .inProgress {
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
                    .accessibilityIdentifier("session.openConsentFlow")
                }
                .padding()
                .background(Color.orange.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Aucun consentement enregistré pour cette session.")
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
            consent = try await APIService.shared.getConsent(forSession: session.id)
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

    private func cancelSession() {
        Task {
            do {
                try await APIService.shared.deleteSession(id: session.id)
                onAction()
            } catch {
                print("Erreur annulation: \(error)")
            }
        }
    }

    private func startSession() {
        Task {
            do {
                _ = try await APIService.shared.startSession(sessionId: session.id)
                onAction()
            } catch {
                print("Erreur démarrage: \(error)")
            }
        }
    }

    private func completeSession() {
        Task {
            do {
                _ = try await APIService.shared.completeSession(sessionId: session.id)
                onAction()
            } catch {
                print("Erreur terminaison: \(error)")
            }
        }
    }

    /// C-63 — génère l'invoice stub à la complétion de session. Best-effort.
    /// Le PDF est stocké localement (cf. InvoiceLocalStore) et un POST est
    /// envoyé au backend pour le lister.
    private func generateInvoiceIfNeeded() async {
        do {
            let invoice = try await InvoiceService.shared.generateInvoiceForCompletedSession(
                session,
                practiceName: nil,
                nurseFullName: authViewModel.user?.fullName,
                clientFullName: session.clientName,
                clientAddress: nil
            )
            generatedInvoice = invoice
            // Charge le PDF local pour l'aperçu immédiat.
            invoicePdfData = InvoiceLocalStore.shared.loadPDF(forInvoiceId: invoice.id)
        } catch {
            // Stub : log seulement. La complétion de session reste valide.
            print("Erreur génération invoice : \(error.localizedDescription)")
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "fr_FR")
        return f
    }()

    fileprivate static let consentDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "fr_FR")
        return f
    }()
}

struct StatusBadge: View {
    let status: Session.SessionStatus

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
        case .inProgress: return "clock.fill"
        case .cancelled: return "xmark.circle.fill"
        default: return "calendar.circle.fill"
        }
    }

    private var label: String {
        switch status {
        case .scheduled: return "Planifiée"
        case .enRoute: return "En route"
        case .inProgress: return "En cours"
        case .completed: return "Terminée"
        case .cancelled: return "Annulée"
        case .noShow: return "Absent"
        }
    }

    private var bgColor: Color {
        switch status {
        case .completed: return Color.green.opacity(0.2)
        case .inProgress: return Color.blue.opacity(0.2)
        case .cancelled: return Color.red.opacity(0.2)
        default: return Color.gray.opacity(0.2)
        }
    }

    private var fgColor: Color {
        switch status {
        case .completed: return .green
        case .inProgress: return .blue
        case .cancelled: return .red
        default: return .gray
        }
    }
}

// MARK: - NewSessionView

struct NewSessionView: View {
    @Environment(\.dismiss) var dismiss
    var onCreated: () -> Void

    @State private var clients: [Client] = []
    @State private var selectedClientId: String = ""
    @State private var serviceType = "IV_Hydration"
    @State private var scheduledAt: Date = Date()
    @State private var address = ""
    @State private var notes = ""
    @State private var estimatedDuration: Int = 60
    @State private var totalAmount: String = "0"
    @State private var errorMessage: String?
    @State private var isLoadingClients = true

    let serviceTypes = ["IV_Hydration", "Post_Op", "Primary_Care", "Vaccination", "Consultation"]

    private var selectedClient: Client? {
        clients.first(where: { $0.id == selectedClientId })
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Client")) {
                    if isLoadingClients {
                        HStack { ProgressView(); Text("Chargement…").foregroundStyle(.secondary) }
                    } else if clients.isEmpty {
                        Text("Aucun client actif — créez d'abord un client.")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Picker("Client", selection: $selectedClientId) {
                            ForEach(clients) { p in
                                Text(p.fullName).tag(p.id)
                            }
                        }
                        .onChange(of: selectedClientId) { _, newId in
                            // Auto-remplit l'adresse depuis le client sélectionné
                            // si l'utilisateur n'a pas encore tapé une adresse custom.
                            if let p = clients.first(where: { $0.id == newId }),
                               address.isEmpty || clients.contains(where: { $0.fullAddress == address }) {
                                address = p.fullAddress
                            }
                        }
                    }
                }

                Section(header: Text("Formulation")) {
                    Picker("Formulation IV", selection: $serviceType) {
                        ForEach(serviceTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    DatePicker("Date", selection: $scheduledAt, displayedComponents: [.date, .hourAndMinute])
                    Stepper("Durée : \(estimatedDuration) min", value: $estimatedDuration, in: 15...240, step: 15)
                }

                Section(header: Text("Adresse")) {
                    TextField("Adresse", text: $address, axis: .vertical)
                        .lineLimit(1...3)
                    if let p = selectedClient, p.fullAddress != address, !address.isEmpty {
                        Text("⚠ Adresse différente de l'adresse du client")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Section(header: Text("Détails cliniques")) {
                    TextField("Notes cliniques", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Montant ($)", text: $totalAmount)
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
                    Button("Créer") { createSession() }
                        .disabled(selectedClientId.isEmpty || address.isEmpty)
                }
            }
            .task { await loadClients() }
        }
    }

    private func loadClients() async {
        isLoadingClients = true
        defer { isLoadingClients = false }
        do {
            clients = try await APIService.shared.getClients(archived: false)
            if selectedClientId.isEmpty, let first = clients.first {
                selectedClientId = first.id
                address = first.fullAddress
            }
        } catch {
            errorMessage = "Impossible de charger les clients : \(error.localizedDescription)"
        }
    }

    private func createSession() {
        guard let client = selectedClient else { return }
        // Si l'adresse est inchangée par rapport à celle du client, on laisse
        // le backend copier ses coords. Si l'adresse a été éditée, on envoie nil
        // pour les coords — le backend re-géocodera si un token Mapbox est dispo.
        let useCustomAddress = address != client.fullAddress
        let total = Double(totalAmount.replacingOccurrences(of: ",", with: ".")) ?? 0

        let newSession = Session(
            id: UUID().uuidString,
            clientId: client.id,
            nurseId: "",  // serveur remplit depuis le JWT
            clientName: client.fullName,
            formulationName: serviceType,
            formulationInventoryId: nil,
            status: .scheduled,
            scheduledAt: scheduledAt,
            createdAt: Date(),
            address: address,
            latitude: useCustomAddress ? nil : client.latitude,
            longitude: useCustomAddress ? nil : client.longitude,
            totalAmount: total,
            estimatedDuration: estimatedDuration,
            startedAt: nil,
            completedAt: nil,
            ivStartTime: nil,
            ivEndTime: nil,
            preVitals: nil,
            duringVitals: nil,
            postVitals: nil,
            dripRate: nil,
            clinicalNotes: notes.isEmpty ? nil : notes,
            photosPaths: [],
            cancelledAt: nil,
            cancellationReason: nil
        )
        Task {
            do {
                _ = try await APIService.shared.createSession(session: newSession)
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
    SessionsListView()
        .environmentObject(AuthViewModel())
}
