import Foundation
import UIKit
import Vision

extension VNHumanHandPoseObservation {
    enum FingerTip: Int, CaseIterable {
        case thumbTip = 4
        case indexTip = 8
        case middleTip = 12
        case ringTip = 16
        case littleTip = 20
    }

    enum FingerIP: Int {
        case thumbIP = 3
        case indexDIP = 7
        case middleDIP = 11
        case ringDIP = 15
        case littleDIP = 19
    }

    enum FingerPIP: Int {
        case thumbMCP = 2
        case indexPIP = 6
        case middlePIP = 10
        case ringPIP = 14
        case littlePIP = 18
    }

    enum FingerMCP: Int {
        case thumbCMC = 1
        case indexMCP = 5
        case middleMCP = 9
        case ringMCP = 13
        case littleMCP = 17
    }

    enum WristPoint: Int {
        case wrist = 0
    }

    // Mengambil recognized point berdasarkan joint name resmi Vision
    func recognizedPoint(for jointName: VNHumanHandPoseObservation.JointName) -> VNRecognizedPoint? {
        try? recognizedPoint(jointName)
    }

    func pointCG(for jointName: VNHumanHandPoseObservation.JointName) -> CGPoint? {
        guard let point = recognizedPoint(for: jointName), point.confidence > 0.3 else {
            return nil
        }
        return CGPoint(x: point.location.x, y: point.location.y)
    }

    func allTipPoints() -> [CGPoint] {
        let tips: [VNHumanHandPoseObservation.JointName] = [
            .thumbTip, .indexTip, .middleTip, .ringTip, .littleTip
        ]
        return tips.compactMap { pointCG(for: $0) }
    }

    func wristPoint() -> CGPoint? {
        pointCG(for: .wrist)
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    func angle(to other: CGPoint) -> CGFloat {
        let dx = other.x - x
        let dy = other.y - y
        return atan2(dy, dx) * 180 / .pi
    }
}
