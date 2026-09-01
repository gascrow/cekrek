import Foundation

protocol GestureStateMachineDelegate: AnyObject {
    func gestureStateMachine(_ stateMachine: GestureStateMachine, didTriggerAction action: GestureAction)
    func gestureStateMachine(_ stateMachine: GestureStateMachine, didUpdateState state: GestureState)
    func gestureStateMachine(_ stateMachine: GestureStateMachine, didDetectWeakGesture gesture: GestureType, confidence: Float)
}

final class GestureStateMachine {
    weak var delegate: GestureStateMachineDelegate?

    private(set) var currentState: GestureState = .idle {
        didSet {
            delegate?.gestureStateMachine(self, didUpdateState: currentState)
        }
    }

    private var holdTimer: Timer?
    private var cooldownTimer: Timer?
    private var holdProgress: Double = 0

    private let holdDuration: Double
    private let cooldownDuration: TimeInterval
    private let confidenceThreshold: Float
    private let weakConfidenceThreshold: Float

    init(
        holdDuration: Double = 1.0,
        cooldownDuration: TimeInterval = 1.0,
        confidenceThreshold: Float = 0.75,
        weakConfidenceThreshold: Float = 0.5
    ) {
        self.holdDuration = holdDuration
        self.cooldownDuration = cooldownDuration
        self.confidenceThreshold = confidenceThreshold
        self.weakConfidenceThreshold = weakConfidenceThreshold
    }

    func processGesture(_ gesture: ClassifiedGesture?, mode: CaptureMode) {
        switch currentState {
        case .idle:
            handleIdle(gesture: gesture, mode: mode)
        case .holding:
            handleHolding(gesture: gesture, mode: mode)
        case .triggered:
            break
        case .cooldown:
            break
        }
    }

    func reset() {
        holdTimer?.invalidate()
        cooldownTimer?.invalidate()
        holdProgress = 0
        currentState = .idle
    }

    // MARK: - State Handlers

    private func handleIdle(gesture: ClassifiedGesture?, mode: CaptureMode) {
        guard let gesture else { return }

        if gesture.confidence >= confidenceThreshold {
            startHolding(gesture: gesture, mode: mode)
        } else if gesture.confidence >= weakConfidenceThreshold {
            delegate?.gestureStateMachine(self, didDetectWeakGesture: gesture.type, confidence: gesture.confidence)
        }
    }

    private func handleHolding(gesture: ClassifiedGesture?, mode: CaptureMode) {
        guard let gesture else {
            cancelHolding()
            return
        }

        if gesture.confidence < weakConfidenceThreshold {
            cancelHolding()
            return
        }
    }

    // MARK: - Hold Timer

    private func startHolding(gesture: ClassifiedGesture, mode: CaptureMode) {
        currentState = .holding(progress: 0)
        holdProgress = 0

        let interval: TimeInterval = 0.05
        holdTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            DispatchQueue.main.async {
                self.holdProgress += interval
                let progress = min(self.holdProgress / self.holdDuration, 1.0)
                self.currentState = .holding(progress: progress)

                if self.holdProgress >= self.holdDuration {
                    timer.invalidate()
                    self.triggerAction(gesture: gesture, mode: mode)
                }
            }
        }
    }

    private func cancelHolding() {
        holdTimer?.invalidate()
        holdTimer = nil
        holdProgress = 0
        currentState = .idle
    }

    // MARK: - Trigger & Cooldown

    private func triggerAction(gesture: ClassifiedGesture, mode: CaptureMode) {
        let action = gesture.type.action(for: mode)

        currentState = .triggered
        delegate?.gestureStateMachine(self, didTriggerAction: action)

        startCooldown()
    }

    private func startCooldown() {
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: cooldownDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentState = .idle
                self?.holdProgress = 0
            }
        }
    }
}
