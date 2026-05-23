import SwiftUI

/// Journal d'audit HIPAA — lecture seule. Liste les actions enregistrées
/// (création de consentement, archivage client, lifecycle session, usage stock)
/// avec timestamp, IP, et entité concernée.
struct AuditLogView: View {
    @State private var entries: [AuditLogEntry] = []
    @State private var filter: String = "all"
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let filters: [(label: String, value: String)] = [
        ("Tous", "all"),
        ("Consentements", "consents"),
        ("Clients", "clients"),
        ("Sessions", "sessions"),
        ("Stock", "inventory_transactions"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Picker("Type", selection: $filter) {
                ForEach(filters, id: \.value) { f in
                    Text(f.label).tag(f.value)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .onChange(of: filter) { _, _ in Task { await load() } }
            .accessibilityIdentifier("audit.filter")

            if isLoading && entries.isEmpty {
                Spacer(); ProgressView(); Spacer()
            } else if let err = errorMessage {
                Spacer(); Text(err).foregroundStyle(.red); Spacer()
            } else if entries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Aucune entrée dans le journal").foregroundStyle(.secondary)
                    Text("Les actions sensibles (consentement, session, stock) sont automatiquement journalisées.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                List(entries) { entry in
                    // Audit H-114 : tap sur entrée → détail complet.
                    NavigationLink {
                        AuditLogDetailView(entry: entry)
                    } label: {
                        AuditRow(entry: entry)
                    }
                    .accessibilityIdentifier("audit.row.\(entry.id)")
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Journal d'audit")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let type = filter == "all" ? nil : filter
            entries = try await APIService.shared.getAuditLogs(entityType: type)
        } catch {
            errorMessage = "Erreur : \(error.localizedDescription)"
        }
    }
}

private struct AuditRow: View {
    let entry: AuditLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconForEntity(entry.entityType))
                .foregroundStyle(colorForAction(entry.action))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(labelForEntity(entry.entityType))
                        .font(.subheadline).fontWeight(.semibold)
                    Text("·").foregroundStyle(.secondary)
                    Text(labelForAction(entry.action))
                        .font(.caption)
                        .foregroundStyle(colorForAction(entry.action))
                }
                Text(entry.entityId)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let changes = entry.changes {
                    Text(changes.displayString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    Text(entry.occurredAt, formatter: Self.timeFormatter)
                        .font(.caption2).foregroundStyle(.secondary)
                    if let ip = entry.ipAddress {
                        Text("IP: \(ip)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func labelForEntity(_ type: AuditEntityType) -> String {
        switch type {
        case .consents: return "Consentement"
        case .clients: return "Client"
        case .sessions: return "Session"
        case .inventoryTransactions: return "Mouvement de stock"
        case .inventoryLots: return "Lot d'inventaire"
        case .standingOrders: return "Standing order"
        case .medicalDirectors: return "Medical Director"
        case .complianceAlerts: return "Alerte"
        case .users: return "Profil"
        case .unknown: return "—"
        }
    }

    private func iconForEntity(_ type: AuditEntityType) -> String {
        switch type {
        case .consents: return "doc.text.fill"
        case .clients: return "person.fill"
        case .sessions: return "calendar"
        case .inventoryTransactions, .inventoryLots: return "cube.fill"
        case .standingOrders: return "doc.append"
        case .medicalDirectors: return "stethoscope"
        case .complianceAlerts: return "bell.fill"
        case .users: return "person.crop.circle"
        case .unknown: return "questionmark.circle"
        }
    }

    private func labelForAction(_ a: AuditAction) -> String {
        switch a {
        case .create: return "Création"
        case .update: return "Modification"
        case .delete: return "Suppression"
        case .read: return "Lecture"
        case .export: return "Export"
        case .unknown: return "—"
        }
    }

    private func colorForAction(_ a: AuditAction) -> Color {
        switch a {
        case .create: return .blue
        case .update: return .orange
        case .delete: return .red
        case .export: return .purple
        default: return .secondary
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "dd/MM HH:mm"
        return f
    }()
}

/// Audit H-114 : vue détail accessible au tap sur une AuditRow.
/// Affiche tous les champs de l'entrée HIPAA sans truncation.
struct AuditLogDetailView: View {
    let entry: AuditLogEntry

    private static let fullDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .full
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        Form {
            Section("Entité") {
                row("Type", value: labelForEntity(entry.entityType))
                row("ID", value: entry.entityId, monospaced: true)
            }

            Section("Action") {
                row("Type d'action", value: labelForAction(entry.action))
                row("Effectuée le", value: Self.fullDateFmt.string(from: entry.occurredAt))
            }

            if let changes = entry.changes {
                Section {
                    Text(changes.displayString)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .accessibilityIdentifier("audit.detail.changes")
                } header: {
                    Text("Détail des changements")
                } footer: {
                    Text("Format clé : valeur. Sélectionnable pour copie.")
                        .font(.caption2)
                }
            }

            Section("Contexte requête") {
                if let ip = entry.ipAddress, !ip.isEmpty {
                    row("Adresse IP", value: ip, monospaced: true)
                }
                if let ua = entry.userAgent, !ua.isEmpty {
                    row("User Agent", value: ua, monospaced: true)
                }
                if let n = entry.nurseId {
                    row("Nurse ID", value: n, monospaced: true)
                }
            }
        }
        .navigationTitle("Entrée d'audit")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func row(_ label: String, value: String, monospaced: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(monospaced ? .system(.subheadline, design: .monospaced) : .subheadline)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private func labelForEntity(_ type: AuditEntityType) -> String {
        switch type {
        case .consents: return "Consentement"
        case .clients: return "Client"
        case .sessions: return "Session"
        case .inventoryTransactions: return "Mouvement de stock"
        case .inventoryLots: return "Lot d'inventaire"
        case .standingOrders: return "Standing order"
        case .medicalDirectors: return "Medical Director"
        case .complianceAlerts: return "Alerte"
        case .users: return "Profil"
        case .unknown: return "—"
        }
    }

    private func labelForAction(_ a: AuditAction) -> String {
        switch a {
        case .create: return "Création"
        case .update: return "Modification"
        case .delete: return "Suppression"
        case .read: return "Lecture"
        case .export: return "Export"
        case .unknown: return "—"
        }
    }
}
