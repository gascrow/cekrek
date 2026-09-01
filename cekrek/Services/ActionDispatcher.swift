import Foundation

protocol ActionDispatcherDelegate: AnyObject {
    func actionDispatcher(_ dispatcher: ActionDispatcher, didRequestAction action: GestureAction)
    func actionDispatcher(_ dispatcher: ActionDispatcher, didFailWith error: AppError)
}

final class ActionDispatcher {
    weak var delegate: ActionDispatcherDelegate?

    private let storageManager: StorageManager
    private let settingsStore: SettingsStore

    init(storageManager: StorageManager = .shared, settingsStore: SettingsStore = .shared) {
        self.storageManager = storageManager
        self.settingsStore = settingsStore
    }

    func dispatch(action: GestureAction, mode: CaptureMode) {
        guard validatePreconditions(for: action) else { return }

        switch action {
        case .startRecording:
            delegate?.actionDispatcher(self, didRequestAction: .startRecording)
        case .stopRecording:
            delegate?.actionDispatcher(self, didRequestAction: .stopRecording)
        case .switchCamera:
            delegate?.actionDispatcher(self, didRequestAction: .switchCamera)
        case .deleteLastTake:
            delegate?.actionDispatcher(self, didRequestAction: .deleteLastTake)
        case .singleCapture:
            delegate?.actionDispatcher(self, didRequestAction: .singleCapture)
        case .cancelCountdown:
            delegate?.actionDispatcher(self, didRequestAction: .cancelCountdown)
        case .burstShot:
            delegate?.actionDispatcher(self, didRequestAction: .burstShot)
        case .none:
            break
        }
    }

    private func validatePreconditions(for action: GestureAction) -> Bool {
        switch action {
        case .startRecording, .singleCapture, .burstShot:
            guard storageManager.hasEnoughStorage else {
                delegate?.actionDispatcher(self, didFailWith: .lowStorage)
                return false
            }
            return true
        default:
            return true
        }
    }

    func customAction(for gesture: GestureType, in mode: CaptureMode) -> GestureAction {
        settingsStore.customAction(for: gesture, in: mode)
    }
}
