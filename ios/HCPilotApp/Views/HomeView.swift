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
                            title: "Visites du jour",
                            value: "\(viewModel.todayVisitsCount)",
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

                            VisitLifecycleButton(
                                visit: viewModel.nextActiveVisit,
                                onStart: { viewModel.startVisit($0) },
                                onComplete: { viewModel.completeVisit($0) }
                            )
                        }
                        .padding(.horizontal)
                    } else if viewModel.nextActiveVisit != nil {
                        // Visites du jour sans coordonnées (cas edge) : on garde le bouton lifecycle
                        // pour ne pas perdre la fonctionnalité "Commencer/Terminer".
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ma Journée")
                                .font(.headline)
                            VisitLifecycleButton(
                                visit: viewModel.nextActiveVisit,
                                onStart: { viewModel.startVisit($0) },
                                onComplete: { viewModel.completeVisit($0) }
                            )
                        }
                        .padding(.horizontal)
                    }

                    // Upcoming Visits
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Visites à venir")
                                .font(.headline)
                            Spacer()
                            NavigationLink("Tout voir") {
                                VisitsListView()
                            }
                            .font(.caption)
                        }

                        if viewModel.upcomingVisits.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "calendar.circle")
                                    .font(.largeTitle)
                                    .foregroundStyle(.gray)
                                Text("Aucune visite prévue")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ForEach(viewModel.upcomingVisits) { visit in
                                VisitListItem(visit: visit)
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

/// Bouton de cycle de vie d'une visite. En `scheduled` : action inline
/// "Commencer". En `in_progress` : navigation vers le détail (où la sheet
/// LotUsageSheet capture le lot avant de clôturer). Affiche un compteur live.
struct VisitLifecycleButton: View {
    let visit: Visit?
    let onStart: (Visit) -> Void
    let onComplete: (Visit) -> Void  // conservé pour compat, non utilisé en in_progress

    var body: some View {
        if let visit, visit.status == .in_progress {
            VStack(spacing: 6) {
                if let startedAt = visit.started_at {
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
                    VisitDetailView(visit: visit, onAction: {})
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
                if let visit { onStart(visit) }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(PrimaryButtonStyle())
            .disabled(visit == nil)
            .opacity(visit == nil ? 0.5 : 1)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
