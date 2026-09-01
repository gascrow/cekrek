import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            cameraPreview

            VStack {
                topBar
                Spacer()
                gestureStatusOverlay
                bottomBar
            }

            if viewModel.isCountdownActive {
                countdownOverlay
            }

            if viewModel.showFlash {
                flashOverlay
            }

            if viewModel.showPermissionDenied {
                permissionDeniedOverlay
            }

            if let weakGesture = viewModel.weakGestureDetected {
                weakGestureBanner(gesture: weakGesture)
            }

            if viewModel.cameraManager.isRecording {
                recordingIndicator
            }
        }
        .onAppear {
            viewModel.setup()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && viewModel.cameraManager.isRecording {
                viewModel.statusMessage = "Rekaman berlanjut di background..."
            }
        }
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK") { }
            Button("Buka Pengaturan") {
                viewModel.openSettings()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Rekaman Ditemukan", isPresented: $viewModel.showRecoveryPrompt) {
            Button("Pulihkan") {
                Task {
                    await viewModel.recoverRecordings()
                }
            }
            Button("Hapus", role: .destructive) {
                viewModel.dismissRecovery()
            }
        } message: {
            Text("Ditemukan rekaman yang belum tersimpan dari sesi sebelumnya. Apakah Anda ingin memulihkannya?")
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(settingsStore: viewModel.settingsStore)
        }
    }

    // MARK: - Camera Preview

    private var cameraPreview: some View {
        CameraPreviewView(session: viewModel.cameraManager.session)
            .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            modeToggle

            Spacer()

            if !viewModel.statusMessage.isEmpty {
                statusBadge
            }

            Spacer()

            settingsButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(CaptureMode.allCases, id: \.rawValue) { mode in
                Button {
                    viewModel.settingsStore.activeMode = mode
                } label: {
                    Text(mode.displayName)
                        .font(.system(.subheadline, weight: .heavy))
                        .foregroundStyle(viewModel.settingsStore.activeMode == mode ? .white : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.settingsStore.activeMode == mode
                            ? Color(viewModel.settingsStore.activeMode == .video ? "videoAccent" : "photoAccent")
                            : Color.clear
                        )
                }
            }
        }
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
    }

    private var statusBadge: some View {
        Text(viewModel.statusMessage)
            .font(.system(.caption, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.7))
            .clipShape(Capsule())
    }

    private var settingsButton: some View {
        Button {
            viewModel.showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }

    // MARK: - Recording Indicator

    private var recordingIndicator: some View {
        VStack {
            HStack {
                Circle()
                    .fill(.red)
                    .frame(width: 12, height: 12)
                    .opacity(recordingBlink ? 1 : 0.3)

                Text("REC \(formatDuration(viewModel.cameraManager.recordingDuration))")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.7))
            .clipShape(Capsule())

            Spacer()
        }
        .padding(.top, 60)
    }

    @State private var recordingBlink = true

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Gesture Status Overlay

    private var gestureStatusOverlay: some View {
        VStack(spacing: 12) {
            if case .holding(let progress) = viewModel.gestureState {
                holdProgressBar(progress: progress)
            }

            HStack(spacing: 8) {
                Image(systemName: gestureStateIcon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(gestureStateColor)

                Text(viewModel.gestureState.displayName)
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.7))
            .clipShape(Capsule())
        }
    }

    private func holdProgressBar(progress: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.yellow)
                    .frame(width: geometry.size.width * progress, height: 8)
                    .animation(.linear(duration: 0.05), value: progress)
            }
        }
        .frame(width: 120, height: 8)
    }

    private var gestureStateIcon: String {
        switch viewModel.gestureState {
        case .idle: return "hand.raised.fill"
        case .holding: return "hand.raised.fist.fill"
        case .triggered: return "bolt.fill"
        case .cooldown: return "clock.fill"
        }
    }

    private var gestureStateColor: Color {
        switch viewModel.gestureState {
        case .idle: return .gray
        case .holding: return .yellow
        case .triggered: return .green
        case .cooldown: return .orange
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 40) {
            gestureGuideView

            captureButton

            cameraSwitchButton
        }
        .padding(.bottom, 40)
    }

    private var gestureGuideView: some View {
        VStack(spacing: 4) {
            if let gesture = viewModel.detectedGesture {
                Image(systemName: gestureIconName(for: gesture.type))
                    .font(.system(size: 28))
                    .foregroundStyle(Double(gesture.confidence) >= viewModel.settingsStore.confidenceThreshold ? .green : .yellow)
                    .scaleEffect(Double(gesture.confidence) >= viewModel.settingsStore.confidenceThreshold ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: gesture.confidence)
            } else {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.gray)
            }

            Text("Gestur")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.gray)
        }
        .frame(width: 60, height: 60)
    }

    private func gestureIconName(for gesture: GestureType) -> String {
        switch gesture {
        case .openPalm: return "hand.raised.fill"
        case .closedFist: return "hand.raised.fist.fill"
        case .peaceSign: return "hand.thumbsup.fill"
        case .crossedHands: return "xmark.circle.fill"
        }
    }

    private var captureButton: some View {
        Button {
            performCapture()
        } label: {
            ZStack {
                Circle()
                    .stroke(.white, lineWidth: 4)
                    .frame(width: 72, height: 72)

                if viewModel.cameraManager.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.red)
                        .frame(width: 28, height: 28)
                } else if viewModel.settingsStore.activeMode == .video {
                    Circle()
                        .fill(.red)
                        .frame(width: 56, height: 56)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 56, height: 56)
                }
            }
        }
    }

    private var cameraSwitchButton: some View {
        Button {
            viewModel.switchCamera()
        } label: {
            Image(systemName: "camera.rotate.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
    }

    // MARK: - Weak Gesture Banner

    private func weakGestureBanner(gesture: GestureType) -> some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text("Gestur terdeteksi lemah: \(gesture.displayName)")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.8))
            .clipShape(Capsule())

            Spacer()
        }
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: viewModel.weakGestureDetected)
    }

    // MARK: - Actions

    private func performCapture() {
        if viewModel.cameraManager.isRecording {
            viewModel.stopRecording()
            return
        }

        switch viewModel.settingsStore.activeMode {
        case .video:
            viewModel.startRecording()
        case .photo:
            viewModel.capturePhoto()
        }
    }

    // MARK: - Overlays

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            Text("\(viewModel.countdownValue)")
                .font(.system(size: 120, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 10)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: viewModel.countdownValue)
        }
    }

    private var flashOverlay: some View {
        Color.white
            .ignoresSafeArea()
            .transition(.opacity)
            .animation(.easeOut(duration: 0.1), value: viewModel.showFlash)
    }

    private var permissionDeniedOverlay: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.red)

                Text("Izin Diperlukan")
                    .font(.system(.title, weight: .black))

                Text("Aplikasi memerlukan akses ke kamera dan mikrofon untuk berfungsi.")
                    .font(.system(.body))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    viewModel.openSettings()
                } label: {
                    Text("Buka Pengaturan")
                        .font(.system(.headline, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - Camera Preview UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

class PreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

// MARK: - Preview

#Preview {
    CameraView()
}
