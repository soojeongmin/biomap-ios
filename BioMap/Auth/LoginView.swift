import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            HeartbeatBorder()
            VStack(spacing: 0) {
                Spacer()
                Image("SplashLogo")
                    .resizable().scaledToFit()
                    .frame(width: 112, height: 112)
                Spacer().frame(height: 18)
                Text("app_name")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.brandDark)
                Spacer().frame(height: 8)
                Text("login_subtitle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.brandDark.opacity(0.7))
                    .multilineTextAlignment(.center)
                Spacer().frame(height: 44)
                googleButton
                if let message = auth.errorMessage {
                    Spacer().frame(height: 16)
                    Text(message).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(.horizontal, 40)
            if auth.isWorking {
                ProgressView().controlSize(.large)
            }
        }
        .onAppear { Haptics.heartbeat() }
    }

    private var background: some View {
        Group {
            if let ui = UIImage(named: "LoginBg") {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(red: 0.17, green: 0.49, blue: 0.36), Color(red: 0.86, green: 0.93, blue: 0.86)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .overlay(.regularMaterial)
    }

    private var googleButton: some View {
        Button { Task { await auth.signInWithGoogle() } } label: {
            HStack(spacing: 10) {
                Image("GoogleG").resizable().scaledToFit().frame(width: 18, height: 18)
                Text("sign_in_with_google")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.13, green: 0.13, blue: 0.13))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.12), lineWidth: 1))
        }
        .disabled(auth.isWorking)
    }
}
