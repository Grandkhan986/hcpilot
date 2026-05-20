import SwiftUI

/// Réglages de sécurité conformes au brief HIPAA :
/// - Timeout d'inactivité configurable (par défaut 30 min)
/// - Bouton "Verrouiller maintenant" (force le logout)
/// - Informations sur le stockage Keychain
struct SecuritySettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTimeout: Int = SecuritySettings.inactivityTimeoutMinutes
    @State private var lastActivity: Date? = SecureStorage.shared.getDate(forKey: .lastActivity)

    private let options = [5, 15, 30, 60]

    var body: some View {
        Form {
            Section("Verrouillage automatique") {
                Picker("Délai d'inactivité", selection: $selectedTimeout) {
                    ForEach(options, id: \.self) { m in
                        Text("\(m) min").tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedTimeout) { _, newValue in
                    SecuritySettings.inactivityTimeoutMinutes = newValue
                }
                Text("Au-delà de \(selectedTimeout) minutes sans activité, vous serez automatiquement déconnecté(e). Conforme au brief HIPAA.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Activité") {
                if let last = lastActivity {
                    HStack {
                        Label("Dernière activité", systemImage: "clock")
                        Spacer()
                        Text(last, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Verrouillage prévu dans", systemImage: "lock")
                        Spacer()
                        Text(remainingText(last: last))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Aucune activité enregistrée").font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Stockage") {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield.fill").foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keychain iOS").fontWeight(.semibold)
                        Text("Token de session, profil et timestamp d'activité stockés dans le Keychain (chiffré au repos, non synchronisé via iCloud).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    authViewModel.logout()
                } label: {
                    Label("Verrouiller maintenant", systemImage: "lock.fill")
                }
            }
        }
        .navigationTitle("Sécurité")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            lastActivity = SecureStorage.shared.getDate(forKey: .lastActivity)
            selectedTimeout = SecuritySettings.inactivityTimeoutMinutes
        }
    }

    private func remainingText(last: Date) -> String {
        let timeout = SecuritySettings.inactivityTimeoutSeconds
        let remaining = timeout - Date().timeIntervalSince(last)
        if remaining <= 0 { return "Maintenant" }
        let min = Int(remaining / 60)
        let sec = Int(remaining.truncatingRemainder(dividingBy: 60))
        if min > 0 { return "\(min) min" }
        return "\(sec) s"
    }
}
