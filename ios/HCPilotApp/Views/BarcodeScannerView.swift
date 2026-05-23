import SwiftUI
import AVFoundation

/// Scanner code-barres en plein écran via AVFoundation natif (no ML Kit dep).
/// Détecte EAN-13, EAN-8, UPC-E, Code 128, QR codes — couvre 99% des produits
/// pharma. Fallback "Saisie manuelle" pour le simulateur (pas de caméra).
struct BarcodeScannerView: View {
    var onDetected: (String) -> Void
    var onCancel: () -> Void

    @State private var manualInput = ""
    @State private var showManualSheet = false
    @State private var cameraAuthorized: Bool? = nil

    var body: some View {
        ZStack {
            if cameraAuthorized == true {
                CameraScanner(onDetected: { code in
                    onDetected(code)
                })
                .ignoresSafeArea()

                // Overlay : cadre de détection + boutons
                VStack {
                    HStack {
                        Button(action: onCancel) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .background(Circle().fill(.black.opacity(0.4)))
                        }
                        Spacer()
                        Button {
                            showManualSheet = true
                        } label: {
                            Label("Saisie manuelle", systemImage: "keyboard")
                                .font(.caption)
                                .padding(8)
                                .background(.regularMaterial)
                                .clipShape(Capsule())
                        }
                    }
                    .padding()
                    Spacer()
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white, lineWidth: 3)
                        .frame(width: 280, height: 160)
                        .shadow(color: .black.opacity(0.4), radius: 8)
                    Spacer()
                    Text("Centrez le code-barres du flacon dans le cadre")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                        .padding(.bottom, 40)
                }
            } else if cameraAuthorized == false {
                cameraDeniedView
            } else {
                ProgressView()
            }
        }
        .task { await checkPermission() }
        .sheet(isPresented: $showManualSheet) {
            manualEntrySheet
        }
    }

    private var cameraDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("Caméra indisponible")
                .font(.title2).fontWeight(.semibold)
            Text("Le simulateur n'a pas de caméra, ou l'autorisation a été refusée. Utilisez la saisie manuelle.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showManualSheet = true
            } label: {
                Label("Saisie manuelle", systemImage: "keyboard")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .accessibilityIdentifier("scanner.openManual")
            Button("Annuler") { onCancel() }
                .padding(.top, 4)
                .accessibilityIdentifier("scanner.cancel")
        }
    }

    private var manualEntrySheet: some View {
        NavigationView {
            Form {
                Section {
                    // Audit H-78 : keyboardType .asciiCapable accepte les
                    // chiffres ET les lettres (Code 128 / 39 peuvent inclure
                    // des caractères alphanum).
                    TextField("Saisissez le code-barres", text: $manualInput)
                        .keyboardType(.asciiCapable)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                        .accessibilityIdentifier("scanner.manual.input")
                } header: {
                    Text("Code-barres")
                } footer: {
                    Text("EAN-13 (13 chiffres), Code 128 (alphanumérique), etc.")
                        .font(.caption2)
                }
            }
            .navigationTitle("Saisie manuelle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showManualSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") {
                        showManualSheet = false
                        onDetected(manualInput)
                    }
                    .disabled(manualInput.isEmpty)
                    .accessibilityIdentifier("scanner.manual.validate")
                }
            }
        }
    }

    private func checkPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraAuthorized = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraAuthorized = granted
        default:
            cameraAuthorized = false
        }
    }
}

// MARK: - AVFoundation wrapper

private struct CameraScanner: UIViewControllerRepresentable {
    let onDetected: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onDetected = { code in
            DispatchQueue.main.async { onDetected(code) }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}
}

private final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onDetected: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var hasReported = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) { session.addOutput(output) }
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [
            .ean13, .ean8, .upce, .code128, .code39, .code93,
            .qr, .pdf417, .dataMatrix,
        ]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasReported,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        hasReported = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        onDetected?(value)
    }
}
