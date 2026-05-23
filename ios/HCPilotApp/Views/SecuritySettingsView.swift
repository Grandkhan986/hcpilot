import SwiftUI

/// Réglages de sécurité conformes au brief HIPAA :
/// - Timeout d'inactivité configurable (par défaut 30 min)
/// - Bouton "Verrouiller maintenant" (force le logout)
/// - Informations sur le stockage Keychain
struct SecuritySettingsView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedTimeout: Int = SecuritySettings.inactivityTimeoutMinutes
    @State private var lastActivity: Date? = SecureStorage.shared.getDate(forKey: .lastActivity)
    @State private var showLockConfirm = false

    // Audit M-108 : étendre les options jusqu'à 2h pour les nurses en tournée
    // longue (8h+ sur la route).
    private let options = [5, 15, 30, 60, 120]

    var body: some View {
        Form {
            Section("Verrouillage automatique") {
                Picker("Délai d'inactivité", selection: $selectedTimeout) {
                    ForEach(options, id: \.self) { m in
                        Text(label(forMinutes: m)).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedTimeout) { _, newValue in
                    SecuritySettings.inactivityTimeoutMinutes = newValue
                }
                .accessibilityIdentifier("security.timeout.picker")
                Text("Au-delà de \(label(forMinutes: selectedTimeout)) sans activité, vous serez automatiquement déconnecté(e). Conforme au brief HIPAA.")
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
                    // Audit H-105 : confirm avant logout pour éviter le tap accidentel.
                    showLockConfirm = true
                } label: {
                    Label("Verrouiller maintenant", systemImage: "lock.fill")
                }
                .accessibilityIdentifier("security.lockNow")
            }
        }
        .navigationTitle("Sécurité")
        .navigationBarTitleDisplayMode(.inline)
        // Fork A Lot 1 / UI-T2 : alert au lieu de confirmationDialog.
        .alert("Verrouiller la session ?", isPresented: $showLockConfirm) {
            Button("Verrouiller", role: .destructive) { authViewModel.logout() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Vous devrez vous reconnecter avec votre email et mot de passe.")
        }
        .onAppear {
            lastActivity = SecureStorage.shared.getDate(forKey: .lastActivity)
            selectedTimeout = SecuritySettings.inactivityTimeoutMinutes
        }
    }

    private func label(forMinutes m: Int) -> String {
        if m >= 60 {
            let h = m / 60
            return "\(h)h"
        }
        return "\(m) min"
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
