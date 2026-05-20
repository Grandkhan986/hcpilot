import SwiftUI
import MapKit

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Bonjour, \(viewModel.userName)")
                                .font(.headline)
                            Text("Aujourd'hui, \(Date.now, formatter: viewModel.dateFormatter)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // Stats Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(
                            title: "Revenu du mois",
                            value: String(format: "%.0f €", viewModel.monthlyRevenue),
                            icon: "eurosign.circle",
                            color: .green
                        )
                        StatCard(
                            title: "Sessions du jour",
                            value: "\(viewModel.todaySessionsCount)",
                            icon: "person.2.circle",
                            color: .blue
                        )
                    }
                    .padding(.horizontal)

                    // Today's Route Map
                    if !viewModel.routeStops.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ma Journée")
                                .font(.headline)

                            NavigationLink(destination: RouteMapView()) {
                                RouteMapContent(
                                    stops: viewModel.routeStops,
                                    polylineCoordinates: viewModel.polylineCoordinates,
                                    cameraPosition: .constant(.region(
                                        RouteMapView.region(for: viewModel.routeStops)
                                    ))
                                )
                                .frame(height: 180)
                                .cornerRadius(12)
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

                            SessionLifecycleButton(
                                session: viewModel.nextActiveSession,
                                onStart: { viewModel.startSession($0) },
                                onComplete: { viewModel.completeSession($0) }
                            )
                        }
                        .padding(.horizontal)
                    } else if viewModel.nextActiveSession != nil {
                        // Sessions du jour sans coordonnées (cas edge) : on garde le bouton lifecycle
                        // pour ne pas perdre la fonctionnalité "Commencer/Terminer".
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ma Journée")
                                .font(.headline)
                            SessionLifecycleButton(
                                session: viewModel.nextActiveSession,
                                onStart: { viewModel.startSession($0) },
                                onComplete: { viewModel.completeSession($0) }
                            )
                        }
                        .padding(.horizontal)
                    }

                    // Upcoming Sessions
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sessions à venir")
                                .font(.headline)
                            Spacer()
                            NavigationLink("Tout voir") {
                                SessionsListView()
                            }
                            .font(.caption)
                        }

                        if viewModel.upcomingSessions.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "calendar.circle")
                                    .font(.largeTitle)
                                    .foregroundStyle(.gray)
                                Text("Aucune session prévue")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ForEach(viewModel.upcomingSessions) { session in
                                SessionListItem(session: session)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Stock Status
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Statut du Stock")
                                .font(.headline)
                            if viewModel.lowStockCount > 0 {
                                Text("\(viewModel.lowStockCount) items faibles")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        if viewModel.stockItems.isEmpty {
                            Text("Stock en ordre")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                        } else {
                            HStack(spacing: 12) {
                                ForEach(viewModel.stockItems.prefix(3)) { item in
                                    StockStatusCard(item: item)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .refreshable {
                viewModel.refresh()
            }
            .onAppear {
                viewModel.setUser(authViewModel.user)
                viewModel.load()
            }
        }
    }
}

/// Bouton de cycle de vie d'une session. En `scheduled` : action inline
/// "Commencer". En `in_progress` : navigation vers le détail (où la sheet
/// LotUsageSheet capture le lot avant de clôturer). Affiche un compteur live.
struct SessionLifecycleButton: View {
    let session: Session?
    let onStart: (Session) -> Void
    let onComplete: (Session) -> Void  // conservé pour compat, non utilisé en in_progress

    var body: some View {
        if let session, session.status == .in_progress {
            VStack(spacing: 6) {
                if let startedAt = session.started_at {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text("En cours depuis")
                            .font(.caption2)
                        Text(startedAt, style: .timer)
                            .font(.caption2.monospacedDigit())
                    }
                    .foregroundStyle(.secondary)
                }
                NavigationLink {
                    SessionDetailView(session: session, onAction: {})
                } label: {
                    Text("Terminer la session")
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        } else {
            Button("Commencer") {
                if let session { onStart(session) }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(PrimaryButtonStyle())
            .disabled(session == nil)
            .opacity(session == nil ? 0.5 : 1)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
