import SwiftUI

struct AppMainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Accueil", systemImage: "house.fill")
                }
                .tag(0)

            VisitsListView()
                .tabItem {
                    Label("Visites", systemImage: "calendar.fill")
                }
                .tag(1)

            StockView()
                .tabItem {
                    Label("Stock", systemImage: "cube.fill")
                }
                .tag(2)

            InvoicesView()
                .tabItem {
                    Label("Factures", systemImage: "doc.text.fill")
                }
                .tag(3)

            ReportsView()
                .tabItem {
                    Label("Rapports", systemImage: "chart.bar.fill")
                }
                .tag(4)

            PatientsView()
                .tabItem {
                    Label("Patients", systemImage: "person.fill")
                }
                .tag(5)

            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle.fill")
                }
                .tag(6)
        }
        .accentColor(.blue)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.blue)
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    AppMainView()
        .environmentObject(AuthViewModel())
}
