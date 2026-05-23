import SwiftUI
import MapKit

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedStockItem: LowStockProduct?
    @State private var navigateToInventoryProduct: String?
    @State private var navigateToCompliance: Bool = false

    // Brief §Dashboard : "auto-refresh 60s en foreground" — Timer publié toutes
    // les 60s. SwiftUI suspend automatiquement les Timer.publish quand l'app
    // passe en background, donc pas besoin de gérer scenePhase manuellement.
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    kpiRow
                    routeMapSection
                    todaySection
                    upcomingSection
                    stockSection
                }
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToCompliance) {
                ComplianceDashboardView()
            }
            .navigationDestination(item: $navigateToInventoryProduct) { productName in
                InventoryDetailView(productName: productName)
            }
            .refreshable { viewModel.refresh() }
            .onAppear {
                viewModel.setUser(authViewModel.user)
                viewModel.load()
            }
            .onReceive(refreshTimer) { _ in
                viewModel.refresh()
            }
            .sheet(item: $selectedStockItem) { item in
                LowStockSheet(item: item) {
                    navigateToInventoryProduct = item.productName
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bonjour, \(viewModel.displayName)")
                        .font(.headline)
                    Text(Date.now, formatter: viewModel.dateFormatter)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SyncStatusBadge(isSyncing: viewModel.isSyncing)
            }
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - KPI row (3 tiles compactes)

    private var kpiRow: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            NavigationLink(destination: ReportsView()) {
                StatCard(
                    title: "Revenu",
                    value: String(format: "%.0f €", viewModel.monthlyRevenue),
                    icon: "eurosign.circle",
                    color: .green
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.kpi.revenue")

            NavigationLink(destination: SessionsListView()) {
                StatCard(
                    title: "Sessions",
                    value: "\(viewModel.todaySessionsCount)",
                    icon: "person.2.circle",
                    color: .blue
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.kpi.sessions")

            Button { navigateToCompliance = true } label: {
                ComplianceTile(
                    status: viewModel.complianceStatus,
                    issueCount: viewModel.complianceIssueCount
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.kpi.compliance")
        }
        .padding(.horizontal)
    }

    // MARK: - Carte itinéraire

    @ViewBuilder
    private var routeMapSection: some View {
        if !viewModel.routeStops.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ma Journée")
                    .font(.headline)

                // Carte + bouton soudés visuellement (brief §refonte Home —
                // patch 5). Le bouton se trouve dans le même conteneur clippé,
                // collé en bas de la carte. Cela évite l'effet « flottant » et
                // donne un bloc cohérent.
                VStack(spacing: 0) {
                    NavigationLink(destination: RouteMapView()) {
                        RouteMapContent(
                            stops: viewModel.routeStops,
                            polylineCoordinates: viewModel.polylineCoordinates,
                            cameraPosition: .constant(.region(
                                RouteMapView.region(for: viewModel.routeStops)
                            ))
                        )
                        .frame(height: 300)
                        .allowsHitTesting(false)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption)
                                .padding(8)
                                .background(.regularMaterial)
                                .clipShape(Circle())
                                .padding(8)
                        }
                    }
                    .buttonStyle(.plain)

                    ContextualStartButton(state: viewModel.startButtonState) { session in
                        viewModel.startSession(session)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)

                // Fork A Lot 2 / H-29 : légende factuelle sous la carte.
                // Clarifie ce que représente la polyline + nombre de stops.
                HStack(spacing: 6) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.caption2)
                    Text("Trajet optimisé · \(viewModel.routeStops.count) stop\(viewModel.routeStops.count > 1 ? "s" : "")")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.top, 2)
                .accessibilityIdentifier("home.mapLegend")
            }
            .padding(.horizontal)
        } else if viewModel.nextActiveSession != nil {
            // Sessions du jour sans coordonnées (cas edge) : on garde le bouton lifecycle
            // pour ne pas perdre la fonctionnalité "Commencer/Terminer".
            VStack(alignment: .leading, spacing: 8) {
                Text("Ma Journée")
                    .font(.headline)
                ContextualStartButton(state: viewModel.startButtonState) { session in
                    viewModel.startSession(session)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Today section (brief §refonte Home — split)

    @ViewBuilder
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aujourd'hui")
                .font(.headline)

            if viewModel.todaySessions.isEmpty {
                emptyTodayCard
            } else {
                ForEach(viewModel.todaySessions) { session in
                    // Audit C-19 : SessionListItem doit être cliquable depuis
                    // l'accueil — c'est le point d'entrée principal pour
                    // reprendre une session après interruption.
                    NavigationLink {
                        SessionDetailView(session: session, onAction: { viewModel.refresh() })
                    } label: {
                        SessionListItem(session: session)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.todaySession.\(session.id)")
                }
            }
        }
        .padding(.horizontal)
    }

    private var emptyTodayCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Aucune session aujourd'hui")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            NavigationLink(destination: SessionsListView()) {
                Text("Voir le planning")
                    .font(.caption.weight(.semibold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Upcoming section

    @ViewBuilder
    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sessions à venir")
                    .font(.headline)
                Spacer()
                NavigationLink("Tout voir") { SessionsListView() }
                    .font(.caption)
            }

            if viewModel.upcomingSessions.isEmpty {
                if viewModel.todaySessions.isEmpty {
                    // Cas "totalement vide" — proposer une action constructive
                    emptyUpcomingFullCard
                } else {
                    emptyUpcomingShortCard
                }
            } else {
                ForEach(viewModel.upcomingSessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session, onAction: { viewModel.refresh() })
                    } label: {
                        SessionListItem(session: session)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.upcomingSession.\(session.id)")
                }
            }
        }
        .padding(.horizontal)
    }

    private var emptyUpcomingShortCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aucune session planifiée pour les prochains jours.")
                .font(.caption)
                .foregroundStyle(.secondary)
            // SessionFormView ne supporte que l'édition pour l'instant ; on
            // route vers SessionsListView qui hébergera le flow de création.
            NavigationLink(destination: SessionsListView()) {
                Label("Ajouter un rendez-vous", systemImage: "plus.circle.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var emptyUpcomingFullCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Aucune session planifiée.")
                .font(.subheadline)
            Text("Profitez-en pour gérer votre stock ou consulter votre conformité.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Stock

    @ViewBuilder
    private var stockSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Statut du stock")
                    .font(.headline)
                if viewModel.lowStockCount > 0 {
                    Text("\(viewModel.lowStockCount) items faibles")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if viewModel.stockItems.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Stock OK").font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 12) {
                    ForEach(viewModel.stockItems.prefix(3)) { item in
                        Button { selectedStockItem = item } label: {
                            StockStatusCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home.lowStock.\(item.productName)")
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Bouton « Commencer/Continuer/Terminé » contextualisé (brief §refonte Home)

struct ContextualStartButton: View {
    let state: HomeViewModel.StartButtonState
    let onStart: (Session) -> Void

    var body: some View {
        switch state {
        case .startDay(let session):
            Button("Commencer la journée") {
                onStart(session)
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(PrimaryButtonStyle())

        case .continueSession(let session, let name):
            NavigationLink {
                SessionDetailView(session: session, onAction: {})
            } label: {
                VStack(spacing: 4) {
                    if let started = session.startedAt {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill").font(.caption2)
                            Text("En cours depuis").font(.caption2)
                            Text(started, style: .timer).font(.caption2.monospacedDigit())
                        }
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    Text("Continuer la session de \(name ?? "Client")")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

        case .dayCompleted:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                Text("Journée terminée")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(8)

        case .noSessionToday:
            NavigationLink(destination: SessionsListView()) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("Planifier une session")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
