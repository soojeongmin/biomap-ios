import SwiftUI
import AuthenticationServices

struct IntroView: View {
    @EnvironmentObject private var auth: AuthService

    @Namespace private var ns
    @State private var compressed = false
    @State private var showSub = false
    @State private var showButton = false
    @State private var settled = false
    @State private var beat = 0

    private let appleSignInEnabled = true

    private let grid: [[String]] = [["생", "생", "한"], ["동", "식", "물"], ["도", "", "감"]]

    private func isKey(_ r: Int, _ c: Int) -> Bool {
        (r == 0 && c == 0) || (r == 1 && c == 0) || (r == 2 && c == 2)
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: settled ? 22 : 22) {
                Image("SplashLogo")
                    .resizable().scaledToFit()
                    .frame(width: settled ? 92 : 104, height: settled ? 92 : 104)
                ZStack {
                    if compressed { compactView } else { gridView }
                }
                .frame(height: settled ? 58 : 176)
                Spacer().frame(height: settled ? 26 : 10)
                VStack(spacing: 12) {
                    if appleSignInEnabled { appleButton }
                    googleButton
                }
                .opacity(showButton ? 1 : 0)
                .scaleEffect(showButton ? 1 : 0.96)
                if let error = auth.errorMessage, showButton {
                    Text(error)
                        .font(.caption).foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32).padding(.top, 4)
                }
            }
            if auth.isWorking {
                ProgressView().controlSize(.large)
            }
        }
        .onAppear(perform: run)
    }

    private var background: some View {
        Color(.systemBackground)
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
                            glyph(ch, key: false).transition(.opacity)
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
        .keyframeAnimator(initialValue: 1.0, trigger: beat) { content, value in
            content.scaleEffect(value)
        } keyframes: { _ in
            KeyframeTrack {
                LinearKeyframe(1.0, duration: 0.001)
                CubicKeyframe(1.05, duration: 0.09)
                CubicKeyframe(1.0, duration: 0.39)
                CubicKeyframe(1.05, duration: 0.09)
                CubicKeyframe(1.0, duration: 0.39)
            }
        }
    }

    private func glyph(_ ch: String, key: Bool, width: CGFloat = 56) -> some View {
        Text(ch)
            .font(.system(size: 40, weight: key ? .heavy : .bold))
            .foregroundStyle(key ? Color.brand : Color.brandInk)
            .frame(width: width, height: 56)
    }

    private var appleButton: some View {
        Button { auth.startAppleSignIn() } label: {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo").font(.system(size: 17, weight: .medium))
                Text("sign_in_with_apple").font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.black, in: Capsule())
        }
        .frame(width: 230)
        .disabled(auth.isWorking)
    }

    private var googleButton: some View {
        Button { Task { await auth.signInWithGoogle() } } label: {
            HStack(spacing: 10) {
                Image("GoogleG").resizable().scaledToFit().frame(width: 18, height: 18)
                Text("sign_in_with_google")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(white: 0.13))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.12), lineWidth: 1))
        }
        .frame(width: 230)
        .disabled(auth.isWorking)
    }

    private func run() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.85)) { compressed = true }
            withAnimation(.easeIn(duration: 0.4).delay(0.3)) { showSub = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.75) {
            beat += 1
            Haptics.heartbeat()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.7) {
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.6)) { settled = true }
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.55).delay(0.12)) { showButton = true }
        }
    }
}
