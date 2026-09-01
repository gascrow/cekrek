import AVFoundation
import Combine
import UIKit

final class AudioHapticManager {
    static let shared = AudioHapticManager()

    private var audioPlayer: AVAudioPlayer?
    private let hapticEngine = UIImpactFeedbackGenerator(style: .medium)

    private init() {
        hapticEngine.prepare()
    }

    // MARK: - Haptic

    func playHaptic() {
        hapticEngine.impactOccurred()
    }

    func playHapticLight() {
        let lightGenerator = UIImpactFeedbackGenerator(style: .light)
        lightGenerator.impactOccurred()
    }

    func playNotificationHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    // MARK: - Sound

    func playShutterSound() {
        playSystemSound(id: 1108)
    }

    func playBeepSound() {
        playSystemSound(id: 1000)
    }

    func playStartSound() {
        playSystemSound(id: 1057)
    }

    func playStopSound() {
        playSystemSound(id: 1054)
    }

    private func playSystemSound(id: UInt32) {
        AudioServicesPlaySystemSound(id)
    }
}
