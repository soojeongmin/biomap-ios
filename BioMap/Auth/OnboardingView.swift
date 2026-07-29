import SwiftUI
import UserNotifications

struct OnboardingView: View {
    var onDone: () -> Void
    @State private var page = 0

    private struct Slide {
        let symbol: String
        let titleKey: LocalizedStringKey
        let bodyKey: LocalizedStringKey
    }

    private let slides: [Slide] = [
        .init(symbol: "camera.viewfinder", titleKey: "onboard_1_title", bodyKey: "onboard_1_body"),
        .init(symbol: "map.fill", titleKey: "onboard_2_title", bodyKey: "onboard_2_body"),
        .init(symbol: "person.3.fill", titleKey: "onboard_3_title", bodyKey: "onboard_3_body"),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0xE7 / 255, green: 0xFA / 255, blue: 0xF1 / 255), Color(.systemBackground)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(slides.indices, id: \.self) { i in
                        slideView(slides[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if page < slides.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
                        onDone()
                    }
                } label: {
                    Text(page < slides.count - 1 ? "onboard_next" : "onboard_start")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledBrandButton())
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
    }

    private func slideView(_ s: Slide) -> some View {
        VStack(spacing: 26) {
            Spacer()
            Image(systemName: s.symbol)
                .font(.system(size: 92, weight: .regular))
                .foregroundStyle(Color.brand)
                .frame(height: 120)
            VStack(spacing: 12) {
                Text(s.titleKey)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(s.bodyKey)
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 36)
            Spacer()
            Spacer()
        }
    }
}
