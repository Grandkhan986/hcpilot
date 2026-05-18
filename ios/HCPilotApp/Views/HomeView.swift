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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Ma Journée")
                                .font(.headline)
                            Spacer()
                            Button("Optimiser", action: viewModel.optimizeRoute)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                        MapView(coordinate: viewModel.currentLocation)
                            .frame(height: 200)
                            .cornerRadius(12)

                        Button(viewModel.nextActiveVisit?.status == .in_progress ? "Continuer" : "Commencer") {
                            if let next = viewModel.nextActiveVisit {
                                viewModel.startVisit(next)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(viewModel.nextActiveVisit == nil)
                        .opacity(viewModel.nextActiveVisit == nil ? 0.5 : 1)
                    }
                    .padding(.horizontal)

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

struct MapView: View {
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        Map(initialPosition: .region(region))
    }

    private var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
