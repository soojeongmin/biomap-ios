import SwiftUI
import FirebaseAuth

struct TeamView: View {
    let refreshID: Int
    var requestChat: Binding<Bool>? = nil

    @State private var team: Team?
    @State private var members: [AppUser] = []
    @State private var allObs: [Observation] = []
    @State private var loading = true
    @State private var reload = 0
    @State private var searchQuery = ""
    @State private var searchResults: [Team] = []
    @State private var previewTeamId: String?
    @State private var showCreate = false
    @State private var allTeams: [Team] = []
    @State private var pendingTeamId: String?
    @State private var pendingRequests: [JoinRequest] = []
    @State private var myName = ""
    @State private var myUser: AppUser?
    @State private var showChat = false
    @State private var pendingChatOpen = false
    @State private var selectedMember: UserRef?
    @State private var showDescEdit = false
    @State private var descText = ""
    @State private var showRenameEdit = false
    @State private var renameText = ""
    @State private var showRenameTaken = false
    @State private var showRenameInsufficient = false
    @State private var selectedManageUid: String?
    @State private var transferTarget: AppUser?
    @State private var kickTarget: AppUser?
    @State private var autoAccept = false
    @StateObject private var duelStore = GuildDuelStore()
    @State private var showChallenge = false

    private var uid: String? { Auth.auth().currentUser?.uid }
    private static let minObservations = 5

    private var myObsCount: Int {
        guard let uid else { return 0 }
        return allObs.filter { $0.userId == uid }.count
    }
    private var canCreate: Bool { myObsCount >= Self.minObservations }

    private func contribution(_ userId: String) -> Int {
        Set(allObs.filter { $0.userId == userId }.map { $0.speciesName }.filter { !$0.isEmpty }).count
    }

    var body: some View {
        Group {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let team {
                detailView(team)
            } else {
                emptyView
            }
        }
        .task(id: "\(refreshID)-\(reload)") { await load() }
        .onChange(of: requestChat?.wrappedValue) { _, v in
            if v == true { openChatWhenReady() }
        }
        .onAppear { if requestChat?.wrappedValue == true { openChatWhenReady() } }
        .sheet(isPresented: $showCreate) {
            CreateTeamSheet { name in await create(name) }
        }
        .sheet(item: $selectedMember) { ref in
            UserProfileSheet(userId: ref.id, userName: ref.name).largeSheet()
        }
        .sheet(item: Binding(get: { previewTeamId.map { UserRef(id: $0, name: "") } }, set: { previewTeamId = $0?.id })) { ref in
            GuildPreviewSheet(teamId: ref.id).largeSheet()
        }
        .alert("guild_transfer", isPresented: Binding(get: { transferTarget != nil }, set: { if !$0 { transferTarget = nil } }), presenting: transferTarget) { member in
            Button("guild_transfer_action", role: .destructive) {
                Task {
                    if let t = team {
                        await TeamRepository.transferOwnership(teamId: t.id, toUid: member.uid)
                        transferTarget = nil
                        selectedManageUid = nil
                        reload += 1
                    }
                }
            }
            Button("cancel", role: .cancel) { transferTarget = nil }
        } message: { member in
            Text(localizedFormat("guild_transfer_confirm", member.name))
        }
        .alert("guild_kick", isPresented: Binding(get: { kickTarget != nil }, set: { if !$0 { kickTarget = nil } }), presenting: kickTarget) { member in
            Button("guild_kick_action", role: .destructive) {
                Task {
                    if let t = team {
                        await TeamRepository.kickMember(teamId: t.id, memberUid: member.uid)
                        kickTarget = nil
                        selectedManageUid = nil
                        reload += 1
                    }
                }
            }
            Button("cancel", role: .cancel) { kickTarget = nil }
        } message: { member in
            Text(localizedFormat("guild_kick_confirm", member.name))
        }
    }

    private func create(_ name: String) async -> CreateTeamResult {
        guard let user = Auth.auth().currentUser else { return .failed }
        let result = await TeamRepository.createTeam(name: name, owner: user)
        if case .success = result { reload += 1 }
        return result
    }

    private var emptyView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 50)).foregroundStyle(Color.brand)
                    .padding(.top, 24)
                Text("team_none")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("team_create") { showCreate = true }
                    .buttonStyle(FilledBrandButton())
                    .disabled(!canCreate)
                if !canCreate {
                    Text("team_min_obs")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 8) {
                    TextField("guild_search_hint", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .task(id: searchQuery) {
                            let q = searchQuery.trimmingCharacters(in: .whitespaces)
                            if q.isEmpty { searchResults = await TeamRepository.getAllTeams(); return }
                            try? await Task.sleep(nanoseconds: 250_000_000)
                            if Task.isCancelled { return }
                            let r = await TeamRepository.searchTeams(q)
                            if Task.isCancelled { return }
                            searchResults = r
                        }
                    ForEach(searchResults) { t in
                        Button { previewTeamId = t.id } label: {
                            HStack {
                                Text(t.name).foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 10).padding(.horizontal, 12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty && searchResults.isEmpty {
                        Text("guild_no_results").font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 8)

                if pendingTeamId != nil {
                    Divider().padding(.vertical, 8)
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("team_request_pending").foregroundStyle(.secondary)
                    }
                    Button("team_request_cancel") { cancelRequest() }
                        .buttonStyle(OutlineBrandButton(color: .red))
                }
            }
            .padding(24)
        }
    }

    private func detailView(_ team: Team) -> some View {
        let sorted = members.sorted { contribution($0.uid) > contribution($1.uid) }
        let total = sorted.reduce(0) { $0 + contribution($1.uid) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text(team.name).font(.title2.bold())
                    if uid == team.ownerId {
                        Button {
                            renameText = team.name
                            showRenameEdit = true
                        } label: {
                            Image(systemName: "pencil").font(.subheadline).foregroundStyle(Color.brand)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 8)

                if let d = team.description, !d.isEmpty {
                    Text(d).font(.subheadline).foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                }
                if uid == team.ownerId {
                    Button {
                        descText = team.description ?? ""
                        showDescEdit = true
                    } label: {
                        Text((team.description ?? "").isEmpty ? "guild_desc_add" : "guild_desc_edit")
                            .font(.caption).foregroundStyle(Color.brand)
                    }
                    .padding(.horizontal, 16)
                }

                Button {
                    showChat = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text("guild_chat")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.brand, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.brand.opacity(0.3), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                guildDuelSection(team)

                SectionCard(titleKey: "team_total") {
                    Text(localizedFormat("rank_unit", total))
                        .font(.title2.weight(.semibold)).foregroundStyle(Color.brand)
                        .frame(maxWidth: .infinity)
                }
                SectionCard(titleKey: "guild_weekly_title") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("guild_points_hint").font(.caption2).foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            Image(systemName: "leaf.fill").font(.caption).foregroundStyle(Color.brand)
                            Text("\(team.guildCoins ?? 0)").foregroundStyle(Color.brand).fontWeight(.semibold)
                        }
                        ForEach(["plant", "insect", "fungi", "bird"], id: \.self) { cat in
                            let prog = team.weeklyProgress?[cat] ?? 0
                            let goal = team.weeklyGoal?[cat] ?? 0
                            HStack(spacing: 8) {
                                Text(categoryLabelKey(cat)).font(.caption).frame(width: 48, alignment: .leading)
                                ProgressView(value: goal > 0 ? min(Double(prog) / Double(goal), 1.0) : 0.0).tint(Color.brand)
                                Text("\(prog)/\(goal > 0 ? "\(goal)" : "—")").font(.caption2).foregroundStyle(.secondary)
                                if (team.weeklyRewarded ?? []).contains(cat) {
                                    Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundStyle(Color.brand)
                                }
                            }
                        }
                    }
                }

                Text("team_members").font(.headline).padding(.horizontal, 16).padding(.top, 4)
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, member in
                    memberRow(rank: index + 1, member: member, ownerId: team.ownerId,
                              borderId: team.borderId ?? "white", borderColor: team.borderColor ?? "#FFFFFF")
                }

                if uid == team.ownerId && !pendingRequests.isEmpty {
                    Text("team_requests").font(.headline).padding(.horizontal, 16).padding(.top, 8)
                    ForEach(pendingRequests) { req in
                        HStack(spacing: 12) {
                            EmojiAvatar(emoji: "", name: req.name, bg: ProfileDecor.defaultBg, size: 36, fontSize: 18)
                            Text(req.name.isEmpty ? "—" : req.name).frame(maxWidth: .infinity, alignment: .leading)
                            Button("team_approve") {
                                Task { await TeamRepository.approveRequest(teamId: team.id, teamName: team.name, uid: req.id); reload += 1 }
                            }.buttonStyle(PillBrandButton())
                            Button("team_reject") {
                                Task { await TeamRepository.rejectRequest(teamId: team.id, uid: req.id); reload += 1 }
                            }.buttonStyle(PillBrandButton(color: .red))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 4)
                    }
                }

                if uid == team.ownerId {
                    SectionCard(titleKey: "guild_auto_accept") {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle(isOn: Binding(
                                get: { autoAccept },
                                set: { newValue in
                                    autoAccept = newValue
                                    Task { await TeamRepository.setAutoAccept(teamId: team.id, enabled: newValue); reload += 1 }
                                }
                            )) {
                                Text("guild_auto_accept")
                            }
                            .tint(Color.brand)
                            Text("guild_auto_accept_desc").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                BorderShopView(team: team, total: total, isOwner: uid == team.ownerId,
                               owner: members.first { $0.uid == team.ownerId }) { reload += 1 }
                    .padding(.top, 8)

                if uid == team.ownerId && sorted.contains(where: { $0.uid != team.ownerId }) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("guild_manage_hint").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Button("guild_transfer_action") {
                                if let m = sorted.first(where: { $0.uid == selectedManageUid }) { transferTarget = m }
                            }
                            .buttonStyle(OutlineBrandButton())
                            .disabled(selectedManageUid == nil)
                            Button("guild_kick_action") {
                                if let m = sorted.first(where: { $0.uid == selectedManageUid }) { kickTarget = m }
                            }
                            .buttonStyle(OutlineBrandButton(color: .red))
                            .disabled(selectedManageUid == nil)
                        }
                    }
                    .padding(.horizontal, 16).padding(.top, 8)
                }

                Button("team_leave") { leave() }
                    .buttonStyle(OutlineBrandButton(color: .red))
                    .padding(.horizontal, 16).padding(.top, 4)
            }
            .padding(.vertical, 8)
        }
        .alert("guild_desc_title", isPresented: $showDescEdit) {
            TextField("guild_desc_hint", text: $descText)
            Button("cancel", role: .cancel) {}
            Button("save") {
                Task {
                    await TeamRepository.setDescription(teamId: team.id, description: descText)
                    reload += 1
                }
            }
        } message: {
            Text("guild_desc_hint")
        }
        .alert("guild_rename", isPresented: $showRenameEdit) {
            TextField("team_name_hint", text: $renameText)
            Button("cancel", role: .cancel) {}
            Button("confirm") {
                Task {
                    let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, trimmed != team.name else { return }
                    switch await TeamRepository.renameTeam(teamId: team.id, name: trimmed) {
                    case nil: reload += 1
                    case "taken": showRenameTaken = true
                    default: showRenameInsufficient = true
                    }
                }
            }
        } message: {
            Text(String(format: NSLocalizedString("guild_rename_cost", comment: ""),
                        members.first(where: { $0.uid == uid })?.coins ?? 0))
        }
        .alert("team_name_taken", isPresented: $showRenameTaken) {
            Button("confirm", role: .cancel) {}
        }
        .alert("guild_rename_insufficient", isPresented: $showRenameInsufficient) {
            Button("confirm", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showChat) {
            if let me = myUser {
                GuildChatView(teamId: team.id, teamName: team.name, me: me,
                              isOwner: uid == team.ownerId,
                              photoByUid: Dictionary(members.map { ($0.uid, $0.avatarPhoto) }, uniquingKeysWith: { a, _ in a })) { showChat = false }
            }
        }
    }

    private func memberRow(rank: Int, member: AppUser, ownerId: String, borderId: String, borderColor: String) -> some View {
        let isMemberOwner = member.uid == ownerId
        let isViewerOwner = uid == ownerId
        let isSelected = selectedManageUid == member.uid
        return HStack(spacing: 12) {
            Text("\(rank)").font(.headline).foregroundStyle(.secondary).frame(width: 28)
            ZStack {
                EmojiAvatar(emoji: member.avatarEmoji, name: member.name, bg: member.avatarBg.isEmpty ? ProfileDecor.defaultBg : member.avatarBg, size: 40, fontSize: 22,
                            effect: member.avatarEffect.isEmpty ? "none" : member.avatarEffect,
                            photoUrl: member.avatarPhoto)
                GuildBorderRing(borderId: borderId, borderColor: borderColor, size: 58)
            }
            .frame(width: 58, height: 58)
            HStack(spacing: 4) {
                DecorNameText(text: member.name.isEmpty ? "—" : member.name,
                              token: member.avatarNameColor.isEmpty ? ProfileDecor.defaultNameColor : member.avatarNameColor,
                              font: .body)
                if isMemberOwner {
                    Image(systemName: "star.fill").font(.caption).foregroundStyle(Color.brand)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(localizedFormat("rank_unit", contribution(member.uid))).foregroundStyle(Color.brand)
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(isSelected ? Color.brand.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if isViewerOwner && !isMemberOwner {
                selectedManageUid = (selectedManageUid == member.uid) ? nil : member.uid
            } else {
                selectedMember = UserRef(id: member.uid, name: member.name)
            }
        }
    }

    @ViewBuilder
    private func guildDuelSection(_ team: Team) -> some View {
        let mine = team.id
        let isOwner = uid == team.ownerId
        let active = duelStore.duels.filter { $0.status == "active" }
        let incoming = duelStore.duels.filter { $0.status == "pending" && $0.bTeam == mine }
        let outgoing = duelStore.duels.filter { $0.status == "pending" && $0.aTeam == mine }
        VStack(spacing: 8) {
            ForEach(active) { d in activeDuelBanner(d, mine: mine) }
            ForEach(incoming) { d in incomingDuelCard(d, mine: mine, isOwner: isOwner) }
            ForEach(outgoing) { d in outgoingDuelCard(d, mine: mine, isOwner: isOwner) }
            if isOwner && active.isEmpty && incoming.isEmpty && outgoing.isEmpty {
                Button { showChallenge = true } label: {
                    Label("gduel_challenge_btn", systemImage: "bolt.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(OutlineBrandButton())
            }
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $showChallenge) {
            GuildDuelChallengeSheet(myTeamId: team.id, myPoints: team.guildCoins ?? 0)
        }
    }

    private func metricName(_ m: String) -> String {
        NSLocalizedString(m == "obs" ? "duel_metric_obs" : "duel_metric_new", comment: "")
    }

    private func duelTimeLeft(_ endAt: Int64) -> String {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let ms = endAt - now
        if ms <= 0 { return NSLocalizedString("duel_active", comment: "") }
        let hours = Int(ms / 3_600_000)
        if hours >= 24 { return localizedFormat("gduel_days_left", (hours + 23) / 24) }
        return localizedFormat("gduel_hours_left", max(hours, 1))
    }

    private func duelScoreCol(_ name: String, _ score: Int, lead: Bool) -> some View {
        VStack(spacing: 2) {
            Text(name.isEmpty ? "—" : name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text("\(score)").font(.title.weight(.bold)).foregroundStyle(lead ? Color.brand : .primary)
        }
        .frame(maxWidth: .infinity)
    }

    private func activeDuelBanner(_ d: GuildDuel, mine: String) -> some View {
        let myS = d.myScore(mine), theirS = d.theirScore(mine)
        return VStack(spacing: 8) {
            HStack {
                Label("duel_active", systemImage: "bolt.fill").font(.caption.weight(.bold)).foregroundStyle(Color.brand)
                Spacer()
                Text(duelTimeLeft(d.endAt)).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                duelScoreCol(d.myName(mine), myS, lead: myS >= theirS)
                Text("VS").font(.subheadline.weight(.bold)).foregroundStyle(.secondary)
                duelScoreCol(d.oppName(mine), theirS, lead: theirS >= myS)
            }
            Text(localizedFormat("gduel_banner_info", metricName(d.metric), d.stake))
                .font(.caption2).foregroundStyle(.secondary)
            Text(localizedFormat("gduel_winner_takes", d.pot))
                .font(.caption2.weight(.semibold)).foregroundStyle(Color.brand)
        }
        .padding(12).frame(maxWidth: .infinity)
        .background(Color.brand.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brand.opacity(0.3), lineWidth: 1))
    }

    private func incomingDuelCard(_ d: GuildDuel, mine: String, isOwner: Bool) -> some View {
        VStack(spacing: 8) {
            Text(localizedFormat("gduel_incoming", d.oppName(mine)))
                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, alignment: .leading)
            Text(localizedFormat("gduel_info", d.stake, metricName(d.metric), d.durationDays))
                .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            if isOwner {
                HStack(spacing: 8) {
                    Button("duel_accept") { Task { await GuildDuelRepository.respond(duelId: d.id, accept: true); reload += 1 } }
                        .buttonStyle(PillBrandButton())
                    Button("duel_decline") { Task { await GuildDuelRepository.respond(duelId: d.id, accept: false); reload += 1 } }
                        .buttonStyle(PillBrandButton(color: .red))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12).frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func outgoingDuelCard(_ d: GuildDuel, mine: String, isOwner: Bool) -> some View {
        HStack {
            Text(localizedFormat("gduel_outgoing", d.oppName(mine))).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            if isOwner {
                Button("duel_cancel") { Task { await GuildDuelRepository.cancel(duelId: d.id); reload += 1 } }
                    .font(.caption).foregroundStyle(.red)
            }
        }
        .padding(12).frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func load() async {
        loading = true
        if let uid { _ = await TeamRepository.completeApprovedJoins(uid: uid) }
        allObs = await ObservationRepository.getAll()
        let me = uid != nil ? await UserRepository.getUser(uid!) : nil
        myUser = me
        myName = me?.name ?? Auth.auth().currentUser?.displayName ?? ""
        let teamId = me?.teamId ?? ""
        team = await TeamRepository.getTeam(teamId)
        if let t = team {
            duelStore.start(teamId: t.id)
            members = await TeamRepository.getMembers(t.id)
            pendingRequests = (uid == t.ownerId) ? await TeamRepository.pendingRequests(teamId: t.id) : []
            autoAccept = t.autoAccept ?? false
            allTeams = []
            pendingTeamId = nil
        } else {
            members = []
            if let pending = (me?.pendingTeamId).flatMap({ $0.isEmpty ? nil : $0 }) {
                pendingTeamId = pending
            } else {
                pendingTeamId = uid != nil ? await TeamRepository.myPendingRequestTeamId(uid: uid!) : nil
            }
        }
        loading = false
        if pendingChatOpen && team != nil {
            pendingChatOpen = false
            showChat = true
        }
    }

    private func openChatWhenReady() {
        requestChat?.wrappedValue = false
        if team != nil {
            showChat = true
        } else {
            pendingChatOpen = true
        }
    }

    private func cancelRequest() {
        guard let uid, let teamId = pendingTeamId else { return }
        Task { await TeamRepository.cancelRequest(teamId: teamId, uid: uid); reload += 1 }
    }

    private func leave() {
        guard let uid else { return }
        Task { await TeamRepository.leave(uid: uid); reload += 1 }
    }
}

private struct BorderShopView: View {
    let team: Team
    let total: Int
    let isOwner: Bool
    let owner: AppUser?
    let onChanged: () -> Void

    @State private var previewBorder: String?
    @State private var buying = false

    private var available: Int { team.guildCoins ?? 0 }
    private var color: Color { Color(uiColor: UIColor(hexString: team.borderColor ?? "#FFFFFF") ?? .white) }
    private var owned: Set<String> { GuildBorders.owned(team) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("border_shop").font(.headline).padding(.horizontal, 16)
            HStack(spacing: 6) {
                Text("border_points")
                Text("\(available)").fontWeight(.bold)
            }.font(.subheadline).foregroundStyle(Color.brand).padding(.horizontal, 16)
            if !isOwner {
                Text("border_owner_only").font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 16)
            }
            if isOwner, let pid = previewBorder, !owned.contains(pid) {
                let b = GuildBorders.byId(pid)
                let canBuy = available >= b.price
                HStack(spacing: 12) {
                    ZStack {
                        EmojiAvatar(
                            emoji: owner?.avatarEmoji ?? "",
                            name: owner?.name ?? "",
                            bg: (owner?.avatarBg).flatMap { $0.isEmpty ? nil : $0 } ?? ProfileDecor.defaultBg,
                            size: 42, fontSize: 22,
                            effect: (owner?.avatarEffect).flatMap { $0.isEmpty ? nil : $0 } ?? "none",
                            photoUrl: owner?.avatarPhoto ?? ""
                        )
                        GuildBorderRing(borderId: pid, borderColor: team.borderColor ?? "#FFFFFF", size: 42 * 1.45)
                    }
                    .frame(width: 42 * 1.45, height: 42 * 1.45)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(LocalizedStringKey(b.nameKey)).font(.subheadline.weight(.semibold))
                        Text("\(b.price)").font(.caption).foregroundStyle(canBuy ? Color.brand : .secondary)
                    }
                    Spacer()
                    Button { buyPreview(b) } label: {
                        Text("customize_buy")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(canBuy ? Color.brand : Color(.systemGray4), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canBuy || buying)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(GuildBorders.all) { b in borderItem(b) }
                }.padding(.horizontal, 16)
            }
            if isOwner {
                Text("border_color").font(.subheadline.weight(.semibold)).padding(.horizontal, 16).padding(.top, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(GuildBorders.palette, id: \.self) { hex in
                            let sel = (team.borderColor ?? "").caseInsensitiveCompare(hex) == .orderedSame
                            Circle().fill(Color(uiColor: UIColor(hexString: hex) ?? .white))
                                .frame(width: 38, height: 38)
                                .overlay(Circle().stroke(sel ? Color.brand : Color(.separator), lineWidth: sel ? 3 : 1))
                                .onTapGesture {
                                    Task { await TeamRepository.setBorder(teamId: team.id, borderId: team.borderId ?? "white", color: hex); onChanged() }
                                }
                        }
                    }.padding(.horizontal, 16)
                }
            }
        }
    }

    private func buyPreview(_ b: GuildBorder) {
        guard isOwner, available >= b.price, !buying else { return }
        buying = true
        Task {
            let col = team.borderColor ?? "#FFFFFF"
            if await TeamRepository.buyBorder(teamId: team.id, borderId: b.id) {
                await TeamRepository.setBorder(teamId: team.id, borderId: b.id, color: col)
            }
            buying = false
            previewBorder = nil
            onChanged()
        }
    }

    private func borderItem(_ b: GuildBorder) -> some View {
        let isOwnedB = owned.contains(b.id)
        let equipped = (team.borderId ?? "white") == b.id
        let previewing = previewBorder == b.id
        return Button {
            guard isOwner else { return }
            if isOwnedB {
                if equipped { return }
                Task {
                    let col = team.borderColor ?? "#FFFFFF"
                    await TeamRepository.setBorder(teamId: team.id, borderId: b.id, color: col); onChanged()
                }
            } else {
                previewBorder = b.id
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(Color(.systemGray5)).frame(width: 44, height: 44)
                    if let asset = b.asset, let img = UIImage(named: asset) {
                        Image(uiImage: img).resizable().scaledToFit().frame(width: 66, height: 66).colorMultiply(color)
                    } else if GuildBorders.procedural.contains(b.id) {
                        GuildBorderRing(borderId: b.id, borderColor: team.borderColor ?? "#FFFFFF", size: 66)
                    } else {
                        Circle().stroke(Color(.systemGray3), lineWidth: 3).frame(width: 56, height: 56)
                    }
                }
                .frame(width: 66, height: 66)
                .overlay {
                    if equipped { Circle().stroke(Color.brand, lineWidth: 2.5) }
                    else if previewing { Circle().stroke(Color.brand, style: StrokeStyle(lineWidth: 2.5, dash: [4, 3])) }
                }
                Text(LocalizedStringKey(b.nameKey)).font(.caption)
                if equipped {
                    Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundStyle(Color.brand)
                } else if !isOwnedB {
                    Text("\(b.price)").font(.caption2.weight(.bold))
                        .foregroundStyle(available >= b.price ? Color.brand : .secondary)
                }
            }
            .frame(width: 78)
        }
        .buttonStyle(.plain)
        .disabled(!isOwner)
    }
}

private struct GuildDuelChallengeSheet: View {
    let myTeamId: String
    let myPoints: Int
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Team] = []
    @State private var allGuilds: [Team] = []
    @State private var picked: Team?
    @State private var stake = 20
    @State private var metric = "obs"
    @State private var days = 3
    @State private var errorMessage: String?
    @State private var busy = false

    private var maxStake: Int { max(10, (min(100, myPoints) / 10) * 10) }
    private var listed: [Team] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return (q.isEmpty ? allGuilds : results).filter { $0.id != myTeamId }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("guild_search_hint", text: $query)
                            .textInputAutocapitalization(.never)
                            .onSubmit { search() }
                        Button(action: search) { Image(systemName: "magnifyingglass").foregroundStyle(Color.brand) }
                    }
                    ForEach(listed) { t in
                        Button { picked = t } label: {
                            HStack {
                                Text(t.name).foregroundStyle(.primary)
                                Spacer()
                                if picked?.id == t.id { Image(systemName: "checkmark").foregroundStyle(Color.brand) }
                            }
                        }
                    }
                }
                if picked != nil {
                    Section {
                        Stepper(localizedFormat("gduel_stake_label", stake), value: $stake, in: 10...maxStake, step: 10)
                        Picker("duel_metric", selection: $metric) {
                            Text("duel_metric_obs").tag("obs")
                            Text("duel_metric_new").tag("newspecies")
                        }
                        Picker("duel_duration", selection: $days) {
                            ForEach([1, 3, 7], id: \.self) { Text(localizedFormat("duel_days", $0)).tag($0) }
                        }
                    }
                }
            }
            .navigationTitle(Text("gduel_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("duel_send") {
                        guard let p = picked else { return }
                        busy = true
                        Task {
                            let err = await GuildDuelRepository.create(opponentTeamId: p.id, stake: stake, metric: metric, durationDays: days)
                            busy = false
                            if let err { errorMessage = err } else { dismiss() }
                        }
                    }
                    .disabled(picked == nil || busy || myPoints < stake)
                }
            }
            .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("confirm", role: .cancel) {}
            }
            .task { allGuilds = await TeamRepository.getAllTeams() }
        }
    }

    private func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        Task { results = q.isEmpty ? [] : await TeamRepository.searchTeams(q) }
    }
}

struct CreateTeamSheet: View {
    let onCreate: (String) async -> CreateTeamResult
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var error: String?
    @State private var working = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("team_name_hint", text: $name)
                    .onChange(of: name) { _, _ in error = nil }
                if let error {
                    Text(LocalizedStringKey(error)).font(.caption).foregroundStyle(.red)
                }
            }
            .navigationTitle(Text("team_create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("team_create_action") {
                        working = true
                        Task {
                            let result = await onCreate(name.trimmingCharacters(in: .whitespaces))
                            working = false
                            switch result {
                            case .success: dismiss()
                            case .duplicateName: error = "team_name_taken"
                            case .failed: error = "team_create_failed"
                            }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || working)
                }
            }
        }
    }
}
