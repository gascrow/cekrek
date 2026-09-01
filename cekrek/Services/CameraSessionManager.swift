import AVFoundation
import UIKit
import Combine

final class CameraSessionManager: NSObject, ObservableObject {
    @Published var isSessionRunning = false
    @Published var isRecording = false
    @Published var currentCameraPosition: AVCaptureDevice.Position = .back
    @Published var recordingDuration: TimeInterval = 0
    @Published var lastError: AppError?

    @Published var detectedGesture: ClassifiedGesture?
    @Published var gestureState: GestureState = .idle
    @Published var weakGestureDetected: GestureType?

    let session = AVCaptureSession()
    private var videoInput: AVCaptureDeviceInput?
    private var photoOutput = AVCapturePhotoOutput()
    private var movieOutput = AVCaptureMovieFileOutput()
    private var videoDataOutput = AVCaptureVideoDataOutput()

    let handPoseDetector = HandPoseDetector()
    let gestureClassifier = GestureClassifier()
    lazy var gestureStateMachine: GestureStateMachine = GestureStateMachine()

    private var recordingTimer: Timer?
    private var tempRecordingURL: URL?
    private var maxRecordingDuration: TimeInterval = 600

    private var lastFrameTime: CMTime = .zero
    private let frameInterval = CMTime(value: 1, timescale: Int32(Constants.aiFrameRate))

    var onRecordingSaved: ((URL) -> Void)?
    var onFrameCaptured: ((CMSampleBuffer) -> Void)?
    var onGestureAction: ((GestureAction) -> Void)?

    private let sessionQueue = DispatchQueue(label: "com.cekrek.camera.session")
    private let videoOutputQueue = DispatchQueue(label: "com.cekrek.camera.videoOutput", qos: .userInitiated)

    override init() {
        super.init()
        tempRecordingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cekrek_temp_\(UUID().uuidString).mp4")
        gestureStateMachine.delegate = self
    }

    // MARK: - Session Setup

    func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()

            if self.session.canSetSessionPreset(.high) {
                self.session.sessionPreset = .high
            }

            self.setupCamera()
            self.setupOutputs()

            self.session.commitConfiguration()
            self.session.startRunning()

            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }

    private func setupCamera() {
        if let existingInput = videoInput {
            session.removeInput(existingInput)
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
            videoInput = input
        }
    }

    private func setupOutputs() {
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }

        videoOutputQueue.async { [weak self] in
            guard let self else { return }
            self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoOutputQueue)
            self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
        }

        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
    }

    func updateGestureSettings(holdDuration: Double, confidenceThreshold: Float) {
        gestureStateMachine = GestureStateMachine(
            holdDuration: holdDuration,
            confidenceThreshold: confidenceThreshold
        )
        gestureStateMachine.delegate = self
    }

    // MARK: - Camera Switching

    func switchCamera() {
        guard !isRecording else {
            DispatchQueue.main.async {
                self.lastError = .cameraSwitchDuringRecording
            }
            return
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }

            let newPosition: AVCaptureDevice.Position = self.currentCameraPosition == .back ? .front : .back

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                return
            }

            self.session.beginConfiguration()

            if let existingInput = self.videoInput {
                self.session.removeInput(existingInput)
            }

            if self.session.canAddInput(input) {
                self.session.addInput(input)
                self.videoInput = input
            } else {
                if let oldInput = self.videoInput {
                    self.session.addInput(oldInput)
                }
            }

            self.session.commitConfiguration()

            DispatchQueue.main.async {
                self.currentCameraPosition = newPosition
            }
        }
    }

    // MARK: - Photo Capture

    func capturePhoto() {
        guard !isRecording else { return }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        settings.isHighResolutionPhotoEnabled = true

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func captureBurstPhoto(completion: @escaping ([UIImage]) -> Void) {
        guard !isRecording else { return }

        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true

        var capturedImages: [UIImage] = []
        let burstCount = Constants.burstShotCount

        photoOutput.capturePhoto(with: settings, delegate: BurstPhotoCaptureDelegate { image in
            if let image {
                capturedImages.append(image)
            }
            if capturedImages.count >= burstCount {
                completion(capturedImages)
            }
        })
    }

    // MARK: - Video Recording

    func startRecording(maxDuration: TimeInterval = 600) {
        guard !isRecording else { return }

        maxRecordingDuration = maxDuration
        recordingDuration = 0

        let outputURL = tempRecordingURL ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("cekrek_temp_\(UUID().uuidString).mp4")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        CrashRecoveryManager.shared.saveRecordingInProgress(url: outputURL)

        movieOutput.startRecording(to: outputURL, recordingDelegate: self)

        DispatchQueue.main.async {
            self.isRecording = true
        }

        startRecordingTimer()
    }

    func stopRecording() {
        guard isRecording else { return }

        stopRecordingTimer()
        movieOutput.stopRecording()

        if let url = tempRecordingURL {
            CrashRecoveryManager.shared.removeRecordingInProgress(url: url)
        }

        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    private func startRecordingTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.recordingDuration += 1

                if self.recordingDuration >= self.maxRecordingDuration - Double(Constants.warningBeforeMaxDuration) {
                    NotificationCenter.default.post(name: .recordingWarning, object: nil)
                }

                if self.recordingDuration >= self.maxRecordingDuration {
                    self.stopRecording()
                }
            }
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    func setVideoFrameRateDelegate(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate?) {
        videoOutputQueue.async { [weak self] in
            self?.videoDataOutput.setSampleBufferDelegate(delegate, queue: self?.videoOutputQueue)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraSessionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        let elapsed = CMTimeSubtract(currentTime, lastFrameTime)
        guard CMTimeCompare(elapsed, frameInterval) >= 0 else { return }
        lastFrameTime = currentTime

        let results = handPoseDetector.detectHandPose(from: sampleBuffer)

        let primary = results.first
        let secondary = results.count > 1 ? results[1] : nil

        var classified: ClassifiedGesture?
        if let primary {
            classified = gestureClassifier.classify(landmarks: primary, secondLandmarks: secondary)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.detectedGesture = classified
            if let classified {
                self.gestureStateMachine.processGesture(classified, mode: SettingsStore.shared.activeMode)
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraSessionManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async {
                self.lastError = .captureFailed
            }
            return
        }

        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}

// MARK: - AVCaptureFileRecordingDelegate

extension CameraSessionManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error {
            print("Recording error: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.lastError = .recordingFailed
            }
            return
        }

        DispatchQueue.main.async {
            self.onRecordingSaved?(outputFileURL)
        }
    }

    func fileOutputBeganRecording(_ outputFileURL: URL, from connections: [AVCaptureConnection]) {
        print("Recording started: \(outputFileURL)")
    }
}

// MARK: - Burst Photo Delegate

private class BurstPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let onCapture: (UIImage?) -> Void

    init(onCapture: @escaping (UIImage?) -> Void) {
        self.onCapture = onCapture
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let data = photo.fileDataRepresentation(),
           let image = UIImage(data: data) {
            onCapture(image)
        } else {
            onCapture(nil)
        }
    }
}

// MARK: - GestureStateMachineDelegate

extension CameraSessionManager: GestureStateMachineDelegate {
    func gestureStateMachine(_ stateMachine: GestureStateMachine, didTriggerAction action: GestureAction) {
        DispatchQueue.main.async { [weak self] in
            self?.onGestureAction?(action)
        }
    }

    func gestureStateMachine(_ stateMachine: GestureStateMachine, didUpdateState state: GestureState) {
        DispatchQueue.main.async { [weak self] in
            self?.gestureState = state
        }
    }

    func gestureStateMachine(_ stateMachine: GestureStateMachine, didDetectWeakGesture gesture: GestureType, confidence: Float) {
        DispatchQueue.main.async { [weak self] in
            self?.weakGestureDetected = gesture
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.weakGestureDetected = nil
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let recordingWarning = Notification.Name("recordingWarning")
}
