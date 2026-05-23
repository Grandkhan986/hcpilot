import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var showSetupWizard = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white)
                            )

                        Text(authViewModel.user?.fullName ?? "Utilisateur")
                            .font(.headline)
                            .fontWeight(.bold)

                        Text(authViewModel.user?.specialty ?? "Professionnel de santé")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Menu
                    VStack(alignment: .leading, spacing: 0) {
                        ProfileMenuItem(icon: "person.crop.circle", title: "Mon profil")
                        ProfileMenuItem(icon: "envelope", title: "Messages")
                        NavigationLink(destination: NotificationsView()) {
                            ProfileMenuRow(icon: "bell", title: "Notifications")
                        }

                        Divider().padding(.vertical, 8)

                        ProfileMenuItem(icon: "eurosign.circle", title: "Revenus")
                        ProfileMenuItem(icon: "doc.text", title: "Factures")
                        ProfileMenuItem(icon: "creditcard", title: "Paiements")

                        Divider().padding(.vertical, 8)

                        Button { showSetupWizard = true } label: {
                            ProfileMenuRow(icon: "checkmark.shield", title: "Configuration de la pratique")
                        }
                        .accessibilityIdentifier("profile.openSetupWizard")
                        NavigationLink(destination: AuditLogView()) {
                            ProfileMenuRow(icon: "lock.doc", title: "Journal d'audit (HIPAA)")
                        }
                        NavigationLink(destination: SecuritySettingsView()) {
                            ProfileMenuRow(icon: "lock.shield.fill", title: "Sécurité")
                        }
                        NavigationLink(destination: SupplierSettingsView()) {
                            ProfileMenuRow(icon: "cart", title: "Fournisseur (réappro)")
                        }
                        NavigationLink(destination: MutationQueueView()) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.primary)
                                    .frame(width: 24)
                                Text("File de synchronisation")
                                    .foregroundColor(.primary)
                                Spacer()
                                if MutationQueue.shared.count > 0 {
                                    Text("\(MutationQueue.shared.count)")
                                        .font(.caption2).fontWeight(.semibold)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.orange)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        }
                        ProfileMenuItem(icon: "gear", title: "Paramètres")
                        NavigationLink(destination: LegalDocsView()) {
                            ProfileMenuRow(icon: "doc.text.below.ecg", title: "Mentions légales & HIPAA")
                        }
                    }
                    .padding(.top, 24)

                    Button(action: { authViewModel.logout() }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text("Déconnexion")
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                        .padding()
                    }
                    .padding(.top, 16)

                    Text("HCPilot v1.0.0")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showSetupWizard) {
                SetupWizardView(onCompleted: {})
            }
        }
    }
}

struct ProfileMenuItem: View {
    let icon: String
    let title: String

    var body: some View {
        Button(action: {}) {
            ProfileMenuRow(icon: icon, title: title)
        }
    }
}

/// Ligne d'item réutilisable (pour Button comme pour NavigationLink).
struct ProfileMenuRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.primary)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
