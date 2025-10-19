import SwiftUI
import Combine
import AVFoundation
import Vision

struct ISBNScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scannerState = ScannerState()
    @State private var scannerError: ScannerError?

    let onISBNFound: (String) -> Void

    var body: some View {
        ZStack {
            CameraPreview(
                state: scannerState,
                onISBNFound: { isbn in
                    dismiss()
                    onISBNFound(isbn)
                },
                onError: { error in
                    scannerError = error
                }
            )
            .ignoresSafeArea()

            GeometryReader { geometry in
                ZStack {
                    ForEach(scannerState.overlayRects(in: geometry.size), id: \.self) { rect in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: 2)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .animation(.easeInOut(duration: 0.2), value: rect)
                    }
                }
            }
            .allowsHitTesting(false)

            VStack {
                Text("Align the barcode inside the frame")
                    .font(.headline)
                    .padding(.top, 60)
                    .padding(.horizontal)
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.top)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.bottom, 40)
            }
        }
        .alert(item: $scannerError) { error in
            Alert(
                title: Text("Scanning Unavailable"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK")) {
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Scanner State

private final class ScannerState: ObservableObject {
    @Published var observations: [VNBarcodeObservation] = []

    func overlayRects(in size: CGSize) -> [CGRect] {
        observations.map { observation in
            let boundingBox = observation.boundingBox
            // Vision coordinates are normalized with origin at bottom-left.
            let width = boundingBox.width * size.width
            let height = boundingBox.height * size.height
            let x = boundingBox.minX * size.width
            let y = (1 - boundingBox.maxY) * size.height
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }
}

// MARK: - Camera Preview

private struct CameraPreview: UIViewControllerRepresentable {
    @ObservedObject var state: ScannerState
    let onISBNFound: (String) -> Void
    let onError: (ScannerError) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        controller.onError = onError
        context.coordinator.configure(with: controller, state: state, onISBNFound: onISBNFound)
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
        private weak var controller: ScannerViewController?
        private weak var state: ScannerState?
        private var onISBNFound: ((String) -> Void)?
        private var isProcessingFrame = false
        private var hasEmittedISBN = false
        private lazy var request = VNDetectBarcodesRequest(completionHandler: handleDetections)

        private let requestQueue = DispatchQueue(label: "com.library.isbnscanner.vision")

        func configure(with controller: ScannerViewController, state: ScannerState, onISBNFound: @escaping (String) -> Void) {
            self.controller = controller
            self.state = state
            self.onISBNFound = onISBNFound
            request.symbologies = [.ean13, .ean8, .code128, .code39, .code39Checksum, .code93]
            controller.setSampleBufferDelegate(self)
        }

        func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard !isProcessingFrame else { return }
            isProcessingFrame = true

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                isProcessingFrame = false
                return
            }

            requestQueue.async { [weak self] in
                guard let self else { return }
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
                do {
                    try handler.perform([self.request])
                } catch {
                    DispatchQueue.main.async {
                        self.controller?.onError?(.visionError)
                    }
                }
                self.isProcessingFrame = false
            }
        }

        private func handleDetections(request: VNRequest, error: Error?) {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }

                if error != nil {
                    self.controller?.onError?(.visionError)
                    return
                }

                guard let observations = request.results as? [VNBarcodeObservation], !observations.isEmpty else {
                    self.state?.observations = []
                    return
                }

                self.state?.observations = observations

                guard !hasEmittedISBN else { return }

                if let match = observations.compactMap({ $0.payloadStringValue }).first(where: { self.isLikelyISBN($0) }) {
                    hasEmittedISBN = true
                    controller?.stopSession()
                    onISBNFound?(match)
                }
            }
        }

        private func isLikelyISBN(_ value: String) -> Bool {
            let cleaned = value.uppercased().filter { $0.isNumber || $0 == "X" }
            return cleaned.count == 10 || cleaned.count == 13
        }
    }
}

// MARK: - Scanner View Controller

private final class ScannerViewController: UIViewController {
    fileprivate var delegate: (any AVCaptureVideoDataOutputSampleBufferDelegate)?
    fileprivate var onError: ((ScannerError) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.library.isbnscanner.session")
    private let output = AVCaptureVideoDataOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        configurePreviewLayer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkCameraAuthorization()
    }

    func setSampleBufferDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        output.setSampleBufferDelegate(delegate, queue: DispatchQueue(label: "com.library.isbnscanner.capture"))
    }

    private func configurePreviewLayer() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
    }

    private func checkCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.configureSession()
                    } else {
                        self.onError?(.permissionDenied)
                    }
                }
            }
        case .denied, .restricted:
            onError?(.permissionDenied)
        @unknown default:
            onError?(.permissionDenied)
        }
    }

    private func configureSession() {
        sessionQueue.async {
            do {
                self.session.beginConfiguration()
                self.session.sessionPreset = .high

                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                    throw ScannerError.cameraUnavailable
                }

                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }

                self.output.alwaysDiscardsLateVideoFrames = true
                if self.session.canAddOutput(self.output) {
                    self.session.addOutput(self.output)
                }

                self.output.connection(with: .video)?.videoOrientation = .portrait
                self.session.commitConfiguration()
                self.startSession()
            } catch let error as ScannerError {
                DispatchQueue.main.async {
                    self.onError?(error)
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError?(.configurationFailed)
                }
            }
        }
    }

    private func startSession() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    fileprivate func stopSession() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
}

// MARK: - Errors

private enum ScannerError: LocalizedError, Identifiable {
    case permissionDenied
    case cameraUnavailable
    case configurationFailed
    case visionError

    var id: Int {
        hashValue
    }

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera access is required to scan ISBN barcodes. You can enable camera access in Settings."
        case .cameraUnavailable:
            return "The camera is not available on this device."
        case .configurationFailed:
            return "We couldn't set up the camera session."
        case .visionError:
            return "We couldn't process the camera feed. Please try again."
        }
    }
}
