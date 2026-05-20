import SwiftUI
import UserNotifications

/// Tableau de bord des notifications locales : permission, count programmé,
/// test rapide. Les rappels sont reprogrammés automatiquement à chaque chargement
/// des écrans Conformité (compliance) et Accueil (visites).
struct NotificationsView: View {
    @State private var status: UNAuthorizationStatus = .notDetermined
    @State private var totalScheduled = 0
    @State private var complianceScheduled = 0
    @State private var visitScheduled = 0
    @State private var isLoading = true
    @State private var feedback: String?

    var body: some View {
        Form {
            Section("Permission") {
                HStack {
                    Image(systemName: iconForStatus)
                        .foregroundStyle(colorForStatus)
                    Text(labelForStatus)
                    Spacer()
                }
                if status == .notDetermined {
                    Button("Demander la permission") {
                        Task { await requestPermission() }
                    }
                } else if status == .denied {
                    Text("Activez les notifications dans Réglages iOS → HCPilot.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Notifications programmées") {
                if isLoading {
                    ProgressView()
                } else {
                    HStack {
                        Label("Conformité (licence/MD/SO)", systemImage: "checkmark.shield")
                        Spacer()
                        Text("\(complianceScheduled)").foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Rappels de visites", systemImage: "calendar")
                        Spacer()
                        Text("\(visitScheduled)").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Total programmé").fontWeight(.semibold)
                        Spacer()
                        Text("\(totalScheduled)")
                    }
                }
            }

            Section("Brief Sprint 6") {
                Text("Les seuils suivent le brief :")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Licence : J-90, J-30, J-7, J-1")
                    Text("• Contrat MD : J-60, J-30, J-7")
                    Text("• Standing order : J-30, J-7")
                    Text("• Audit MD : J-7 et jour J")
                    Text("• Visite : J-1 (8h) et H-2")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Test") {
                Button {
                    Task {
                        await NotificationService.shared.scheduleSmokeTest()
                        feedback = "Notification de test prévue dans 5 secondes."
                    }
                } label: {
                    Label("Lancer un test (5s)", systemImage: "bell.badge")
                }
                .disabled(status != .authorized && status != .provisional)
                Button(role: .destructive) {
                    Task {
                        await NotificationService.shared.removeAll()
                        feedback = "Toutes les notifications ont été annulées."
                        await refresh()
                    }
                } label: {
                    Label("Tout annuler", systemImage: "trash")
                }
            }

            if let feedback {
                Section { Text(feedback).font(.caption).foregroundStyle(.blue) }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private func requestPermission() async {
        _ = await NotificationService.shared.requestPermissionIfNeeded()
        await refresh()
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        status = await NotificationService.shared.authorizationStatus()
        complianceScheduled = await NotificationService.shared.pendingByPrefix("compliance:")
        visitScheduled = await NotificationService.shared.pendingByPrefix("visit:")
        totalScheduled = await NotificationService.shared.pendingCount()
    }

    private var iconForStatus: String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "checkmark.circle.fill"
        case .denied: return "xmark.octagon.fill"
        default: return "questionmark.circle"
        }
    }

    private var colorForStatus: Color {
        switch status {
        case .authorized, .provisional, .ephemeral: return .green
        case .denied: return .red
        default: return .orange
        }
    }

    private var labelForStatus: String {
        switch status {
        case .authorized: return "Autorisées"
        case .provisional: return "Provisoires (silencieuses)"
        case .ephemeral: return "Éphémères"
        case .denied: return "Refusées"
        case .notDetermined: return "Non demandées"
        @unknown default: return "Inconnu"
        }
    }
}
