import SwiftUI
import FirebaseAuth

struct UserRef: Identifiable, Hashable {
    let id: String
    let name: String
}

struct UserProfileSheet: View {
    let userId: String
    let userName: String

    @State private var allObservations: [Observation] = []
    @State private var fullUser: AppUser?
    @State private var team: Team?
    @State private var target: String?
    @State private var loaded = false
    @State private var myUid = Auth.auth().currentUser?.uid
    @State private var isFriend = false
    @State private var requested = false
    @State private var showGuild = false

    private var userObservations: [Observation] {
        allObservations.filter { $0.userId == userId }
    }
    private var speciesCount: Int {
        Set(userObservations.map { $0.speciesName }.filter { !$0.isEmpty }).count
    }
    private var xp: Int {
        Stats.calculateXp(all: allObservations, mine: userObservations, uid: userId) + (fullUser?.missionXp ?? 0)
    }
    private var level: Int { Stats.level(xp) }
    private var days: Int {
        let created = fullUser.map { $0.createdAt > 0 ? Date(timeIntervalSince1970: Double($0.createdAt) / 1000) : nil } ?? nil
        return Stats.daysSince(created)
    }
    private var name: String {
        let n = fullUser?.name ?? userName
        return n.isEmpty ? "—" : n
    }

    var body: some View {
        ScrollView {
            if let target {
                galleryView(target)
            } else if loaded {
                profileView
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 320)
            }
        }
        .frame(maxWidth: .infinity)
        .appBackground()
        .task {
            async let obs = ObservationRepository.getAll()
            async let user = UserRepository.getUser(userId)
            async let friendsList: [AppUser] = (myUid != nil && myUid != userId) ? UserRepository.getFriends(myUid!) : []
            async let outgoingList: Set<String> = (myUid != nil && myUid != userId) ? UserRepository.outgoingRequestUids(myUid!) : []
            let u = await user
            allObservations = await obs
            fullUser = u
            if let tid = u?.teamId, !tid.isEmpty { team = await TeamRepository.getTeam(tid) }
            isFriend = (await friendsList).contains { $0.uid == userId }
            requested = (await outgoingList).contains(userId)
            loaded = true
        }
    }

    private var avatarBlock: some View {
        ZStack {
            EmojiAvatar(emoji: fullUser?.avatarEmoji ?? "", name: name, bg: (fullUser?.avatarBg).flatMap { $0.isEmpty ? nil : $0 } ?? ProfileDecor.defaultBg, size: 80, fontSize: 44,
                        effect: (fullUser?.avatarEffect).flatMap { $0.isEmpty ? nil : $0 } ?? "none",
                        photoUrl: fullUser?.avatarPhoto ?? "")
            GuildBorderRing(borderId: team?.borderId ?? "white", borderColor: team?.borderColor ?? "#FFFFFF", size: 116)
        }
        .frame(width: 116, height: 116)
    }

    private var profileView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                if let h = fullUser?.avatarHeader, !h.isEmpty {
                    ZStack(alignment: .top) {
                        Color(.tertiarySystemFill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .overlay {
                                AsyncImage(url: URL(string: h)) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Color(.tertiarySystemFill)
                                }
                            }
                            .clipped()
                            .contentShape(Rectangle())
                        avatarBlock.padding(.top, 150 - 58)
                    }
                } else {
                    avatarBlock.padding(.top, 16)
                }
                DecorNameText(text: name, token: (fullUser?.avatarNameColor).flatMap { $0.isEmpty ? nil : $0 } ?? ProfileDecor.defaultNameColor, font: .title3.weight(.semibold))
                if let team {
                    Button { showGuild = true } label: {
                        HStack(spacing: 4) {
                            if team.ownerId == userId {
                                Image(systemName: "star.fill").font(.caption).foregroundStyle(Color.brand)
                            }
                            Text(team.name).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showGuild) {
                        GuildPreviewSheet(teamId: team.id).largeSheet()
                    }
                }
                if myUid != nil && !userId.isEmpty && userId != myUid {
                    friendButton
                }
            }
            CollectionTierView(speciesCount: speciesCount)
            ProfileStatsView(speciesCount: speciesCount, days: days, level: level, xp: xp)
            ProfileObservationsView(observations: userObservations) { target = $0 }
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder private var friendButton: some View {
        if isFriend {
            Label("friend_added", systemImage: "checkmark")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(Capsule().fill(Color(.systemGray5)))
        } else if requested {
            Text("friend_requested")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(Capsule().fill(Color(.systemGray5)))
        } else {
            Button {
                Task {
                    guard let myUid else { return }
                    let target = fullUser ?? AppUser(uid: userId, name: userName)
                    await UserRepository.sendFriendRequest(myUid: myUid, to: target)
                    requested = true
                }
            } label: {
                Label("friend_request_send", systemImage: "person.badge.plus")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().fill(Color.brand))
            }
            .buttonStyle(.plain)
        }
    }

    private func galleryView(_ key: String) -> some View {
        let items = key == galleryAllKey ? userObservations : userObservations.filter { $0.category == key }
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { target = nil } label: {
                    Image(systemName: "chevron.left")
                    Text(key == galleryAllKey ? "category_all" : categoryLabelKey(key))
                }
                .font(.headline)
                Spacer()
            }
            GalleryGrid(observations: items)
        }
        .padding(16)
    }
}
