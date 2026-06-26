import SwiftUI

enum BioTab: Hashable {
    case map, list, community, profile
}

struct MainView: View {
    @State private var tab: BioTab = .map
    @State private var showAdd = false
    @State private var refreshID = 0
    @State private var communityTab = 2
    @State private var communityChatRequest = false
    @State private var communityDuelRequest = false
    @State private var communityDmPeer: String?
    @State private var detailObs: Observation?
    @State private var updateConfig: AppConfig?
    @State private var showUpdate = false
    @ObservedObject private var router = NotifRouter.shared

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                BioTabBar(tab: $tab, onAdd: { showAdd = true })
            }
            .task { await checkUpdate() }
            .task(id: router.destination) {
                guard let dest = router.destination else { return }
                handleNavigate(dest)
                router.destination = nil
            }
            .alert("update_title", isPresented: $showUpdate) {
                Button("update_now") {
                    if let c = updateConfig, let url = URL(string: c.iosUrl) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("update_later", role: .cancel) {}
            } message: {
                Text((updateConfig?.updateMessage).flatMap { $0.isEmpty ? nil : $0 }
                     ?? NSLocalizedString("update_message", comment: ""))
            }
            .fullScreenCover(isPresented: $showAdd) {
                AddObservationView(
                    onDone: { showAdd = false; refreshID += 1 },
                    onCancel: { showAdd = false }
                )
                .padContentWidth()
            }
            .sheet(item: $detailObs) { obs in
                ObservationDetailView(observation: obs, onChanged: { refreshID += 1 })
                    .adaptiveDetents()
            }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .map: MapView(refreshID: refreshID)
        case .list: ListView(refreshID: refreshID).padContentWidth()
        case .community: CommunityView(refreshID: refreshID, externalTab: $communityTab, requestChat: $communityChatRequest, requestDuels: $communityDuelRequest, requestDmPeer: $communityDmPeer).padContentWidth()
        case .profile: ProfileView(refreshID: refreshID, onNavigate: handleNavigate).padContentWidth()
        }
    }

    private func checkUpdate() async {
        guard let c = await AppConfigRepository.get(), !c.iosUrl.isEmpty else { return }
        let current = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
        let lastPrompted = UserDefaults.standard.integer(forKey: "updatePromptedBuild")
        if c.iosLatestBuild > current && c.iosLatestBuild != lastPrompted {
            updateConfig = c
            UserDefaults.standard.set(c.iosLatestBuild, forKey: "updatePromptedBuild")
            showUpdate = true
        }
    }

    private func handleNavigate(_ dest: NotifDestination) {
        switch dest {
        case .friends:
            communityTab = 1
            tab = .community
        case .guild:
            communityTab = 2
            tab = .community
        case .guildChat:
            communityTab = 2
            tab = .community
            communityChatRequest = true
        case .ranking:
            communityTab = 0
            tab = .community
        case .duels:
            communityTab = 1
            tab = .community
            communityDuelRequest = true
        case .dm(let peer):
            communityTab = 1
            tab = .community
            communityDmPeer = peer
        case .observation(let id):
            Task {
                let all = await ObservationRepository.getAll()
                if let obs = all.first(where: { $0.id == id }) { detailObs = obs }
            }
        }
    }
}

private struct BioTabBar: View {
    @Binding var tab: BioTab
    let onAdd: () -> Void
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            tabItem(.map, "tab_map", "map.fill")
            tabItem(.list, "tab_list", "list.bullet")
            addItem
            tabItem(.community, "tab_community", "person.3.fill")
            tabItem(.profile, "profile_title", "person.fill")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .modifier(TabBarGlass())
        .padding(.horizontal, 22)
        .padding(.bottom, 4)
    }

    private func tabItem(_ value: BioTab, _ titleKey: LocalizedStringKey, _ symbol: String) -> some View {
        let active = tab == value
        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.72)) { tab = value }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 19))
                Text(titleKey).font(.system(size: 10))
            }
            .foregroundStyle(active ? Color.brand : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background {
                if active {
                    Capsule()
                        .fill(Color.brand.opacity(0.15))
                        .matchedGeometryEffect(id: "tabIndicator", in: ns)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var addItem: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.brand))
                .shadow(color: Color.brand.opacity(0.45), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
