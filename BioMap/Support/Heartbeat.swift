import SwiftUI
import UIKit

enum Haptics {
    static func heartbeat() {
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.prepare()
        for delay: TimeInterval in [0.09, 0.57] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                gen.prepare()
                gen.impactOccurred(intensity: 1.0)
            }
        }
    }
}

struct HeartbeatBorder: View {
    @State private var phase = false

    var body: some View {
        Rectangle()
            .stroke(Color.white, lineWidth: 34)
            .blur(radius: 18)
            .padding(phase ? 44 : 0)
            .opacity(phase ? 0 : 0.95)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.timingCurve(0.42, 0, 0.58, 1, duration: 1.1).repeatCount(2, autoreverses: false)) {
                    phase = true
                }
            }
    }
}
