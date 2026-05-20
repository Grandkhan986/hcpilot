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
                    AuditRow(entry: entry)
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
            Image(systemName: iconForEntity(entry.entity_type))
                .foregroundStyle(colorForAction(entry.action))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(labelForEntity(entry.entity_type))
                        .font(.subheadline).fontWeight(.semibold)
                    Text("·").foregroundStyle(.secondary)
                    Text(labelForAction(entry.action))
                        .font(.caption)
                        .foregroundStyle(colorForAction(entry.action))
                }
                Text(entry.entity_id)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                if let changes = entry.changes, !changes.isEmpty {
                    Text(formatChanges(changes))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    Text(formatDate(entry.occurred_at))
                        .font(.caption2).foregroundStyle(.secondary)
                    if let ip = entry.ip_address {
                        Text("IP: \(ip)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func labelForEntity(_ s: String) -> String {
        switch s {
        case "consents": return "Consentement"
        case "clients": return "Client"
        case "sessions": return "Session"
        case "inventory_transactions": return "Stock"
        default: return s.capitalized
        }
    }

    private func iconForEntity(_ s: String) -> String {
        switch s {
        case "consents": return "doc.text.fill"
        case "clients": return "person.fill"
        case "sessions": return "calendar"
        case "inventory_transactions": return "cube.fill"
        default: return "circle.fill"
        }
    }

    private func labelForAction(_ s: String) -> String {
        switch s {
        case "create": return "Création"
        case "update": return "Modification"
        case "delete": return "Suppression"
        case "read": return "Lecture"
        case "export": return "Export"
        default: return s
        }
    }

    private func colorForAction(_ s: String) -> Color {
        switch s {
        case "create": return .blue
        case "update": return .orange
        case "delete": return .red
        case "export": return .purple
        default: return .secondary
        }
    }

    private func formatChanges(_ changes: [String: AnyDecodable]) -> String {
        changes.map { "\($0.key)=\($0.value.value)" }.joined(separator: ", ")
    }

    private func formatDate(_ s: String) -> String {
        // 2026-05-20T14:32:01.123 → "20/05 14:32"
        guard s.count >= 16 else { return s }
        let date = String(s[s.index(s.startIndex, offsetBy: 8)..<s.index(s.startIndex, offsetBy: 10)])
            + "/" + String(s[s.index(s.startIndex, offsetBy: 5)..<s.index(s.startIndex, offsetBy: 7)])
        let time = String(s[s.index(s.startIndex, offsetBy: 11)..<s.index(s.startIndex, offsetBy: 16)])
        return "\(date) \(time)"
    }
}
