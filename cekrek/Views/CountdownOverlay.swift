import SwiftUI

struct CountdownOverlay: View {
    let value: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            Text("\(value)")
                .font(.system(size: 120, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 10)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: value)
        }
    }
}

#Preview {
    CountdownOverlay(value: 3)
}
