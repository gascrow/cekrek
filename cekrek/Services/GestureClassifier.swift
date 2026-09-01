import CoreGraphics

struct ClassifiedGesture {
    let type: GestureType
    let confidence: Float
}

final class GestureClassifier {

    func classify(landmarks: HandLandmarkResult, secondLandmarks: HandLandmarkResult? = nil) -> ClassifiedGesture? {
        if let secondLandmarks {
            if let crossed = classifyCrossedHands(first: landmarks, second: secondLandmarks) {
                return crossed
            }
        }

        let scores: [(GestureType, Float)] = [
            (.openPalm, scoreOpenPalm(landmarks)),
            (.closedFist, scoreClosedFist(landmarks)),
            (.peaceSign, scorePeaceSign(landmarks))
        ]

        guard let best = scores.max(by: { $0.1 < $1.1 }), best.1 > 0 else {
            return nil
        }

        return ClassifiedGesture(type: best.0, confidence: best.1)
    }

    // MARK: - Open Palm Detection

    private func scoreOpenPalm(_ lm: HandLandmarkResult) -> Float {
        guard let wrist = lm.wrist,
              let thumbTip = lm.thumbTip,
              let indexTip = lm.indexTip,
              let middleTip = lm.middleTip,
              let ringTip = lm.ringTip,
              let littleTip = lm.littleTip,
              let indexMCP = lm.indexMCP,
              let middleMCP = lm.middleMCP,
              let ringMCP = lm.ringMCP,
              let littleMCP = lm.littleMCP else {
            return 0
        }

        var score: Float = 0

        let palmSize = wrist.distance(to: middleMCP)

        let indexExtended = fingerExtended(tip: indexTip, mcp: indexMCP, wrist: wrist, palmSize: palmSize)
        let middleExtended = fingerExtended(tip: middleTip, mcp: middleMCP, wrist: wrist, palmSize: palmSize)
        let ringExtended = fingerExtended(tip: ringTip, mcp: ringMCP, wrist: wrist, palmSize: palmSize)
        let littleExtended = fingerExtended(tip: littleTip, mcp: littleMCP, wrist: wrist, palmSize: palmSize)

        let extendedCount = [indexExtended, middleExtended, ringExtended, littleExtended].filter { $0 }.count

        if extendedCount >= 3 { score += 0.5 }

        let spread = calculateFingerSpread(tips: [indexTip, middleTip, ringTip, littleTip])
        let normalizedSpread = spread / palmSize

        if normalizedSpread > 0.3 { score += 0.25 }

        let thumbExtended = thumbTip.distance(to: indexMCP) > palmSize * 0.5
        if thumbExtended { score += 0.15 }

        let allTipsFarFromWrist = [indexTip, middleTip, ringTip, littleTip].allSatisfy {
            $0.distance(to: wrist) > palmSize * 0.8
        }
        if allTipsFarFromWrist { score += 0.1 }

        return min(score, 1.0)
    }

    // MARK: - Closed Fist Detection

    private func scoreClosedFist(_ lm: HandLandmarkResult) -> Float {
        guard let wrist = lm.wrist,
              let thumbTip = lm.thumbTip,
              let indexTip = lm.indexTip,
              let middleTip = lm.middleTip,
              let ringTip = lm.ringTip,
              let littleTip = lm.littleTip,
              let indexMCP = lm.indexMCP,
              let middleMCP = lm.middleMCP,
              let ringMCP = lm.ringMCP,
              let littleMCP = lm.littleMCP else {
            return 0
        }

        var score: Float = 0

        let palmCenter = CGPoint(
            x: (wrist.x + middleMCP.x) / 2,
            y: (wrist.y + middleMCP.y) / 2
        )
        let palmSize = wrist.distance(to: middleMCP)

        let indexCurled = fingerCurled(tip: indexTip, mcp: indexMCP, palmCenter: palmCenter, palmSize: palmSize)
        let middleCurled = fingerCurled(tip: middleTip, mcp: middleMCP, palmCenter: palmCenter, palmSize: palmSize)
        let ringCurled = fingerCurled(tip: ringTip, mcp: ringMCP, palmCenter: palmCenter, palmSize: palmSize)
        let littleCurled = fingerCurled(tip: littleTip, mcp: littleMCP, palmCenter: palmCenter, palmSize: palmSize)

        let curledCount = [indexCurled, middleCurled, ringCurled, littleCurled].filter { $0 }.count

        if curledCount >= 3 { score += 0.6 }

        let thumbCurled = thumbTip.distance(to: wrist) < palmSize * 0.8
        if thumbCurled { score += 0.2 }

        let allTipsClose = [indexTip, middleTip, ringTip, littleTip].allSatisfy {
            $0.distance(to: palmCenter) < palmSize * 0.6
        }
        if allTipsClose { score += 0.2 }

        return min(score, 1.0)
    }

    // MARK: - Peace Sign Detection

    private func scorePeaceSign(_ lm: HandLandmarkResult) -> Float {
        guard let wrist = lm.wrist,
              let indexTip = lm.indexTip,
              let middleTip = lm.middleTip,
              let ringTip = lm.ringTip,
              let littleTip = lm.littleTip,
              let indexMCP = lm.indexMCP,
              let middleMCP = lm.middleMCP,
              let ringMCP = lm.ringMCP,
              let littleMCP = lm.littleMCP else {
            return 0
        }

        var score: Float = 0

        let palmSize = wrist.distance(to: middleMCP)

        let indexExtended = fingerExtended(tip: indexTip, mcp: indexMCP, wrist: wrist, palmSize: palmSize)
        let middleExtended = fingerExtended(tip: middleTip, mcp: middleMCP, wrist: wrist, palmSize: palmSize)
        let ringCurled = !fingerExtended(tip: ringTip, mcp: ringMCP, wrist: wrist, palmSize: palmSize)
        let littleCurled = !fingerExtended(tip: littleTip, mcp: littleMCP, wrist: wrist, palmSize: palmSize)

        if indexExtended && middleExtended { score += 0.4 }
        if ringCurled { score += 0.25 }
        if littleCurled { score += 0.25 }

        let spread = indexTip.distance(to: middleTip)
        let normalizedSpread = spread / palmSize
        if normalizedSpread > 0.15 && normalizedSpread < 0.8 { score += 0.1 }

        return min(score, 1.0)
    }

    // MARK: - Crossed Hands Detection

    private func classifyCrossedHands(first: HandLandmarkResult, second: HandLandmarkResult) -> ClassifiedGesture? {
        guard let wrist1 = first.wrist, let wrist2 = second.wrist else {
            return nil
        }

        let distance = wrist1.distance(to: wrist2)
        let combinedWidth = first.boundingBox.width + second.boundingBox.width
        let normalizedDistance = distance / combinedWidth

        if normalizedDistance < Constants.GestureThreshold.crossedHandsDistance {
            let hand1X = wrist1.x
            let hand2X = wrist2.x
            let box1Center = first.boundingBox.midX
            let box2Center = second.boundingBox.midX

            let crossed = (hand1X > hand2X && box1Center < box2Center) ||
                          (hand1X < hand2X && box1Center > box2Center)

            if crossed {
                let avgConfidence = (first.confidence + second.confidence) / 2
                return ClassifiedGesture(type: .crossedHands, confidence: avgConfidence)
            }
        }

        return nil
    }

    // MARK: - Helpers

    private func fingerExtended(tip: CGPoint, mcp: CGPoint, wrist: CGPoint, palmSize: Double) -> Bool {
        let tipToWrist = tip.distance(to: wrist)
        let mcpToWrist = mcp.distance(to: wrist)
        return tipToWrist > mcpToWrist * 1.2
    }

    private func fingerCurled(tip: CGPoint, mcp: CGPoint, palmCenter: CGPoint, palmSize: Double) -> Bool {
        let tipToCenter = tip.distance(to: palmCenter)
        return tipToCenter < palmSize * 0.6
    }

    private func calculateFingerSpread(tips: [CGPoint]) -> CGFloat {
        guard tips.count >= 2 else { return 0 }

        var totalDistance: CGFloat = 0
        for i in 0..<tips.count - 1 {
            totalDistance += tips[i].distance(to: tips[i + 1])
        }
        return totalDistance / CGFloat(tips.count - 1)
    }
}
