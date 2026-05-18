import SwiftUI

struct AppMainView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0

    private let tabs: [(title: String, icon: String)] = [
        ("Accueil", "house.fill"),
        ("Visites", "calendar"),
        ("Stock", "cube.fill"),
        ("Factures", "doc.text.fill"),
        ("Rapports", "chart.bar.fill"),
        ("Patients", "person.2.fill"),
        ("Profil", "person.crop.circle.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case 0: HomeView()
                case 1: VisitsListView()
                case 2: StockView()
                case 3: InvoicesView()
                case 4: ReportsView()
                case 5: PatientsView()
                case 6: ProfileView()
                default: HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HCPilotTabBar(tabs: tabs, selected: $selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

struct HCPilotTabBar: View {
    let tabs: [(title: String, icon: String)]
    @Binding var selected: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    selected = index
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: selected == index ? .semibold : .regular))
                        Text(tab.title)
                            .font(.system(size: 10, weight: selected == index ? .semibold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(selected == index ? Color.blue : Color.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(
            Color(.systemBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 4, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
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
