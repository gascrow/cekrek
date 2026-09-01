import Vision
import AVFoundation

struct HandLandmarkResult {
    let wrist: CGPoint?
    let thumbTip: CGPoint?
    let indexTip: CGPoint?
    let middleTip: CGPoint?
    let ringTip: CGPoint?
    let littleTip: CGPoint?
    let indexPIP: CGPoint?
    let middlePIP: CGPoint?
    let ringPIP: CGPoint?
    let littlePIP: CGPoint?
    let indexMCP: CGPoint?
    let middleMCP: CGPoint?
    let ringMCP: CGPoint?
    let littleMCP: CGPoint?
    let thumbCMC: CGPoint?
    let boundingBox: CGRect
    let confidence: Float
}

final class HandPoseDetector {
    private let request: VNDetectHumanHandPoseRequest

    init() {
        request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        request.revision = VNDetectHumanHandPoseRequestRevision1
    }

    func detectHandPose(from sampleBuffer: CMSampleBuffer) -> [HandLandmarkResult] {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return []
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("Hand pose detection error: \(error.localizedDescription)")
            return []
        }

        guard let results = request.results, !results.isEmpty else {
            return []
        }

        let sortedResults = results.sorted { $0.confidence > $1.confidence }

        return sortedResults.prefix(2).compactMap { observation in
            extractLandmarks(from: observation)
        }
    }

    private func extractLandmarks(from observation: VNHumanHandPoseObservation) -> HandLandmarkResult? {
        guard let wrist = observation.pointCG(for: .wrist),
              let thumbTip = observation.pointCG(for: .thumbTip),
              let indexTip = observation.pointCG(for: .indexTip),
              let middleTip = observation.pointCG(for: .middleTip),
              let ringTip = observation.pointCG(for: .ringTip),
              let littleTip = observation.pointCG(for: .littleTip) else {
            return nil
        }

        let indexPIP = observation.pointCG(for: .indexPIP)
        let middlePIP = observation.pointCG(for: .middlePIP)
        let ringPIP = observation.pointCG(for: .ringPIP)
        let littlePIP = observation.pointCG(for: .littlePIP)
        let indexMCP = observation.pointCG(for: .indexMCP)
        let middleMCP = observation.pointCG(for: .middleMCP)
        let ringMCP = observation.pointCG(for: .ringMCP)
        let littleMCP = observation.pointCG(for: .littleMCP)
        let thumbCMC = observation.pointCG(for: .thumbCMC)

        let points = [wrist, thumbTip, indexTip, middleTip, ringTip, littleTip, indexPIP, middlePIP, ringPIP, littlePIP, indexMCP, middleMCP, ringMCP, littleMCP, thumbCMC].compactMap { $0 }
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let boundingBox = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        return HandLandmarkResult(
            wrist: wrist,
            thumbTip: thumbTip,
            indexTip: indexTip,
            middleTip: middleTip,
            ringTip: ringTip,
            littleTip: littleTip,
            indexPIP: indexPIP,
            middlePIP: middlePIP,
            ringPIP: ringPIP,
            littlePIP: littlePIP,
            indexMCP: indexMCP,
            middleMCP: middleMCP,
            ringMCP: ringMCP,
            littleMCP: littleMCP,
            thumbCMC: thumbCMC,
            boundingBox: boundingBox,
            confidence: observation.confidence
        )
    }
}
