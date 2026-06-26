import SwiftUI

struct IntroSplashView: View {
    var onDone: () -> Void

    @Namespace private var ns
    @State private var compressed = false
    @State private var faded = false
    @State private var appeared = false

    private let grid: [[String]] = [["생", "생", "한"], ["동", "식", "물"], ["도", "", "감"]]

    private func isKey(_ r: Int, _ c: Int) -> Bool {
        (r == 0 && c == 0) || (r == 1 && c == 0) || (r == 2 && c == 2)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 22) {
                logoTile
                ZStack {
                    if compressed { compactView } else { gridView }
                }
                .frame(height: 176)
            }
            .opacity(appeared ? 1 : 0)
        }
        .opacity(faded ? 0 : 1)
        .task { await run() }
    }

    private var logoTile: some View {
        Image("AppLogoTile")
            .resizable().scaledToFit()
            .frame(width: 128, height: 128)
    }

    private var gridView: some View {
        VStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { c in
                        let ch = grid[r][c]
                        if ch.isEmpty {
                            Color.clear.frame(width: 56, height: 56)
                        } else if isKey(r, c) {
                            glyph(ch, key: true).matchedGeometryEffect(id: ch, in: ns)
                        } else {
                            glyph(ch, key: false).transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
        }
    }

    private var compactView: some View {
        HStack(spacing: 2) {
            ForEach(["생", "동", "감"], id: \.self) { ch in
                glyph(ch, key: true, width: 42).matchedGeometryEffect(id: ch, in: ns)
            }
        }
    }

    private func glyph(_ ch: String, key: Bool, width: CGFloat = 56) -> some View {
        Text(ch)
            .font(.system(size: 40, weight: key ? .heavy : .bold))
            .foregroundStyle(key ? Color.brand : Color.brandInk)
            .frame(width: width, height: 56)
    }

    private func run() async {
        withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        withAnimation(.spring(response: 0.7, dampingFraction: 0.66)) { compressed = true }
        try? await Task.sleep(nanoseconds: 1_250_000_000)
        withAnimation(.easeOut(duration: 0.4)) { faded = true }
        try? await Task.sleep(nanoseconds: 450_000_000)
        onDone()
    }
}
