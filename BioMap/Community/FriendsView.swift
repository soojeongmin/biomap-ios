import SwiftUI
import FirebaseAuth

struct FriendsView: View {
    let refreshID: Int
    var requestDuels: Binding<Bool>? = nil
    var requestDmPeer: Binding<String?>? = nil

    @State private var query = ""
    @State private var results: [AppUser] = []
    @State private var friends: [AppUser] = []
    @State private var allObs: [Observation] = []
    @State private var allUsers: [AppUser] = []
    @State private var teams: [Team] = []
    @State private var incoming: [AppUser] = []
    @State private var outgoing: Set<String> = []
    @State private var justRequested: Set<String> = []
    @State private var selectedUser: UserRef?
    @State private var chatPeer: AppUser?
    @State private var duelTarget: AppUser?
    @State private var showDuels = false
    @State private var me: AppUser?
    @State private var reload = 0
    @State private var dmUnread: Set<String> = []
    @State private var duelPending: Set<String> = []
    @State private var loaded = false

    private var uid: String? { Auth.auth().currentUser?.uid }
    private func friendAlerted(_ fid: String) -> Bool { dmUnread.contains(fid) || duelPending.contains(fid) }
    private var friendUids: Set<String> { Set(friends.map { $0.uid }) }
    private var nameByUid: [String: String] {
        Dictionary(allUsers.map { ($0.uid, $0.name) }, uniquingKeysWith: { a, _ in a })
    }
    private var emojiByUid: [String: String] {
        Dictionary(allUsers.map { ($0.uid, $0.avatarEmoji) }, uniquingKeysWith: { a, _ in a })
    }
    private var bgByUid: [String: String] {
        Dictionary(allUsers.map { ($0.uid, $0.avatarBg) }, uniquingKeysWith: { a, _ in a })
    }
    private var nameColorByUid: [String: String] {
        Dictionary(allUsers.map { ($0.uid, $0.avatarNameColor) }, uniquingKeysWith: { a, _ in a })
    }
    private var effectByUid: [String: String] {
        Dictionary(allUsers.map { ($0.uid, $0.avatarEffect) }, uniquingKeysWith: { a, _ in a })
    }
    private var borderByUid: [String: (String, String)] {
        let teamById = Dictionary(teams.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return Dictionary(allUsers.map { u -> (String, (String, String)) in
            let t = teamById[u.teamId]
            return (u.uid, (t?.borderId ?? "white", t?.borderColor ?? "#FFFFFF"))
        }, uniquingKeysWith: { a, _ in a })
    }

    @ViewBuilder private func avatarBordered(_ u: AppUser, size: CGFloat, font: CGFloat) -> some View {
        let b = borderByUid[u.uid] ?? ("white", "#FFFFFF")
        ZStack {
            EmojiAvatar(emoji: u.avatarEmoji, name: u.name, bg: u.avatarBg.isEmpty ? ProfileDecor.defaultBg : u.avatarBg, size: size, fontSize: font,
                        effect: u.avatarEffect.isEmpty ? "none" : u.avatarEffect,
                        photoUrl: u.avatarPhoto)
            GuildBorderRing(borderId: b.0, borderColor: b.1, size: size * 1.45)
        }
        .frame(width: size * 1.45, height: size * 1.45)
    }

    private func nameTinted(_ u: AppUser, font: Font) -> some View {
        DecorNameText(text: u.name.isEmpty ? "—" : u.name,
                      token: u.avatarNameColor.isEmpty ? ProfileDecor.defaultNameColor : u.avatarNameColor,
                      font: font)
    }
    private var missionXpByUid: [String: Int] {
        Dictionary(allUsers.map { ($0.uid, $0.missionXp) }, uniquingKeysWith: { a, _ in a })
    }
    private var xpByUid: [String: Int] {
        Dictionary(grouping: allObs.filter { !$0.userId.isEmpty }, by: { $0.userId })
            .mapValues { obs in Stats.calculateXp(all: allObs, mine: obs, uid: obs.first?.userId) }
    }
    private func friendLevel(_ uid: String) -> Int {
        Stats.level((xpByUid[uid] ?? 0) + (missionXpByUid[uid] ?? 0))
    }
    private var displayFriends: [AppUser] {
        friends
            .filter { nameByUid.isEmpty || nameByUid[$0.uid] != nil }
            .map { f in
                var c = f
                c.name = nameByUid[f.uid].flatMap { $0.isEmpty ? nil : $0 } ?? f.name
                c.avatarEmoji = emojiByUid[f.uid] ?? f.avatarEmoji
                c.avatarBg = bgByUid[f.uid].flatMap { $0.isEmpty ? nil : $0 } ?? f.avatarBg
                c.avatarNameColor = nameColorByUid[f.uid].flatMap { $0.isEmpty ? nil : $0 } ?? f.avatarNameColor
                c.avatarEffect = effectByUid[f.uid].flatMap { $0.isEmpty ? nil : $0 } ?? f.avatarEffect
                return c
            }
    }
    private var searchList: [AppUser] { results.filter { $0.uid != uid } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                searchField
                Button { showDuels = true } label: {
                    Label("duel_short", systemImage: "bolt.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Color.brand, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16).padding(.top, 8)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if !searchList.isEmpty {
                        Text("search_results").font(.subheadline).foregroundStyle(.secondary)
                        ForEach(searchList) { searchRow($0) }
                    }
                    Text("friend_requests").font(.subheadline).foregroundStyle(.secondary).padding(.top, 4)
                    if incoming.isEmpty {
                        Text("friend_requests_empty").font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(incoming) { requestRow($0) }
                    }
                    Text("friend_list").font(.subheadline).foregroundStyle(.secondary).padding(.top, 4)
                    if !loaded {
                        ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
                    } else if friends.isEmpty {
                        Text("friends_empty").font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(displayFriends) { friendCard($0) }
                        }
                    }
                }
                .padding(16)
            }
        }
        .task(id: "\(refreshID)-\(reload)") { await load() }
        .sheet(item: $selectedUser) { ref in
            UserProfileSheet(userId: ref.id, userName: ref.name).largeSheet()
        }
        .fullScreenCover(item: $chatPeer) { peer in
            if let me {
                FriendChatView(peer: peer, me: me, onBack: { chatPeer = nil })
            }
        }
        .fullScreenCover(isPresented: $showDuels) {
            if let me {
                DuelView(me: me, onBack: { showDuels = false })
            }
        }
        .sheet(item: $duelTarget) { target in
            CreateDuelView(target: target, myCoins: me?.coins ?? 0, onDone: { showDuels = true })
        }
        .onChange(of: requestDuels?.wrappedValue) { _, v in
            if v == true { showDuels = true; requestDuels?.wrappedValue = false }
        }
        .onChange(of: requestDmPeer?.wrappedValue) { _, v in
            if let peer = v {
                requestDmPeer?.wrappedValue = nil
                dmUnread.remove(peer)
                Task {
                    if let myUid = uid { await UserRepository.clearDmUnread(myUid: myUid, peerUid: peer) }
                    if let u = await UserRepository.getUser(peer) { chatPeer = u }
                }
            }
        }
        .onAppear {
            if requestDuels?.wrappedValue == true { showDuels = true; requestDuels?.wrappedValue = false }
            if let peer = requestDmPeer?.wrappedValue {
                requestDmPeer?.wrappedValue = nil
                dmUnread.remove(peer)
                Task {
                    if let myUid = uid { await UserRepository.clearDmUnread(myUid: myUid, peerUid: peer) }
                    if let u = await UserRepository.getUser(peer) { chatPeer = u }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            TextField("friend_search_hint", text: $query)
                .textInputAutocapitalization(.never)
                .onSubmit { runSearch() }
            Button(action: runSearch) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.brand)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(Color(.systemGray5), in: Capsule())
        .onChange(of: query) { _, v in if v.isEmpty { results = [] } }
    }

    private func searchRow(_ user: AppUser) -> some View {
        HStack(spacing: 12) {
            avatarBordered(user, size: 40, font: 22)
            nameTinted(user, font: .body).frame(maxWidth: .infinity, alignment: .leading)
            if friendUids.contains(user.uid) {
                Text("friend_added").font(.caption).foregroundStyle(.secondary)
            } else if outgoing.contains(user.uid) || justRequested.contains(user.uid) {
                Text("friend_requested").font(.caption.weight(.semibold)).foregroundStyle(Color.brand)
            } else {
                Button("friend_request_send") {
                    guard let uid else { return }
                    justRequested.insert(user.uid)
                    Task { await UserRepository.sendFriendRequest(myUid: uid, to: user); reload += 1 }
                }
                .buttonStyle(PillBrandButton())
            }
        }
        .padding(.vertical, 4)
    }

    private func requestRow(_ user: AppUser) -> some View {
        HStack(spacing: 12) {
            avatarBordered(user, size: 40, font: 22)
            nameTinted(user, font: .body).frame(maxWidth: .infinity, alignment: .leading)
            Button("friend_accept") {
                incoming.removeAll { $0.uid == user.uid }
                if !friends.contains(where: { $0.uid == user.uid }) { friends.append(user) }
                Task { await UserRepository.acceptFriend(fromUid: user.uid); reload += 1 }
            }
            .buttonStyle(PillBrandButton())
            Button("friend_reject") {
                guard let uid else { return }
                Task { await UserRepository.rejectFriend(myUid: uid, fromUid: user.uid); reload += 1 }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func friendCard(_ friend: AppUser) -> some View {
        let hasHeader = !friend.avatarHeader.isEmpty
        return ZStack(alignment: .topTrailing) {
            ZStack(alignment: .top) {
                Group {
                    if hasHeader {
                        Color(.tertiarySystemFill)
                            .overlay {
                                AsyncImage(url: URL(string: friend.avatarHeader)) { img in
                                    img.resizable().scaledToFill()
                                } placeholder: {
                                    Color(.tertiarySystemFill)
                                }
                            }
                            .clipped()
                    } else {
                        Color.clear
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 96)
                VStack(spacing: 8) {
                    Button { selectedUser = UserRef(id: friend.uid, name: friend.name) } label: {
                        VStack(spacing: 8) {
                            avatarBordered(friend, size: 64, font: 34)
                                .overlay(alignment: .topTrailing) {
                                    if friendAlerted(friend.uid) {
                                        Circle().fill(Color.red)
                                            .frame(width: 15, height: 15)
                                            .overlay(Circle().stroke(Color(.secondarySystemGroupedBackground), lineWidth: 2.5))
                                            .offset(x: -2, y: 2)
                                    }
                                }
                            Text(localizedFormat("level_format", friendLevel(friend.uid)))
                                .font(.callout).fontWeight(.semibold).foregroundStyle(Color.brand)
                            nameTinted(friend, font: .body).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 8) {
                        friendActionButton("bubble.left.fill", "dm_open") {
                            chatPeer = friend
                            dmUnread.remove(friend.uid)
                            if let uid { Task { await UserRepository.clearDmUnread(myUid: uid, peerUid: friend.uid) } }
                        }
                        friendActionButton("bolt.fill", "duel_short") { duelTarget = friend }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 50)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .glassCardClipped(radius: 16)
            Button {
                guard let uid else { return }
                Task { await UserRepository.removeFriend(myUid: uid, friendUid: friend.uid); reload += 1 }
            } label: {
                Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary).padding(8)
            }
        }
    }

    private func friendActionButton(_ icon: String, _ titleKey: LocalizedStringKey, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(titleKey, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.brand)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .glassCapsule(interactive: true)
        }
        .buttonStyle(.plain)
    }

    private func runSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        Task { results = q.isEmpty ? [] : await UserRepository.search(q) }
    }

    private func load() async {
        async let friendsL: [AppUser] = uid != nil ? UserRepository.getFriends(uid!) : []
        async let incomingL: [AppUser] = uid != nil ? UserRepository.incomingRequests(uid!) : []
        async let outgoingL: Set<String> = uid != nil ? UserRepository.outgoingRequestUids(uid!) : []
        async let meL: AppUser? = uid != nil ? UserRepository.getUser(uid!) : nil
        async let dmL: Set<String> = uid != nil ? UserRepository.dmUnreadFrom(uid!) : []
        async let duelsL: [Duel] = uid != nil ? DuelRepository.myDuels(uid!) : []
        async let obsL = ObservationRepository.getAll()
        async let usersL = UserRepository.getAllUsers()
        async let teamsL = TeamRepository.getAllTeams()
        friends = await friendsL
        incoming = await incomingL
        outgoing = await outgoingL
        me = await meL
        dmUnread = await dmL
        duelPending = Set((await duelsL).filter { $0.status == "pending" && $0.bUid == (uid ?? "") }.map { $0.aUid })
        allObs = await obsL
        allUsers = await usersL
        teams = await teamsL
        loaded = true
    }
}
