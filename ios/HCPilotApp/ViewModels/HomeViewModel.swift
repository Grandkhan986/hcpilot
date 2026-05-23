import SwiftUI
import CoreLocation

@MainActor
class HomeViewModel: ObservableObject {
    // Identité & greeting (brief §refonte Home — salutation contextuelle)
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var licenseType: String?  // RN | LPN | NP | MD | DO | PA — pilote le préfixe

    // KPIs
    @Published var monthlyRevenue = 0.0
    @Published var todaySessionsCount = 0

    // Sessions découpées en deux sections (brief §refonte Home)
    @Published var todaySessions: [Session] = []
    @Published var upcomingSessions: [Session] = []

    // Stock
    @Published var stockItems: [LowStockProduct] = []
    @Published var lowStockCount = 0

    // Compliance (brief §refonte Home — 3ème tile + douleur n°1)
    @Published var complianceStatus: ComplianceStatus = .unknown
    @Published var complianceIssueCount: Int = 0

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSyncing = false

    // Mini-aperçu de l'itinéraire du jour, affiché sur l'écran d'accueil.
    @Published var routeStops: [RouteMapStop] = []
    @Published var polylineCoordinates: [CLLocationCoordinate2D] = []

    /// Session candidate au bouton « Commencer/Continuer » (brief §refonte
    /// Home — bouton contextualisé). Préfère in_progress puis première
    /// scheduled de la journée par ordre chronologique.
    var nextActiveSession: Session? {
        if let inProgress = todaySessions.first(where: { $0.status == .inProgress }) {
            return inProgress
        }
        return todaySessions.first(where: { $0.status == .scheduled || $0.status == .enRoute })
    }

    /// État du bouton d'action principal sous la carte.
    enum StartButtonState: Equatable {
        case startDay(session: Session)
        case continueSession(session: Session, clientName: String?)
        case dayCompleted
        case noSessionToday
    }

    var startButtonState: StartButtonState {
        if todaySessions.isEmpty { return .noSessionToday }
        if let inProgress = todaySessions.first(where: { $0.status == .inProgress }) {
            return .continueSession(session: inProgress, clientName: inProgress.clientName)
        }
        let allFinished = todaySessions.allSatisfy { s in
            s.status == .completed || s.status == .cancelled || s.status == .noShow
        }
        if allFinished { return .dayCompleted }
        if let next = todaySessions.first(where: { $0.status == .scheduled || $0.status == .enRoute }) {
            return .startDay(session: next)
        }
        return .dayCompleted
    }

    /// Salutation horaire (brief §refonte Home).
    var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Bonjour"
        case 12..<18: return "Bon après-midi"
        default: return "Bonsoir"
        }
    }

    /// Nom affiché dans la salutation, préfixé selon le type de licence.
    /// RN/LPN/NP/PA → prénom seul ; MD/DO → « Dr. Nom ».
    var displayName: String {
        let type = (licenseType ?? "").uppercased()
        switch type {
        case "MD", "DO":
            return lastName.isEmpty ? firstName : "Dr. \(lastName)"
        default:
            return firstName.isEmpty ? "soignant" : firstName
        }
    }

    private let apiService = APIService.shared

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .full
        return formatter
    }()

    func load() {
        Task { await loadAll() }
    }

    func refresh() {
        Task { await loadAll() }
    }

    /// Charge dashboard + compliance en parallèle. La compliance échoue
    /// silencieusement (sans bloquer le reste du Home).
    private func loadAll() async {
        isLoading = true
        isSyncing = true
        errorMessage = nil
        async let dashboardTask: () = loadDashboard()
        async let complianceTask: () = loadCompliance()
        _ = await (dashboardTask, complianceTask)
        isLoading = false
        isSyncing = false
    }

    private func loadDashboard() async {
        do {
            let dashboard = try await apiService.getDashboard()

            todaySessionsCount = dashboard.todaySessions
            monthlyRevenue = dashboard.monthlyRevenue
            lowStockCount = dashboard.lowStockAlerts
            stockItems = dashboard.lowStockItems

            // Brief §refonte Home — split Aujourd'hui / Sessions à venir.
            // Calendar.isDateInToday respecte la timezone locale, donc
            // les sessions du jour sont celles dont scheduledAt tombe
            // aujourd'hui pour la nurse.
            let cal = Calendar.current
            let all = dashboard.sessionsToday.sorted { $0.scheduledAt < $1.scheduledAt }
            todaySessions = all.filter { cal.isDateInToday($0.scheduledAt) }
            upcomingSessions = all
                .filter { !cal.isDateInToday($0.scheduledAt) && $0.scheduledAt > Date() }
                .prefix(5)
                .map { $0 }

            await loadRouteOptimization()
            // Reprogramme les rappels J-1 et H-2 sur les sessions du jour + à venir
            await NotificationService.shared.scheduleSessionReminders(
                sessions: todaySessions + upcomingSessions
            )
        } catch {
            errorMessage = "Erreur lors du chargement: \(error.localizedDescription)"
        }
    }

    private func loadCompliance() async {
        do {
            let dash = try await apiService.getComplianceDashboard()
            let statuses: [ComplianceStatus] = [
                dash.license?.status,
                dash.medicalDirector?.contractStatus,
                dash.medicalDirector?.nextAuditStatus,
            ].compactMap { $0 } + dash.standingOrders.compactMap { $0.expirationStatus }

            complianceStatus = Self.worst(of: statuses)
            complianceIssueCount = statuses.filter { $0 == .warning || $0 == .critical || $0 == .expired }.count
            licenseType = dash.license?.licenseType
        } catch {
            // Compliance échoue silencieusement — le reste du Home doit rester utilisable.
        }
    }

    /// Worst-of compliance (brief §refonte Home — pire statut parmi
    /// licence/MD/standing orders). Ordre : expired > critical > warning > ok.
    /// `unknown` est traité comme `ok` (rien à signaler).
    /// `nonisolated` car pur calcul sans état partagé — testable sans @MainActor.
    nonisolated static func worst(of statuses: [ComplianceStatus]) -> ComplianceStatus {
        let order: [ComplianceStatus] = [.expired, .critical, .warning, .ok, .unknown]
        for s in order {
            if statuses.contains(s) { return s == .unknown ? .ok : s }
        }
        return .ok
    }

    /// Calcule l'itinéraire optimisé du jour et alimente `routeStops` + `polylineCoordinates`
    /// pour la mini-carte du Home. Silencieux en cas d'échec.
    private func loadRouteOptimization() async {
        let activeSessions = todaySessions.filter { $0.status != .cancelled }
        let withCoords = activeSessions.compactMap { v -> (Session, CLLocationCoordinate2D)? in
            if let lat = v.latitude, let lng = v.longitude {
                return (v, CLLocationCoordinate2D(latitude: lat, longitude: lng))
            }
            return nil
        }
        guard !withCoords.isEmpty else {
            routeStops = []
            polylineCoordinates = []
            return
        }

        do {
            let response = try await apiService.optimizeRoute(sessions: withCoords.map { $0.0 })
            let orderById = Dictionary(
                uniqueKeysWithValues: response.optimizedRoute.map { ($0.sessionId, $0.order) }
            )
            routeStops = withCoords.map { v, coord in
                let order = orderById[v.id] ?? Int.max
                let label = v.clientName ?? v.formulationName.replacingOccurrences(of: "_", with: " ")
                return RouteMapStop(
                    id: v.id,
                    order: order,
                    coordinate: coord,
                    title: label,
                    address: v.address,
                    status: v.status,
                    startedAt: v.startedAt,
                    completedAt: v.completedAt
                )
            }.sorted { $0.order < $1.order }
            polylineCoordinates = (response.routeGeometry ?? []).compactMap { pair in
                guard pair.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
            }
        } catch {
            // Non-bloquant pour le Home : le bouton Commencer reste opérationnel.
        }
    }

    func setUser(_ user: UserProfile?) {
        guard let user = user else {
            firstName = "soignant"
            lastName = ""
            return
        }
        // Strip leading honorifics — un fullName peut hériter d'un préfixe
        // historique ("Dr. Marie Dupont") même quand le titre ne correspond
        // pas au licenseType réel (cas du profil persistant en Keychain qui
        // survit aux changements de seed côté backend). Le préfixe « Dr. » est
        // ré-appliqué côté `displayName` selon le licenseType courant.
        var name = user.fullName.trimmingCharacters(in: .whitespaces)
        let honorifics = ["Dr.", "Dr", "Mr.", "Mr", "Mrs.", "Ms.", "M.", "Mme", "Mlle"]
        for h in honorifics {
            let prefix = h + " "
            if name.lowercased().hasPrefix(prefix.lowercased()) {
                name = String(name.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        let parts = name.split(separator: " ", maxSplits: 1).map(String.init)
        firstName = parts.first ?? user.fullName
        lastName = parts.count > 1 ? parts[1] : ""
    }

    func startSession(_ session: Session) {
        Task {
            do {
                _ = try await apiService.startSession(sessionId: session.id)
                await loadAll()
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }

    func completeSession(_ session: Session) {
        Task {
            do {
                _ = try await apiService.completeSession(sessionId: session.id)
                await loadAll()
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Composants UI réutilisables

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

/// Ligne de liste « session » — icône colorée selon le statut + badge de
/// formulation abrégée (brief §refonte Home — distinguer visuellement
/// scheduled/en_route/in_progress/completed/cancelled/no_show).
struct SessionListItem: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: statusIcon)
                            .foregroundColor(.white)
                            .font(.caption)
                    )
                Text(formulationAbbrev(session.formulationName))
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(.systemBackground))
                    .foregroundColor(.primary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: 0.5))
                    .offset(x: 4, y: 4)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.clientName ?? "Client")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .strikethrough(session.status == .cancelled, color: .secondary)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(session.scheduledAt, formatter: Self.timeFormatter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(session.formulationName.replacingOccurrences(of: "_", with: " "))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var statusColor: Color {
        switch session.status {
        case .scheduled: return Color.blue.opacity(0.7)
        case .enRoute: return .yellow
        case .inProgress: return .orange
        case .completed: return .green
        case .cancelled: return Color(.systemGray3)
        case .noShow: return .red
        }
    }

    private var statusIcon: String {
        switch session.status {
        case .scheduled: return "calendar.badge.clock"
        case .enRoute: return "car.fill"
        case .inProgress: return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle"
        case .noShow: return "exclamationmark.triangle.fill"
        }
    }

    /// Abrège la formulation pour le badge — brief §refonte Home.
    /// Heuristique : NAD+ Xmg → NX, sinon initiale ou 1-2 lettres.
    private func formulationAbbrev(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("nad") {
            if n.contains("500") { return "N500" }
            if n.contains("250") { return "N250" }
            return "NAD"
        }
        if n.contains("myers") { return "M" }
        if n.contains("vitamin") || n.contains("vita") { return "V" }
        if n.contains("hydra") { return "H" }
        if n.contains("zinc") { return "Z" }
        return String(name.prefix(1)).uppercased()
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.locale = Locale(identifier: "fr_FR")
        return f
    }()
}

struct StockStatusCard: View {
    let item: LowStockProduct

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "cube")
                        .foregroundColor(.white)
                        .font(.caption2)
                )

            Text(item.productName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.tail)

            Text("\(item.totalQuantity)")
                .font(.caption)
                .fontWeight(.semibold)

            Text("Faible")
                .font(.caption2)
                .foregroundColor(.red)
        }
        .frame(width: 80)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
