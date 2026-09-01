import AVFoundation
import SwiftUI
import Combine

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var cameraPermissionGranted = false
    @Published var microphonePermissionGranted = false
    @Published var showPermissionDenied = false
    @Published var showSettings = false
    @Published var countdownValue: Int = 0
    @Published var isCountdownActive = false
    @Published var showFlash = false
    @Published var statusMessage = ""
    @Published var hasError = false
    @Published var showErrorAlert = false
    @Published var errorMessage = ""

    @Published var detectedGesture: ClassifiedGesture?
    @Published var gestureState: GestureState = .idle
    @Published var weakGestureDetected: GestureType?
    @Published var holdProgress: Double = 0

    @Published var showRecoveryPrompt = false
    @Published var recoveredCount = 0

    let cameraManager = CameraSessionManager()
    let storageManager = StorageManager.shared
    let settingsStore = SettingsStore.shared
    let audioManager = AudioHapticManager.shared

    private var cancellables = Set<AnyCancellable>()
    private var thermalObservation: NSKeyValueObservation?

    init() {
        setupBindings()
        setupThermalMonitoring()
    }

    // MARK: - Setup

    func setup() {
        Task {
            await requestPermissions()
            await checkForRecoverableRecordings()
        }
    }

    private func setupBindings() {
        cameraManager.$lastError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleError(error)
            }
            .store(in: &cancellables)

        cameraManager.$recordingDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                guard let self else { return }
                let maxDuration = Double(self.settingsStore.maxRecordingDurationSeconds)
                let remaining = maxDuration - duration
                if remaining > 0 && remaining <= Double(Constants.warningBeforeMaxDuration) {
                    self.statusMessage = "Sisa waktu: \(Int(remaining)) detik"
                }
            }
            .store(in: &cancellables)

        cameraManager.$detectedGesture
            .receive(on: DispatchQueue.main)
            .sink { [weak self] gesture in
                self?.detectedGesture = gesture
            }
            .store(in: &cancellables)

        cameraManager.$gestureState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.gestureState = state
                if case .holding(let progress) = state {
                    self?.holdProgress = progress
                } else {
                    self?.holdProgress = 0
                }
            }
            .store(in: &cancellables)

        cameraManager.$weakGestureDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] gesture in
                self?.weakGestureDetected = gesture
            }
            .store(in: &cancellables)

        cameraManager.onRecordingSaved = { [weak self] url in
            Task { @MainActor in
                guard let self else { return }
                let success = await self.storageManager.saveVideo(at: url)
                if success {
                    self.statusMessage = "Video tersimpan ke album \(Constants.albumName)"
                    self.audioManager.playStopSound()
                } else {
                    self.handleError(.recordingFailed)
                }
            }
        }

        cameraManager.onGestureAction = { [weak self] action in
            Task { @MainActor in
                self?.handleGestureAction(action)
            }
        }

        NotificationCenter.default.publisher(for: .recordingWarning)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.statusMessage = "Peringatan: Sisa waktu 30 detik!"
                self?.audioManager.playBeepSound()
            }
            .store(in: &cancellables)
    }

    // MARK: - Thermal Monitoring

    private func setupThermalMonitoring() {
        thermalObservation = ProcessInfo.processInfo.observe(\.thermalState) { [weak self] processInfo, _ in
            Task { @MainActor in
                switch processInfo.thermalState {
                case .critical:
                    self?.handleError(.thermalCritical)
                case .serious:
                    self?.statusMessage = "Perangkat mulai panas, kurangi durasi rekaman"
                default:
                    break
                }
            }
        }
    }

    // MARK: - Crash Recovery

    private func checkForRecoverableRecordings() async {
        if CrashRecoveryManager.shared.hasRecoverableRecordings() {
            showRecoveryPrompt = true
        }
    }

    func recoverRecordings() async {
        let results = await CrashRecoveryManager.shared.recoverRecordings()
        let successCount = results.filter { $0.success }.count
        recoveredCount = successCount
        showRecoveryPrompt = false

        if successCount > 0 {
            statusMessage = "\(successCount) rekaman berhasil dipulihkan"
        } else {
            statusMessage = "Gagal memulihkan rekaman"
        }
    }

    func dismissRecovery() {
        CrashRecoveryManager.shared.clearAllCrashData()
        showRecoveryPrompt = false
    }

    // MARK: - Gesture Action Handler

    private func handleGestureAction(_ action: GestureAction) {
        guard !isCountdownActive else { return }

        switch action {
        case .startRecording:
            startRecording()
        case .stopRecording:
            stopRecording()
        case .switchCamera:
            switchCamera()
        case .deleteLastTake:
            deleteLastTake()
        case .singleCapture:
            capturePhoto()
        case .cancelCountdown:
            cancelCountdown()
        case .burstShot:
            captureBurst()
        case .none:
            break
        }
    }

    // MARK: - Permissions

    private func requestPermissions() async {
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        switch cameraStatus {
        case .authorized:
            cameraPermissionGranted = true
        case .notDetermined:
            cameraPermissionGranted = await AVCaptureDevice.requestAccess(for: .video)
        default:
            cameraPermissionGranted = false
            showPermissionDenied = true
            handleError(.cameraPermissionDenied)
            return
        }

        switch micStatus {
        case .authorized:
            microphonePermissionGranted = true
        case .notDetermined:
            microphonePermissionGranted = await AVCaptureDevice.requestAccess(for: .audio)
        default:
            microphonePermissionGranted = false
            showPermissionDenied = true
            handleError(.microphonePermissionDenied)
            return
        }

        if cameraPermissionGranted && microphonePermissionGranted {
            cameraManager.configureSession()
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Actions

    func switchCamera() {
        cameraManager.switchCamera()
        audioManager.playHapticLight()
    }

    func capturePhoto() {
        guard storageManager.hasEnoughStorage else {
            handleError(.lowStorage)
            return
        }

        startCountdown {
            Task { @MainActor in
                self.cameraManager.capturePhoto()
                self.audioManager.playShutterSound()
                self.showFlash = true

                try? await Task.sleep(nanoseconds: 100_000_000)
                self.showFlash = false

                let image = await self.takeSnapshot()
                if let image {
                    let success = await self.storageManager.savePhoto(image)
                    if success {
                        self.statusMessage = "Foto tersimpan ke album \(Constants.albumName)"
                    } else {
                        self.handleError(.captureFailed)
                    }
                }
            }
        }
    }

    func captureBurst() {
        guard storageManager.hasEnoughStorage else {
            handleError(.lowStorage)
            return
        }

        startCountdown {
            Task { @MainActor in
                self.cameraManager.captureBurstPhoto { images in
                    Task { @MainActor in
                        let success = await self.storageManager.saveBurstPhotos(images)
                        if success {
                            self.statusMessage = "\(images.count) foto tersimpan ke album \(Constants.albumName)"
                            self.audioManager.playShutterSound()
                        } else {
                            self.handleError(.captureFailed)
                        }
                    }
                }
                self.audioManager.playShutterSound()
                self.showFlash = true

                try? await Task.sleep(nanoseconds: 100_000_000)
                self.showFlash = false
            }
        }
    }

    func startRecording() {
        guard storageManager.hasEnoughStorage else {
            handleError(.lowStorage)
            return
        }

        startCountdown {
            Task { @MainActor in
                self.cameraManager.startRecording(maxDuration: Double(self.settingsStore.maxRecordingDurationSeconds))
                self.audioManager.playStartSound()
                self.statusMessage = "Merekam..."
            }
        }
    }

    func stopRecording() {
        cameraManager.stopRecording()
        statusMessage = "Menghentikan rekaman..."
    }

    func cancelCountdown() {
        isCountdownActive = false
        countdownValue = 0
        statusMessage = "Countdown dibatalkan"
    }

    func deleteLastTake() {
        statusMessage = "Hapus rekaman terakhir (fitur fase 2)"
    }

    // MARK: - Countdown

    private func startCountdown(completion: @escaping () -> Void) {
        guard !isCountdownActive else { return }

        isCountdownActive = true
        countdownValue = Constants.countdownDuration

        audioManager.playBeepSound()

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                if self.countdownValue > 1 {
                    self.countdownValue -= 1
                    self.audioManager.playBeepSound()
                } else {
                    timer.invalidate()
                    self.countdownValue = 0
                    self.isCountdownActive = false
                    completion()
                }
            }
        }
    }

    // MARK: - Snapshot

    private func takeSnapshot() async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let previewLayer = self.cameraManager.session.connections.first?.videoPreviewLayer else {
                    continuation.resume(returning: nil)
                    return
                }

                let bounds = previewLayer.bounds
                UIGraphicsBeginImageContextWithOptions(bounds.size, false, UIScreen.main.scale)
                defer { UIGraphicsEndImageContext() }

                guard let context = UIGraphicsGetCurrentContext() else {
                    continuation.resume(returning: nil)
                    return
                }

                context.translateBy(x: 0, y: bounds.height)
                context.scaleBy(x: 1, y: -1)
                previewLayer.render(in: context)

                let image = UIGraphicsGetImageFromCurrentImageContext()
                continuation.resume(returning: image)
            }
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: AppError) {
        hasError = true
        errorMessage = error.localizedDescription
        showErrorAlert = true
        statusMessage = error.localizedDescription

        switch error {
        case .cameraPermissionDenied, .microphonePermissionDenied, .photoLibraryPermissionDenied:
            showPermissionDenied = true
        case .thermalCritical:
            if cameraManager.isRecording {
                cameraManager.stopRecording()
            }
        case .lowStorage:
            if cameraManager.isRecording {
                cameraManager.stopRecording()
            }
        default:
            break
        }
    }
}
