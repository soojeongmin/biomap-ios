import SwiftUI
import FirebaseAuth

struct RootView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var deepLink: DeepLinkRouter
    @Environment(\.openURL) private var openURL
    @State private var needsNickname: Bool?
    @State private var showSplash = Auth.auth().currentUser != nil
    @State private var showUpdate = false
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        ZStack {
            Group {
                if auth.user == nil {
                    IntroView()
                } else if needsNickname == nil {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if needsNickname == true {
                    NicknameSetupView(onDone: { needsNickname = false })
                } else {
                    MainView()
                }
            }
            if showSplash {
                IntroSplashView(onDone: { showSplash = false })
            }
            if !onboarded {
                OnboardingView(onDone: { withAnimation { onboarded = true } })
                    .transition(.opacity)
                    .zIndex(3)
            }
        }
        .animation(.default, value: auth.user?.uid)
        .task(id: auth.user?.uid) {
            guard let uid = auth.user?.uid else { needsNickname = nil; return }
            let u = await withTimeout(seconds: 8) { await UserRepository.getUser(uid) }
            needsNickname = (u??.name ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        }
        .task {
            if let latest = await AppVersion.latest(),
               AppVersion.isOutdated(AppVersion.current, latest) {
                showUpdate = true
            }
        }
        .alert("update_available_title", isPresented: $showUpdate) {
            Button("update_now") { if let u = AppVersion.storeURL { openURL(u) } }
            Button("later", role: .cancel) {}
        }
        .sheet(item: $deepLink.observation) { obs in
            ObservationDetailView(observation: obs)
                .adaptiveDetents()
        }
    }
}
