import SwiftUI

/// Vue d'inspection de la file de mutations offline (brief §Gestion offline).
/// Liste les actions cliniques en attente de sync (start/complete/usage/delete).
struct MutationQueueView: View {
    @StateObject private var queue = MutationQueue.shared
    @StateObject private var connectivity = ConnectivityState.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: connectivity.isOffline ? "wifi.exclamationmark" : "wifi")
                        .foregroundStyle(connectivity.isOffline ? .orange : .green)
                    Text(connectivity.isOffline ? "Hors-ligne" : "En ligne")
                    Spacer()
                    if let last = connectivity.lastSyncAt {
                        Text("Sync à \(last, style: .time)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("\(queue.count) mutation\(queue.count > 1 ? "s" : "") en attente") {
                if queue.pending.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("File vide — toutes les actions sont synchronisées.")
                            .font(.caption)
                    }
                } else {
                    ForEach(queue.pending) { m in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(m.method).font(.caption2.monospaced())
                                    .padding(.horizontal, 4).padding(.vertical, 2)
                                    .background(colorForMethod(m.method).opacity(0.18))
                                    .foregroundStyle(colorForMethod(m.method))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                Text(m.endpoint).font(.caption.monospaced())
                                Spacer()
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "clock").font(.caption2)
                                Text(m.queuedAt, style: .relative).font(.caption2)
                                if m.attempts > 0 {
                                    Text("· \(m.attempts) tentative\(m.attempts > 1 ? "s" : "")")
                                        .font(.caption2)
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Comportement") {
                Text("Les actions cliniques (start/complete session, usage stock, annulation) effectuées sans réseau sont mises en file. Au retour de connexion, la file est drainée automatiquement avec retry exponentiel. Les actions devenues obsolètes (4xx serveur) sont abandonnées (last-write-wins).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !queue.pending.isEmpty {
                Section {
                    Button {
                        Task { await MutationQueue.shared.drain(via: APIService.shared) }
                    } label: {
                        Label("Forcer la synchronisation", systemImage: "arrow.triangle.2.circlepath")
                    }
                    Button(role: .destructive) {
                        MutationQueue.shared.clear()
                    } label: {
                        Label("Vider la file (sans sync)", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("File de synchronisation")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorForMethod(_ s: String) -> Color {
        switch s {
        case "POST": return .blue
        case "PUT": return .orange
        case "DELETE": return .red
        default: return .secondary
        }
    }
}
