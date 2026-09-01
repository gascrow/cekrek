import Foundation

enum Constants {
    static let albumName = "AI Hands-Free"
    static let minStorageWarningMB = 500
    static let countdownDuration = 3
    static let cooldownDuration: TimeInterval = 1.0
    static let burstShotCount = 3
    static let burstShotInterval: TimeInterval = 0.4
    static let warningBeforeMaxDuration = 30
    static let aiFrameRate = 15
    static let maxRecordingDurationDefault = 600
    static let gestureGuideSize: CGFloat = 80

    enum GestureThreshold {
        static let fingerExtensionAngle: Double = 150
        static let fingerFoldAngle: Double = 60
        static let palmSizeMultiplier: Double = 0.3
        static let crossedHandsDistance: Double = 0.15
    }
}
