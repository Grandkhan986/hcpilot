import SwiftUI

/// Écran Compliance — 4 cards résumant l'état réglementaire de la nurse :
/// licence, Medical Director, standing orders, alertes.
/// En lecture seule pour cette première tranche.
struct ComplianceDashboardView: View {
    @StateObject private var vm = ComplianceViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if vm.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 60)
                } else if let dashboard = vm.dashboard {
                    LicenseCard(license: dashboard.license)
                    MedicalDirectorCard(md: dashboard.medicalDirector)
                    StandingOrdersCard(
                        orders: dashboard.standingOrders,
                        expiringSoon: dashboard.standingOrdersExpiringSoon
                    )
                    AlertsCard(
                        alerts: dashboard.alerts,
                        unreadCount: dashboard.unreadAlerts,
                        onAcknowledge: { id in Task { await vm.acknowledge(id) } }
                    )
                } else if let err = vm.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Conformité")
        .navigationBarTitleDisplayMode(.large)
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }
}

// MARK: - Cards

private struct LicenseCard: View {
    let license: LicenseInfo?

    var body: some View {
        ComplianceCard(title: "Ma Licence", systemImage: "person.crop.rectangle.badge.checkmark") {
            if let license {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(license.licenseNumber ?? "—")
                                .font(.title3).fontWeight(.semibold)
                            Text("\(license.licenseType ?? "?") · \(license.stateCode ?? "??")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusPill(status: license.status)
                    }
                    Divider()
                    HStack(spacing: 16) {
                        if let exp = license.expirationDate {
                            Label("Expire le \(LicenseCard.dateFmt.string(from: exp))", systemImage: "calendar")
                                .font(.caption)
                        }
                        if let d = license.daysRemaining {
                            Label(remainingLabel(days: d), systemImage: "hourglass")
                                .font(.caption)
                                .foregroundStyle(colorForStatus(license.status))
                        }
                    }
                }
            } else {
                Text("Aucune licence configurée.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func remainingLabel(days: Int) -> String {
        if days < 0 { return "Expirée depuis \(-days) jour\(-days > 1 ? "s" : "")" }
        if days == 0 { return "Expire aujourd'hui" }
        return "\(days) jour\(days > 1 ? "s" : "") restant\(days > 1 ? "s" : "")"
    }

    static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .medium
        return f
    }()
}

private struct MedicalDirectorCard: View {
    let md: MedicalDirectorInfo?

    var body: some View {
        ComplianceCard(title: "Medical Director", systemImage: "stethoscope") {
            if let md {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(md.fullName).font(.headline)
                            Text(md.email).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let s = md.contractStatus {
                            StatusPill(status: s)
                        }
                    }
                    Divider()
                    HStack(spacing: 12) {
                        if let endDate = md.contractEndDate {
                            Label("Contrat jusqu'au \(endDate)", systemImage: "doc.text")
                                .font(.caption)
                        }
                    }
                    if let audit = md.nextAuditDate {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar.badge.exclamationmark")
                            Text("Prochain audit : \(audit)")
                            Spacer()
                            if let s = md.nextAuditStatus {
                                Text(statusLabel(s))
                                    .font(.caption2)
                                    .foregroundStyle(colorForStatus(s))
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Aucun Medical Director configuré.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct StandingOrdersCard: View {
    let orders: [StandingOrderInfo]
    let expiringSoon: Int

    var body: some View {
        ComplianceCard(title: "Standing Orders", systemImage: "doc.text.fill") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(orders.count) actif\(orders.count > 1 ? "s" : "")")
                        .font(.title3).fontWeight(.semibold)
                    Spacer()
                    if expiringSoon > 0 {
                        Label("\(expiringSoon) à renouveler", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Divider()
                if orders.isEmpty {
                    Text("Aucune standing order active.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(orders) { order in
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(colorForStatus(order.expirationStatus ?? .ok))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(order.formulationName).font(.subheadline)
                                if let exp = order.expiresAt {
                                    Text("Expire le \(exp, style: .date)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

private struct AlertsCard: View {
    let alerts: [ComplianceAlertInfo]
    let unreadCount: Int
    let onAcknowledge: (String) -> Void

    var body: some View {
        ComplianceCard(title: "Alertes", systemImage: "bell.badge") {
            if alerts.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Tout est à jour").font(.subheadline)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(alerts) { alert in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: iconForSeverity(alert.severity))
                                .foregroundStyle(colorForSeverity(alert.severity))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.title).font(.subheadline).fontWeight(.semibold)
                                Text(alert.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if alert.acknowledgedAt == nil {
                                Button("Vu") { onAcknowledge(alert.id) }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                            } else {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                    if unreadCount > 0 {
                        Text("\(unreadCount) non-lue\(unreadCount > 1 ? "s" : "")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Building blocks

private struct ComplianceCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title).font(.headline)
            }
            content()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct StatusPill: View {
    let status: ComplianceStatus

    var body: some View {
        Text(statusLabel(status))
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorForStatus(status).opacity(0.18))
            .foregroundStyle(colorForStatus(status))
            .clipShape(Capsule())
    }
}

private func statusLabel(_ status: ComplianceStatus) -> String {
    switch status {
    case .ok: return "OK"
    case .warning: return "Attention"
    case .critical: return "Urgent"
    case .expired: return "Expiré"
    case .unknown: return "—"
    }
}

private func colorForStatus(_ status: ComplianceStatus) -> Color {
    switch status {
    case .ok: return .green
    case .warning: return .orange
    case .critical, .expired: return .red
    case .unknown: return .gray
    }
}

private func iconForSeverity(_ severity: AlertSeverity) -> String {
    switch severity {
    case .critical: return "exclamationmark.octagon.fill"
    case .warning: return "exclamationmark.triangle.fill"
    case .info: return "info.circle"
    }
}

private func colorForSeverity(_ severity: AlertSeverity) -> Color {
    switch severity {
    case .critical: return .red
    case .warning: return .orange
    case .info: return .blue
    }
}

// MARK: - ViewModel

@MainActor
final class ComplianceViewModel: ObservableObject {
    @Published var dashboard: ComplianceDashboard?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIService.shared

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let d = try await api.getComplianceDashboard()
            dashboard = d
            // Reprogramme les rappels J-90/J-30/etc. sur les seuils brief
            _ = await NotificationService.shared.requestPermissionIfNeeded()
            await NotificationService.shared.scheduleComplianceNotifications(from: d)
        } catch {
            errorMessage = "Erreur de chargement : \(error.localizedDescription)"
        }
    }

    func acknowledge(_ alertId: String) async {
        do {
            try await api.acknowledgeAlert(id: alertId)
            await load()
        } catch {
            errorMessage = "Erreur ack : \(error.localizedDescription)"
        }
    }
}
