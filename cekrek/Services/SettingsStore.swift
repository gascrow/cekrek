import Foundation
import Combine

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let gestureHoldDuration = "gestureHoldDuration"
        static let activeMode = "activeMode"
        static let confidenceThreshold = "confidenceThreshold"
        static let maxRecordingDurationSeconds = "maxRecordingDurationSeconds"
        static let preferredResolution = "preferredResolution"
        static let hapticFeedbackEnabled = "hapticFeedbackEnabled"
        static let soundEffectsEnabled = "soundEffectsEnabled"
        static let customGestureMapping = "customGestureMapping"
    }

    @Published var gestureHoldDuration: Double {
        didSet { defaults.set(gestureHoldDuration, forKey: Keys.gestureHoldDuration) }
    }

    @Published var activeMode: CaptureMode {
        didSet { defaults.set(activeMode.rawValue, forKey: Keys.activeMode) }
    }

    @Published var confidenceThreshold: Double {
        didSet { defaults.set(confidenceThreshold, forKey: Keys.confidenceThreshold) }
    }

    @Published var maxRecordingDurationSeconds: Int {
        didSet { defaults.set(maxRecordingDurationSeconds, forKey: Keys.maxRecordingDurationSeconds) }
    }

    @Published var preferredResolution: String {
        didSet { defaults.set(preferredResolution, forKey: Keys.preferredResolution) }
    }

    @Published var hapticFeedbackEnabled: Bool {
        didSet { defaults.set(hapticFeedbackEnabled, forKey: Keys.hapticFeedbackEnabled) }
    }

    @Published var soundEffectsEnabled: Bool {
        didSet { defaults.set(soundEffectsEnabled, forKey: Keys.soundEffectsEnabled) }
    }

    @Published var customGestureMapping: [String: String] {
        didSet {
            if let data = try? JSONSerialization.data(withJSONObject: customGestureMapping) {
                defaults.set(data, forKey: Keys.customGestureMapping)
            }
        }
    }

    private init() {
        self.gestureHoldDuration = defaults.double(forKey: Keys.gestureHoldDuration)
        self.confidenceThreshold = defaults.double(forKey: Keys.confidenceThreshold)
        self.maxRecordingDurationSeconds = defaults.integer(forKey: Keys.maxRecordingDurationSeconds)
        self.preferredResolution = defaults.string(forKey: Keys.preferredResolution) ?? "4K_30"
        self.hapticFeedbackEnabled = defaults.object(forKey: Keys.hapticFeedbackEnabled) as? Bool ?? true
        self.soundEffectsEnabled = defaults.object(forKey: Keys.soundEffectsEnabled) as? Bool ?? true

        if let modeRaw = defaults.string(forKey: Keys.activeMode),
           let mode = CaptureMode(rawValue: modeRaw) {
            self.activeMode = mode
        } else {
            self.activeMode = .video
        }

        if let data = defaults.data(forKey: Keys.customGestureMapping),
           let mapping = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            self.customGestureMapping = mapping
        } else {
            self.customGestureMapping = [
                GestureType.openPalm.rawValue: GestureAction.startRecording.rawValue,
                GestureType.closedFist.rawValue: GestureAction.stopRecording.rawValue,
                GestureType.peaceSign.rawValue: GestureAction.switchCamera.rawValue,
                GestureType.crossedHands.rawValue: GestureAction.deleteLastTake.rawValue
            ]
        }

        if defaults.double(forKey: Keys.gestureHoldDuration) == 0 {
            self.gestureHoldDuration = 1.0
        }
        if defaults.double(forKey: Keys.confidenceThreshold) == 0 {
            self.confidenceThreshold = 0.75
        }
        if defaults.integer(forKey: Keys.maxRecordingDurationSeconds) == 0 {
            self.maxRecordingDurationSeconds = 600
        }
    }

    func gestureAction(for gesture: GestureType) -> GestureAction {
        gesture.action(for: activeMode)
    }

    func customAction(for gesture: GestureType, in mode: CaptureMode) -> GestureAction {
        let key = "\(gesture.rawValue)_\(mode.rawValue)"
        if let actionRaw = customGestureMapping[key],
           let action = GestureAction(rawValue: actionRaw) {
            return action
        }
        return gesture.action(for: mode)
    }

    func setCustomAction(_ action: GestureAction, for gesture: GestureType, in mode: CaptureMode) {
        let key = "\(gesture.rawValue)_\(mode.rawValue)"
        customGestureMapping[key] = action.rawValue
    }
}
