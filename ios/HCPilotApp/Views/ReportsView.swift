import SwiftUI

struct ReportsView: View {
    @StateObject private var viewModel = ReportsViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Period selector
                    Picker("Période", selection: $viewModel.period) {
                        Text("Aujourd'hui").tag("today")
                        Text("Cette semaine").tag("this_week")
                        Text("Ce mois").tag("this_month")
                        Text("Cette année").tag("this_year")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .onChange(of: viewModel.period) { _, _ in
                        viewModel.load()
                    }

                    // Key Metrics
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        MetricCard(title: "Revenu total", value: viewModel.totalRevenue, color: .green)
                        MetricCard(title: "Total visites", value: "\(viewModel.totalVisits)", color: .blue)
                        MetricCard(title: "Panier moyen", value: viewModel.avgVisitValue, color: .purple)
                    }
                    .padding(.horizontal)

                    // Revenue by Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Revenus par type de service")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.revenueByType, id: \.key) { item in
                            RevenueBar(label: item.key, value: item.value, maxValue: viewModel.maxRevenue)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Rapports")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { viewModel.load() }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct RevenueBar: View {
    let label: String
    let value: Double
    let maxValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.0f €", value))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: maxValue > 0 ? min((value / maxValue) * geometry.size.width, geometry.size.width) : 0)
            }
            .frame(height: 8)
            .cornerRadius(4)
        }
    }
}

@MainActor
class ReportsViewModel: ObservableObject {
    @Published var period = "this_month"
    @Published var totalRevenue = "0 €"
    @Published var totalVisits = 0
    @Published var avgVisitValue = "0 €"
    @Published var revenueByType: [(key: String, value: Double)] = []
    @Published var maxRevenue: Double = 1

    private let apiService = APIService.shared

    func load() {
        Task { await fetchReport() }
    }

    private func fetchReport() async {
        do {
            let report = try await apiService.getRevenueReport(startDate: "2024-01-01", endDate: "2024-12-31")
            totalRevenue = String(format: "%.0f €", report.total_revenue)
            totalVisits = report.total_visits
            avgVisitValue = String(format: "%.0f €", report.average_visit_value)

            revenueByType = report.by_visit_type.map { (key: $0.key.replacingOccurrences(of: "_", with: " "), value: $0.value) }
                .sorted { $0.value > $1.value }
            maxRevenue = revenueByType.first?.value ?? 1
        } catch {
            // Fallback to mock data if API fails
            loadMockData()
        }
    }

    private func loadMockData() {
        totalRevenue = "28 500 €"
        totalVisits = 180
        avgVisitValue = "158 €"
        revenueByType = [
            ("Perfusion IV", 18000),
            ("Post-Op", 7000),
            ("Soins primaires", 3500)
        ]
        maxRevenue = 18000
    }
}

#Preview {
    ReportsView()
}
