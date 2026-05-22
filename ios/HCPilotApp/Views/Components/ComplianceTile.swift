import SwiftUI

/// Tile de conformité affichée sur l'écran d'accueil (brief §refonte Home).
/// Présente le pire statut parmi licence / MD / standing orders avec un libellé
/// actionnable. La couleur suit la sémantique HCPilot : vert/orange/rouge.
struct ComplianceTile: View {
    let status: ComplianceStatus
    let issueCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.subheadline)
                    .foregroundStyle(tint)
                Text("Conformité")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var tint: Color {
        switch status {
        case .ok, .unknown: return .green
        case .warning: return .orange
        case .critical, .expired: return .red
        }
    }

    private var label: String {
        switch status {
        case .ok, .unknown:
            return "Tout OK"
        case .warning:
            return "\(issueCount) à surveiller"
        case .critical, .expired:
            return issueCount > 1
                ? "\(issueCount) urgents"
                : "1 urgent"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ComplianceTile(status: .ok, issueCount: 0)
        ComplianceTile(status: .warning, issueCount: 2)
        ComplianceTile(status: .critical, issueCount: 1)
        ComplianceTile(status: .expired, issueCount: 3)
    }
    .padding()
    .background(Color(.systemGray6))
}
