import SwiftUI
import CoreLocation

@MainActor
class HomeViewModel: ObservableObject {
    @Published var userName = ""
    @Published var monthlyRevenue = 0.0
    @Published var todaySessionsCount = 0
    @Published var upcomingSessions: [Session] = []
    @Published var stockItems: [LowStockProduct] = []
    @Published var lowStockCount = 0
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Mini-aperçu de l'itinéraire du jour, affiché sur l'écran d'accueil.
    @Published var routeStops: [RouteMapStop] = []
    @Published var polylineCoordinates: [CLLocationCoordinate2D] = []

    var nextActiveSession: Session? {
        upcomingSessions.first(where: { $0.status == .scheduled || $0.status == .inProgress })
    }

    private let apiService = APIService.shared

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .full
        return formatter
    }()

    func load() {
        Task {
            await loadDashboard()
        }
    }

    func refresh() {
        Task {
            await loadDashboard()
        }
    }

    private func loadDashboard() async {
        isLoading = true
        errorMessage = nil

        do {
            let dashboard = try await apiService.getDashboard()

            todaySessionsCount = dashboard.todaySessions
            monthlyRevenue = dashboard.monthlyRevenue
            lowStockCount = dashboard.lowStockAlerts
            upcomingSessions = dashboard.sessionsToday
            stockItems = dashboard.lowStockItems

            await loadRouteOptimization()
            // Reprogramme les rappels J-1 et H-2 selon les sessions du jour
            await NotificationService.shared.scheduleSessionReminders(sessions: upcomingSessions)
        } catch {
            errorMessage = "Erreur lors du chargement: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Calcule l'itinéraire optimisé du jour et alimente `routeStops` + `polylineCoordinates`
    /// pour la mini-carte du Home. Silencieux en cas d'échec.
    private func loadRouteOptimization() async {
        let activeSessions = upcomingSessions.filter { $0.status != .cancelled }
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
        userName = user?.fullName ?? "Docteur"
    }

    func startSession(_ session: Session) {
        Task {
            do {
                _ = try await apiService.startSession(sessionId: session.id)
                await loadDashboard()
            } catch {
                errorMessage = "Erreur: \(error.localizedDescription)"
            }
        }
    }

    func completeSession(_ session: Session) {
        Task {
            do {
                _ = try await apiService.completeSession(sessionId: session.id)
                await loadDashboard()
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct SessionListItem: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: statusIcon)
                        .foregroundColor(.white)
                        .font(.caption)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(session.clientName ?? "Client")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(session.scheduledAt, formatter: timeFormatter)
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
        case .inProgress: return .blue
        case .completed: return .green
        case .cancelled: return .red
        default: return .orange
        }
    }

    private var statusIcon: String {
        switch session.status {
        case .inProgress: return "clock.fill"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        default: return "calendar.badge.clock"
        }
    }

    var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
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
