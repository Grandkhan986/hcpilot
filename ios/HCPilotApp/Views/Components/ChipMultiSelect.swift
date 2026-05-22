import SwiftUI

/// Composant chips multi-select brief-aligned (§création client) :
/// allergies / conditions / médications avec choix prédéfinis + saisie libre.
///
/// Usage :
/// ```
/// ChipMultiSelect(
///     title: "Allergies",
///     predefined: ["Pénicilline", "Latex", ...],
///     selection: $client.allergies,
///     placeholder: "Autre allergie..."
/// )
/// ```
struct ChipMultiSelect: View {
    let title: String
    let predefined: [String]
    @Binding var selection: [String]
    var placeholder: String = "Ajouter…"

    @State private var customInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline).fontWeight(.semibold)
            }

            // Chips prédéfinies — toggle
            FlowLayout(spacing: 6) {
                ForEach(predefined, id: \.self) { item in
                    Chip(
                        label: item,
                        isSelected: selection.contains(item),
                        onTap: { toggle(item) }
                    )
                }
            }

            // Chips custom (ajoutées par l'utilisateur, pas dans predefined)
            let customs = selection.filter { !predefined.contains($0) }
            if !customs.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(customs, id: \.self) { item in
                        Chip(label: item, isSelected: true, onTap: { toggle(item) })
                    }
                }
            }

            // Champ saisie libre
            HStack(spacing: 6) {
                TextField(placeholder, text: $customInput)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(addCustom)
                Button {
                    addCustom()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(customInput.isEmpty ? Color.secondary : Color.blue)
                }
                .disabled(customInput.isEmpty)
            }
        }
    }

    private func toggle(_ item: String) {
        if let idx = selection.firstIndex(of: item) {
            selection.remove(at: idx)
        } else {
            selection.append(item)
        }
    }

    private func addCustom() {
        let trimmed = customInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !selection.contains(trimmed) else {
            customInput = ""
            return
        }
        selection.append(trimmed)
        customInput = ""
    }
}

/// Chip individuelle avec état sélectionné / non.
private struct Chip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark").font(.caption2.bold())
                }
                Text(label).font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Layout flow simple — wrap automatique des chips sur plusieurs lignes.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth, lineWidth > 0 {
                totalHeight += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth.isFinite ? maxWidth : lineWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// Suggestions brief-aligned (§création client : "chips prédéfinies").
enum ChipPresets {
    static let allergies = [
        "Pénicilline", "Latex", "Iode", "Aspirine", "Sulfamides",
        "Fruits à coque", "Œufs", "Poisson/Fruits de mer", "Anesthésie locale",
    ]
    static let medicalConditions = [
        "Diabète type 2", "Hypertension", "Asthme", "BPCO",
        "Insuffisance cardiaque", "Insuffisance rénale", "Grossesse",
        "Dépression", "Anxiété", "Hypothyroïdie",
    ]
}
