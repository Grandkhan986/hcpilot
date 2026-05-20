import SwiftUI
import MapKit

struct RouteMapStop: Identifiable, Equatable {
    let id: String          // session_id
    let order: Int          // position dans l'itinéraire optimisé (0-based)
    let coordinate: CLLocationCoordinate2D
    let title: String       // client_name ou type
    let address: String
    let status: Session.SessionStatus
    let startedAt: Date?
    let completedAt: Date?

    static func == (lhs: RouteMapStop, rhs: RouteMapStop) -> Bool {
        lhs.id == rhs.id && lhs.order == rhs.order && lhs.status == rhs.status
    }
}

struct RouteMapView: View {
    @StateObject private var viewModel = RouteMapViewModel()
    @State private var cameraPosition: MapCameraPosition = .region(RouteMapView.defaultRegion)
    @State private var hasFitInitially = false
    @State private var selectedStop: RouteMapStop?

    var body: some View {
        ZStack(alignment: .bottom) {
            RouteMapContent(
                stops: viewModel.stops,
                polylineCoordinates: viewModel.polylineCoordinates,
                cameraPosition: $cameraPosition,
                onSelectStop: { selectedStop = $0 },
                showsControls: true
            )
            .ignoresSafeArea()

            VStack(spacing: 8) {
                if let warning = viewModel.warning, !warning.isEmpty {
                    BannerView(text: warning, kind: .warning)
                }
                bottomContent
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
        }
        .navigationTitle("Itinéraire du jour")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 14) {
                    Button {
                        if !viewModel.stops.isEmpty {
                            withAnimation {
                                cameraPosition = .region(Self.region(for: viewModel.stops))
                            }
                        }
                    } label: {
                        Image(systemName: "scope")
                    }
                    .disabled(viewModel.stops.isEmpty)

                    Button {
                        Task { await viewModel.reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .task {
            await viewModel.reload()
        }
        .onChange(of: viewModel.stops) { _, newStops in
            if !hasFitInitially && !newStops.isEmpty {
                cameraPosition = .region(Self.region(for: newStops))
                hasFitInitially = true
            }
        }
        .sheet(item: $selectedStop) { stop in
            StopDetailSheet(
                stop: stop,
                onNavigate: { openInMaps(stop: $0) },
                onStart: { stop in
                    Task {
                        await viewModel.start(stopId: stop.id)
                        selectedStop = nil
                    }
                },
                onComplete: { stop in
                    Task {
                        await viewModel.complete(stopId: stop.id)
                        selectedStop = nil
                    }
                }
            )
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var bottomContent: some View {
        if viewModel.isLoading && viewModel.stops.isEmpty {
            HStack(spacing: 8) {
                ProgressView()
                Text("Optimisation en cours…")
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        } else if let next = viewModel.nextStop {
            RouteSummaryCard(
                nextStop: next,
                totalStops: viewModel.stops.count,
                totalDistanceKm: viewModel.totalDistanceKm,
                totalDurationMin: viewModel.totalDurationMin,
                onNavigate: { openInMaps(stop: next) }
            )
        } else if !viewModel.stops.isEmpty {
            // Toutes les sessions sont terminées/annulées.
            BannerView(text: "Toutes les sessions du jour sont terminées.", kind: .success)
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 8) {
                BannerView(text: error, kind: .error)
                Button("Réessayer") {
                    Task { await viewModel.reload() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            BannerView(
                text: "Aucune session géolocalisée aujourd'hui.",
                kind: .info
            )
        }
    }

    private func openInMaps(stop: RouteMapStop) {
        let placemark = MKPlacemark(coordinate: stop.coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = stop.title
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    // MARK: - Region helpers

    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )

    static func region(for stops: [RouteMapStop]) -> MKCoordinateRegion {
        guard !stops.isEmpty else { return defaultRegion }
        let lats = stops.map { $0.coordinate.latitude }
        let lngs = stops.map { $0.coordinate.longitude }
        let minLat = lats.min() ?? 48.8566
        let maxLat = lats.max() ?? 48.8566
        let minLng = lngs.min() ?? 2.3522
        let maxLng = lngs.max() ?? 2.3522
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        // 30% de padding, avec un span minimum pour rester lisible sur 1 stop.
        let latSpan = max((maxLat - minLat) * 1.3, 0.01)
        let lngSpan = max((maxLng - minLng) * 1.3, 0.01)
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lngSpan)
        )
    }
}

// MARK: - Shared map content (réutilisé par RouteMapView plein écran et la
// mini-carte du Home).

struct RouteMapContent: View {
    let stops: [RouteMapStop]
    let polylineCoordinates: [CLLocationCoordinate2D]
    @Binding var cameraPosition: MapCameraPosition
    var onSelectStop: ((RouteMapStop) -> Void)? = nil
    var showsControls: Bool = false

    var body: some View {
        let map = Map(position: $cameraPosition) {
            if polylineCoordinates.count >= 2 {
                MapPolyline(coordinates: polylineCoordinates)
                    .stroke(
                        Color.blue.opacity(0.85),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )
            }
            ForEach(stops) { stop in
                Annotation(stop.title, coordinate: stop.coordinate) {
                    if let onSelectStop {
                        Button { onSelectStop(stop) } label: {
                            StopMarker(stop: stop)
                        }
                        .buttonStyle(.plain)
                    } else {
                        StopMarker(stop: stop)
                    }
                }
            }
        }
        if showsControls {
            map.mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
        } else {
            map
        }
    }
}

// MARK: - Marker

struct StopMarker: View {
    let stop: RouteMapStop

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .shadow(radius: 2)
            Text("\(stop.order + 1)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var color: Color {
        switch stop.status {
        case .completed: return .green
        case .in_progress: return .blue
        case .cancelled: return .gray
        default: return .red
        }
    }
}

// MARK: - Detail sheet

private struct StopDetailSheet: View {
    let stop: RouteMapStop
    let onNavigate: (RouteMapStop) -> Void
    let onStart: (RouteMapStop) -> Void
    let onComplete: (RouteMapStop) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text("\(stop.order + 1)")
                    .font(.title2).bold()
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.red)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(stop.title)
                        .font(.headline)
                    StatusBadge(status: stop.status)
                }
                Spacer()
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "location")
                    .foregroundColor(.red)
                Text(stop.address)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }

            timeInfo

            VStack(spacing: 8) {
                Button {
                    onNavigate(stop)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "location.north.fill")
                        Text("Naviguer dans Plans").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                switch stop.status {
                case .scheduled, .en_route:
                    Button { onStart(stop) } label: {
                        actionLabel("play.circle.fill", "Commencer la session", color: .green)
                    }
                case .in_progress:
                    Button { onComplete(stop) } label: {
                        actionLabel("checkmark.circle.fill", "Terminer la session", color: .green)
                    }
                case .completed, .cancelled, .no_show:
                    EmptyView()
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
    }

    @ViewBuilder
    private var timeInfo: some View {
        switch stop.status {
        case .in_progress:
            if let startedAt = stop.startedAt {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill").foregroundStyle(.blue)
                    Text("En cours depuis")
                    Text(startedAt, style: .timer)
                        .monospacedDigit()
                }
                .font(.subheadline)
            }
        case .completed:
            if let started = stop.startedAt, let ended = stop.completedAt {
                let minutes = Int(ended.timeIntervalSince(started) / 60)
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text("Durée : \(minutes) min")
                }
                .font(.subheadline)
            }
        default:
            EmptyView()
        }
    }

    private func actionLabel(_ icon: String, _ text: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
            Text(text).fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color)
        .foregroundColor(.white)
        .cornerRadius(10)
    }
}

// MARK: - Summary card

private struct RouteSummaryCard: View {
    let nextStop: RouteMapStop
    let totalStops: Int
    let totalDistanceKm: Double
    let totalDurationMin: Int
    let onNavigate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(nextStop.order + 1)")
                .font(.headline).bold()
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.red)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(nextStop.title)
                    .font(.subheadline).fontWeight(.semibold)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("Étape \(nextStop.order + 1)/\(totalStops)")
                    if totalDistanceKm > 0 {
                        Text("·")
                        Text(String(format: "%.1f km", totalDistanceKm))
                        Text("·")
                        Text("\(totalDurationMin) min")
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: onNavigate) {
                HStack(spacing: 6) {
                    Image(systemName: "location.north.fill")
                    Text("Y aller").fontWeight(.semibold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.12), radius: 10, y: 2)
    }
}

// MARK: - Banner

private struct BannerView: View {
    enum Kind {
        case info, warning, success, error
        var bg: Color {
            switch self {
            case .info: return Color.gray.opacity(0.15)
            case .warning: return Color.orange.opacity(0.18)
            case .success: return Color.green.opacity(0.18)
            case .error: return Color.red.opacity(0.18)
            }
        }
        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            case .success: return "checkmark.circle"
            case .error: return "xmark.octagon"
            }
        }
    }

    let text: String
    let kind: Kind

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: kind.icon)
            Text(text)
                .font(.footnote)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(kind.bg)
        .cornerRadius(10)
    }
}

// MARK: - ViewModel

@MainActor
final class RouteMapViewModel: ObservableObject {
    @Published var stops: [RouteMapStop] = []
    @Published var polylineCoordinates: [CLLocationCoordinate2D] = []
    @Published var totalDistanceKm: Double = 0
    @Published var totalDurationMin: Int = 0
    @Published var isLoading = false
    @Published var warning: String?
    @Published var errorMessage: String?

    private let api = APIService.shared
    private let calendar = Calendar.current

    /// Première session non terminée dans l'ordre optimisé.
    var nextStop: RouteMapStop? {
        stops.first(where: { $0.status == .scheduled || $0.status == .in_progress })
    }

    func start(stopId: String) async {
        do {
            _ = try await api.startSession(sessionId: stopId)
            await reload()
        } catch {
            errorMessage = "Erreur démarrage : \(error.localizedDescription)"
        }
    }

    func complete(stopId: String) async {
        do {
            _ = try await api.completeSession(sessionId: stopId)
            await reload()
        } catch {
            errorMessage = "Erreur clôture : \(error.localizedDescription)"
        }
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        warning = nil
        defer { isLoading = false }

        do {
            async let sessionsTask = api.getSessions()
            async let clientsTask = api.getClients()
            let sessions = try await sessionsTask
            let clients = try await clientsTask

            let todays = sessions.filter {
                calendar.isDateInToday($0.scheduled_at) && $0.status != .cancelled
            }
            let withCoords = todays.compactMap { v -> (Session, CLLocationCoordinate2D)? in
                if let lat = v.latitude, let lng = v.longitude {
                    return (v, CLLocationCoordinate2D(latitude: lat, longitude: lng))
                }
                if let p = clients.first(where: { $0.id == v.client_id }),
                   let lat = p.latitude, let lng = p.longitude {
                    return (v, CLLocationCoordinate2D(latitude: lat, longitude: lng))
                }
                return nil
            }

            // Aucune coord exploitable : on évite un appel API inutile.
            guard !withCoords.isEmpty else {
                stops = []
                polylineCoordinates = []
                totalDistanceKm = 0
                totalDurationMin = 0
                return
            }

            let sessionsForOptim = withCoords.map { $0.0 }
            let response = try await api.optimizeRoute(sessions: sessionsForOptim)
            // On masque le warning "ordre conservé" quand il n'y a qu'un seul stop —
            // il n'y a juste rien à optimiser.
            warning = (withCoords.count == 1) ? nil : response.warning

            let orderById = Dictionary(
                uniqueKeysWithValues: response.optimized_route.map { ($0.session_id, $0.order) }
            )

            let built: [RouteMapStop] = withCoords.map { v, coord in
                let order = orderById[v.id] ?? Int.max
                let label = v.client_name ?? v.formulation_name.replacingOccurrences(of: "_", with: " ")
                return RouteMapStop(
                    id: v.id,
                    order: order,
                    coordinate: coord,
                    title: label,
                    address: v.address,
                    status: v.status,
                    startedAt: v.started_at,
                    completedAt: v.completed_at
                )
            }.sorted { $0.order < $1.order }

            stops = built
            // Geometry GeoJSON: [[lng, lat], ...] → CLLocationCoordinate2D
            polylineCoordinates = (response.route_geometry ?? []).compactMap { pair in
                guard pair.count >= 2 else { return nil }
                return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
            }
            totalDistanceKm = response.total_distance_m / 1000.0
            totalDurationMin = Int((response.total_duration_s / 60.0).rounded())
        } catch {
            errorMessage = "Erreur de chargement : \(error.localizedDescription)"
            stops = []
            polylineCoordinates = []
            totalDistanceKm = 0
            totalDurationMin = 0
        }
    }
}
