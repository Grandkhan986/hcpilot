import Foundation

/// File de mutations différées pour le mode offline (brief §Gestion offline).
/// Quand un appel POST/PUT/DELETE échoue avec une erreur réseau, on enqueue
/// la mutation. Au retour de connectivité, on draine la file (retry avec
/// exponential backoff). Résolution des conflits : last-write-wins (le serveur
/// est autoritaire ; si une mutation devient incohérente entre-temps, elle est
/// simplement abandonnée — 4xx renvoyé = drop).
///
/// Limites volontaires :
///   - Ne queue que les actions cliniques *légères* (start/complete session,
///     inventory usage, ack alertes). Les écritures lourdes (POST consent
///     avec PDF base64) ne passent pas par la queue.
///   - Pas de transformation/merge — chaque mutation est rejouée telle quelle.
struct PendingMutation: Codable, Identifiable {
    let id: String          // UUID stable pour dédoublonner
    let endpoint: String    // ex: "/sessions/vis_001/start"
    let method: String      // POST | DELETE
    let body: Data?         // JSON encodé si applicable
    var attempts: Int
    let queuedAt: Date
    var lastAttemptAt: Date?
}

@MainActor
final class MutationQueue: ObservableObject {
    static let shared = MutationQueue()
    private init() { load() }

    @Published private(set) var pending: [PendingMutation] = []

    private lazy var fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("HCPilotCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("mutation_queue.json")
    }()

    // MARK: - Public API

    func enqueue(endpoint: String, method: String, body: Data?) {
        // Audit H-96 : dédoublonnage. Si une mutation (endpoint, method) identique
        // a été enqueued dans les 5 dernières secondes, on ne re-enqueue pas —
        // évite les double POST quand l'utilisateur re-tape « Commencer » sur
        // une session déjà queuée. Note : on ne compare PAS les bodies (un body
        // peut différer pour un même endpoint+method, ex: updateClient).
        let recentDuplicate = pending.contains { m in
            m.endpoint == endpoint
                && m.method == method
                && Date().timeIntervalSince(m.queuedAt) < 5.0
        }
        if recentDuplicate { return }

        let mutation = PendingMutation(
            id: UUID().uuidString,
            endpoint: endpoint,
            method: method,
            body: body,
            attempts: 0,
            queuedAt: Date(),
            lastAttemptAt: nil
        )
        pending.append(mutation)
        persist()
    }

    /// Draine la file en séquence. Stoppe à la première erreur réseau pour
    /// éviter de spammer ; les 4xx sont droppés (mutation périmée).
    func drain(via api: APIService) async {
        var i = 0
        while i < pending.count {
            var m = pending[i]
            m.attempts += 1
            m.lastAttemptAt = Date()
            pending[i] = m

            let backoff = exponentialBackoff(attempts: m.attempts)
            if backoff > 0 {
                try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            }

            do {
                try await api.replay(mutation: m)
                pending.remove(at: i)  // succès → drop
                persist()
            } catch APIService.MutationReplayError.networkUnavailable {
                // Toujours offline — on garde la mutation et on stoppe
                persist()
                return
            } catch APIService.MutationReplayError.permanentFailure {
                // 4xx/5xx → la mutation est obsolète, on drop (last-write-wins)
                pending.remove(at: i)
                persist()
            } catch {
                // Erreur inconnue — on garde et on stoppe pour ne pas boucler
                persist()
                return
            }
        }
    }

    func clear() {
        pending.removeAll()
        persist()
    }

    var count: Int { pending.count }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let saved = try? decoder.decode([PendingMutation].self, from: data) {
            pending = saved
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(pending) else { return }
        try? data.write(to: fileURL, options: [
            .atomic,
            .completeFileProtectionUntilFirstUserAuthentication,
        ])
    }

    private func exponentialBackoff(attempts: Int) -> Double {
        // 1ère tentative immédiate (au moment du enqueue / drain), puis 1s, 2s, 4s, 8s max 30s.
        if attempts <= 1 { return 0 }
        return min(pow(2.0, Double(attempts - 1)), 30.0)
    }
}
