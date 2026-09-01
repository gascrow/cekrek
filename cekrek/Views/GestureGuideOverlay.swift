import SwiftUI

struct GestureGuideOverlay: View {
    let detectedGesture: ClassifiedGesture?
    let confidenceThreshold: Float
    let gestureState: GestureState

    var body: some View {
        VStack(spacing: 4) {
            if let gesture = detectedGesture {
                Image(systemName: gestureIconName(for: gesture.type))
                    .font(.system(size: 28))
                    .foregroundStyle(gesture.confidence >= confidenceThreshold ? .green : .yellow)
                    .scaleEffect(gesture.confidence >= confidenceThreshold ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: gesture.confidence)
            } else {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.gray)
            }

            Text("Gestur")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.gray)
        }
        .frame(width: 60, height: 60)
    }

    private func gestureIconName(for gesture: GestureType) -> String {
        switch gesture {
        case .openPalm: return "hand.raised.fill"
        case .closedFist: return "hand.raised.fist.fill"
        case .peaceSign: return "hand.thumbsup.fill"
        case .crossedHands: return "xmark.circle.fill"
        }
    }
}

#Preview {
    GestureGuideOverlay(
        detectedGesture: ClassifiedGesture(type: .openPalm, confidence: 0.85),
        confidenceThreshold: 0.75,
        gestureState: .idle
    )
}
