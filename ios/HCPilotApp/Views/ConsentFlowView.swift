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
    @State private var showCancelConfirm = false

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
                    .accessibilityIdentifier("consent.progress")

                // Fork A Lot 1 / UI-T1 : switch au lieu de TabView(.page).
                Group {
                    switch vm.step {
                    case 0: FormulationStep(vm: vm)
                    case 1: ConsentTextStep(vm: vm)
                    case 2: CheckpointsStep(vm: vm)
                    default: SignatureStep(vm: vm)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.25), value: vm.step)
            }
            .navigationTitle("Consentement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        // Audit H-51 : confirm si au-delà de l'étape 0 OU si
                        // une signature a déjà été posée. La perte d'une
                        // signature client est inacceptable.
                        if vm.step > 0 {
                            showCancelConfirm = true
                        } else {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("consent.close")
                }
            }
            .task {
                await vm.loadFormulations()
            }
            // Fork A Lot 1 / UI-T2 : alert au lieu de confirmationDialog.
            .alert("Abandonner le consentement ?", isPresented: $showCancelConfirm) {
                Button("Abandonner", role: .destructive) { dismiss() }
                Button("Continuer", role: .cancel) {}
            } message: {
                Text("La signature et les acquittements seront perdus. Le client devra recommencer.")
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

            // Audit C-50 : empty state explicite si aucune SO active.
            // Sans cet écran, Maria (RN débutante) reste bloquée sur un
            // ProgressView infini si elle n'a pas encore configuré sa pratique.
            if vm.isLoadingStandingOrders {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                    .accessibilityIdentifier("consent.so.loading")
            } else if vm.standingOrders.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 44))
                        .foregroundStyle(.orange)
                    Text("Aucune standing order active")
                        .font(.headline)
                    Text("Vous devez avoir au moins une standing order signée par votre Medical Director pour recueillir un consentement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Text("Allez dans l'onglet Conformité pour en ajouter une, ou complétez votre configuration depuis Profil → Configuration de la pratique.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 24)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("consent.so.empty")
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
                            .accessibilityIdentifier("consent.so.\(so.id)")
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
                    .accessibilityIdentifier("consent.text.back")
                Spacer()
                Button("J'ai lu, continuer") { vm.step = 2 }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("consent.text.continue")
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
                    .accessibilityIdentifier("consent.checkpoint.\(i)")
                }
            }
            .padding(.horizontal)

            Spacer(minLength: 0)

            HStack {
                Button("Retour") { vm.step = 1 }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("consent.checkpoints.back")
                Spacer()
                Button("Continuer vers la signature") { vm.step = 3 }
                    .buttonStyle(.borderedProminent)
                    .disabled(!vm.allCheckpointsAccepted)
                    .accessibilityIdentifier("consent.checkpoints.continue")
            }
            .padding()
        }
        .padding(.top, 16)
    }
}

private struct SignatureStep: View {
    @ObservedObject var vm: ConsentFlowViewModel
    @State private var canvasView = PKCanvasView()
    /// UI-T3 : flag mis à true quand le bouton debug a injecté une signature.
    /// PKCanvasView est une class → muter `.drawing` ne déclenche pas un
    /// re-render SwiftUI. On utilise ce flag comme tripwire pour ré-évaluer
    /// `isSignatureUsable` côté disable du Confirm.
    @State private var debugSignatureInjected = false
    /// Tripwire user réel : bumpé par le delegate à chaque trait pour forcer
    /// SwiftUI à re-évaluer `.disabled` après que le client a signé au doigt.
    @State private var drawingTick = 0

    /// Fork A Lot 1 / UI-T3 : XCUI ne sait pas dessiner sur PKCanvasView.
    /// En présence du launch argument `-uitest`, on affiche un bouton de
    /// debug qui injecte une signature canned (ligne diagonale 200×50pt,
    /// valide pour `isSignatureUsable`).
    /// On évalue depuis ProcessInfo + environment pour robustesse.
    private var isUITest: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uitest") || args.contains("--uitest") { return true }
        if ProcessInfo.processInfo.environment["UITEST"] == "1" { return true }
        return false
    }

    /// Génère un PKDrawing avec un trait diagonal large (> 40×20pt) pour
    /// passer la validation `isSignatureUsable`.
    static func cannedSignature() -> PKDrawing {
        let stroke = PKStroke(
            ink: PKInk(.pen, color: .black),
            path: PKStrokePath(
                controlPoints: [
                    PKStrokePoint(location: CGPoint(x: 10, y: 10), timeOffset: 0, size: CGSize(width: 2, height: 2), opacity: 1, force: 1, azimuth: 0, altitude: 0),
                    PKStrokePoint(location: CGPoint(x: 220, y: 60), timeOffset: 0.1, size: CGSize(width: 2, height: 2), opacity: 1, force: 1, azimuth: 0, altitude: 0),
                ],
                creationDate: Date()
            )
        )
        return PKDrawing(strokes: [stroke])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Signature du client")
                .font(.headline)
                .padding(.horizontal)
            Text("Le client signe ci-dessous avec son doigt.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            SignaturePad(canvasView: $canvasView, drawingTick: $drawingTick)
                .frame(height: 220)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal)
                .accessibilityIdentifier("consent.signature.canvas")

            HStack {
                Button("Effacer") {
                    canvasView.drawing = PKDrawing()
                    drawingTick &+= 1
                    debugSignatureInjected = false
                }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("consent.signature.clear")
                Spacer()
                if vm.isSubmitting {
                    ProgressView()
                } else {
                    Button("Confirmer la signature") {
                        Task { await vm.submit(canvas: canvasView) }
                    }
                    .buttonStyle(.borderedProminent)
                    // Audit H-55 : exiger une signature de taille minimale
                    // pour éviter qu'un point microscopique soit accepté.
                    // 40×20 pt = au moins un trait court (5-6 caractères de
                    // signature, ou un paraphe).
                    .disabled({ _ = drawingTick; return !isSignatureUsable(canvasView.drawing) && !debugSignatureInjected }())
                    .accessibilityIdentifier("consent.signature.confirm")
                }
            }
            .padding(.horizontal)

            // UI-T3 : bouton debug uniquement en run XCUI.
            if isUITest {
                Button("⚙️ Signature de test (debug XCUI)") {
                    canvasView.drawing = Self.cannedSignature()
                    debugSignatureInjected = true
                }
                .font(.caption)
                .padding(.horizontal)
                .accessibilityIdentifier("consent.signature.debugFill")
            }

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
    @Binding var drawingTick: Int

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(tick: $drawingTick) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let tick: Binding<Int>
        init(tick: Binding<Int>) { self.tick = tick }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            tick.wrappedValue &+= 1
        }
    }
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

/// Audit H-55 : valide qu'une signature couvre au moins ~40×20pt (équivalent
/// d'un trait de paraphe court). Refuse les "signatures fantômes" d'1 point.
func isSignatureUsable(_ drawing: PKDrawing) -> Bool {
    let b = drawing.bounds
    return b.width >= 40 && b.height >= 20
}

@MainActor
final class ConsentFlowViewModel: ObservableObject {
    @Published var step: Int = 0
    @Published var standingOrders: [StandingOrderInfo] = []
    @Published var isLoadingStandingOrders = true
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
        isLoadingStandingOrders = true
        defer { isLoadingStandingOrders = false }
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
        // Audit H-55 : exige une signature lisible.
        guard isSignatureUsable(canvas.drawing) else {
            errorMessage = "La signature est trop petite. Demandez au client de signer plus largement."
            return
        }
        let drawingBounds = canvas.drawing.bounds

        isSubmitting = true
        defer { isSubmitting = false }

        // Capture signature en PNG — on cadre sur le drawing lui-même (avec un
        // petit padding pour ne pas couper les traits) plutôt que sur canvas.bounds.
        // Sinon le tracé (~40×20pt) noyé dans un canvas 363×220 devient un
        // micropoint illisible une fois le PDF réduit à 165×100pt.
        let renderBounds = drawingBounds.insetBy(dx: -8, dy: -8)
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
            ipAddress: NetworkInfo.currentIPAddress(),
            standingOrderVersion: standingOrder.version,
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
