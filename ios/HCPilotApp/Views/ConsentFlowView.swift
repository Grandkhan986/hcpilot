import SwiftUI
import PencilKit
import UIKit

/// Flow complet de recueil du consentement éclairé en 4 étapes :
/// 1. Choix de la formulation
/// 2. Lecture du texte de consentement
/// 3. Checkpoints (acquittements obligatoires)
/// 4. Signature électronique + soumission
struct ConsentFlowView: View {
    let session: Session
    let clientName: String
    let nurseName: String
    var onCompleted: () -> Void

    @StateObject private var vm: ConsentFlowViewModel
    @Environment(\.dismiss) private var dismiss

    init(session: Session, clientName: String, nurseName: String, onCompleted: @escaping () -> Void) {
        self.session = session
        self.clientName = clientName
        self.nurseName = nurseName
        self.onCompleted = onCompleted
        _vm = StateObject(wrappedValue: ConsentFlowViewModel(
            session: session,
            clientName: clientName,
            nurseName: nurseName
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressDots(total: 4, current: vm.step)
                    .padding(.top, 12)

                TabView(selection: $vm.step) {
                    FormulationStep(vm: vm).tag(0)
                    ConsentTextStep(vm: vm).tag(1)
                    CheckpointsStep(vm: vm).tag(2)
                    SignatureStep(vm: vm).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: vm.step)
            }
            .navigationTitle("Consentement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task {
                await vm.loadFormulations()
            }
            .alert("Erreur", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .alert("Consentement enregistré", isPresented: $vm.justSubmitted) {
                Button("OK") {
                    onCompleted()
                    dismiss()
                }
            } message: {
                Text("Le document signé est disponible dans la fiche de la session.")
            }
        }
    }
}

// MARK: - Steps

private struct FormulationStep: View {
    @ObservedObject var vm: ConsentFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sous quelle Standing Order ?")
                .font(.headline)
                .padding(.horizontal)
            Text("La standing order signée par votre Medical Director autorise cette administration.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if vm.standingOrders.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(vm.standingOrders) { so in
                            Button {
                                vm.selectedStandingOrder = so
                                vm.consentText = so.consentText ?? ""
                                vm.step = 1
                            } label: {
                                StandingOrderCard(
                                    standingOrder: so,
                                    isSelected: vm.selectedStandingOrder?.id == so.id
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 16)
    }
}

private struct StandingOrderCard: View {
    let standingOrder: StandingOrderInfo
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(standingOrder.formulationName).font(.headline)
                HStack(spacing: 6) {
                    Text(standingOrder.formulationCategory.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                    if let exp = standingOrder.expiresAt {
                        Text("Exp. \(exp, style: .date)")
                            .font(.caption2)
                            .foregroundStyle(colorFor(standingOrder.expirationStatus ?? .ok))
                    }
                }
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                .foregroundStyle(isSelected ? .green : .secondary)
        }
        .padding()
        .background(isSelected ? Color.green.opacity(0.1) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func colorFor(_ status: ComplianceStatus) -> Color {
        switch status {
        case .ok, .unknown: return .secondary
        case .warning: return .orange
        case .critical, .expired: return .red
        }
    }
}

private struct ConsentTextStep: View {
    @ObservedObject var vm: ConsentFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(vm.selectedStandingOrder?.formulationName ?? "—")
                .font(.headline)
                .padding(.horizontal)

            ScrollView {
                Text(vm.consentText)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            }

            HStack {
                Button("Retour") { vm.step = 0 }
                    .buttonStyle(.bordered)
                Spacer()
                Button("J'ai lu, continuer") { vm.step = 2 }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .padding(.top, 16)
    }
}

private struct CheckpointsStep: View {
    @ObservedObject var vm: ConsentFlowViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acquittements")
                .font(.headline)
                .padding(.horizontal)
            Text("Cochez chaque point pour confirmer votre compréhension.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(spacing: 10) {
                ForEach(vm.checkpoints.indices, id: \.self) { i in
                    Toggle(isOn: $vm.checkpoints[i].accepted) {
                        Text(vm.checkpoints[i].label).font(.subheadline)
                    }
                    .toggleStyle(SwitchToggleStyle())
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)

            Spacer(minLength: 0)

            HStack {
                Button("Retour") { vm.step = 1 }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Continuer vers la signature") { vm.step = 3 }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.allCheckpointsAccepted)
            }
            .padding()
        }
        .padding(.top, 16)
    }
}

private struct SignatureStep: View {
    @ObservedObject var vm: ConsentFlowViewModel
    @State private var canvasView = PKCanvasView()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Signature du client")
                .font(.headline)
                .padding(.horizontal)
            Text("Le client signe ci-dessous avec son doigt.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            SignaturePad(canvasView: $canvasView)
                .frame(height: 220)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal)

            HStack {
                Button("Effacer") { canvasView.drawing = PKDrawing() }
                    .buttonStyle(.bordered)
                Spacer()
                if vm.isSubmitting {
                    ProgressView()
                } else {
                    Button("Confirmer la signature") {
                        Task { await vm.submit(canvas: canvasView) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(canvasView.drawing.bounds.isEmpty)
                }
            }
            .padding(.horizontal)

            Spacer(minLength: 0)

            // Info zone : géoloc + horodatage qui seront capturés
            VStack(alignment: .leading, spacing: 4) {
                Label("Horodatage automatique à la confirmation", systemImage: "clock")
                Label("Géolocalisation capturée si autorisée", systemImage: "location")
                Label("IP enregistrée côté serveur", systemImage: "network")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .padding(.top, 16)
    }
}

// MARK: - PencilKit wrapper

private struct SignaturePad: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

// MARK: - Progress dots

private struct ProgressDots: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i <= current ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
final class ConsentFlowViewModel: ObservableObject {
    @Published var step: Int = 0
    @Published var standingOrders: [StandingOrderInfo] = []
    @Published var selectedStandingOrder: StandingOrderInfo?
    @Published var consentText: String = ""
    @Published var checkpoints: [ConsentCheckpoint] = [
        ConsentCheckpoint(label: "Je comprends les risques généraux de la perfusion IV", accepted: false),
        ConsentCheckpoint(label: "Je comprends les risques spécifiques à la formulation choisie", accepted: false),
        ConsentCheckpoint(label: "J'autorise le partage du dossier avec le Medical Director", accepted: false),
        ConsentCheckpoint(label: "J'accepte la politique d'annulation", accepted: false),
    ]
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var justSubmitted = false

    let session: Session
    let clientName: String
    let nurseName: String

    private let api = APIService.shared
    private let location = LocationService()

    var allCheckpointsAccepted: Bool {
        !checkpoints.isEmpty && checkpoints.allSatisfy { $0.accepted }
    }

    init(session: Session, clientName: String, nurseName: String) {
        self.session = session
        self.clientName = clientName
        self.nurseName = nurseName
    }

    func loadFormulations() async {
        do {
            // Charge les standing orders actives de la nurse (et non un catalogue
            // statique) : la signature du consentement référence ainsi une vraie
            // autorisation réglementaire.
            let all = try await api.getStandingOrders()
            standingOrders = all.filter { $0.isActive }
        } catch {
            errorMessage = "Impossible de charger les standing orders : \(error.localizedDescription)"
        }
    }

    func submit(canvas: PKCanvasView) async {
        guard let standingOrder = selectedStandingOrder else {
            errorMessage = "Aucune standing order sélectionnée."
            return
        }
        guard allCheckpointsAccepted else {
            errorMessage = "Tous les acquittements doivent être cochés."
            return
        }
        let drawingBounds = canvas.drawing.bounds
        guard !drawingBounds.isEmpty else {
            errorMessage = "Veuillez signer avant de confirmer."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        // Capture signature en PNG
        let renderBounds = canvas.bounds.isEmpty ? drawingBounds : canvas.bounds
        let signatureUIImage = canvas.drawing.image(from: renderBounds, scale: 2.0)
        guard let signaturePNG = signatureUIImage.pngData() else {
            errorMessage = "Impossible de capturer la signature."
            return
        }
        let signatureB64 = signaturePNG.base64EncodedString()

        // Capture GPS (best effort)
        let coord = await location.requestOneShot()

        // Device info
        let device = UIDevice.current
        let deviceInfo: [String: String] = [
            "model": device.model,
            "system": "\(device.systemName) \(device.systemVersion)",
            "name": device.name,
        ]

        // Construit le PDF
        let pdfInput = ConsentPDFBuilder.Input(
            documentId: UUID().uuidString,
            nurseName: nurseName,
            clientName: clientName,
            formulationName: standingOrder.formulationName,
            consentText: consentText,
            checkpoints: checkpoints,
            signatureImage: signatureUIImage,
            signedAt: Date(),
            latitude: coord?.latitude,
            longitude: coord?.longitude,
            deviceInfo: deviceInfo
        )
        let pdfData = ConsentPDFBuilder.build(pdfInput)
        let pdfB64 = pdfData.base64EncodedString()

        let body = CreateConsentRequest(
            sessionId: session.id,
            standingOrderId: standingOrder.id,
            checkpoints: checkpoints,
            signatureImageB64: signatureB64,
            pdfB64: pdfB64,
            signedLatitude: coord?.latitude,
            signedLongitude: coord?.longitude,
            deviceInfo: deviceInfo
        )

        do {
            _ = try await api.createConsent(body)
            justSubmitted = true
        } catch {
            errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
        }
    }
}
