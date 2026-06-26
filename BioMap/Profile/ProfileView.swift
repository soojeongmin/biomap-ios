import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    let refreshID: Int
    var onNavigate: (NotifDestination) -> Void = { _ in }
    @EnvironmentObject private var auth: AuthService

    @State private var allObservations: [Observation] = []
    @State private var missionXp = 0
    @State private var appUser: AppUser?
    @State private var team: Team?
    @State private var galleryTarget: GalleryTarget?
    @State private var showSettings = false
    @State private var showEditName = false
    @State private var showNameTaken = false
    @State private var showNameInsufficient = false
    @State private var showCustomize = false
    @State private var newName = ""
    @State private var nameOverride: String?
    @State private var notifications: [AppNotification] = []
    @State private var unreadCount = 0
    @State private var showNotifications = false
    @State private var showGuild = false

    private var uid: String? { auth.user?.uid }
    private var myObservations: [Observation] { allObservations.filter { $0.userId == uid } }

    private var speciesCount: Int {
        Set(myObservations.map { $0.speciesName }.filter { !$0.isEmpty }).count
    }
    private var xp: Int { Stats.calculateXp(all: allObservations, mine: myObservations, uid: uid) + missionXp }
    private var level: Int { Stats.level(xp) }
    private var days: Int { Stats.daysSince(auth.user?.metadata.creationDate) }

    private var displayName: String {
        nameOverride
            ?? (appUser?.name).flatMap { $0.isEmpty ? nil : $0 }
            ?? auth.user?.displayName ?? auth.user?.email ?? ""
    }

    var body: some View {
        GeometryReader { geo in
        ScrollView {
            VStack(spacing: 20) {
                header(topInset: geo.safeAreaInsets.top)
                ProfileStatsView(speciesCount: speciesCount, days: days, level: level, xp: xp)
                ProfileObservationsView(observations: myObservations) { galleryTarget = GalleryTarget(key: $0) }
            }
            .padding(.bottom, 24)
        }
        .appBackground()
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 10) {
                circleButton("wand.and.stars", tint: .primary) { showCustomize = true }
                circleButton(unreadCount > 0 ? "bell.badge.fill" : "bell.fill", tint: unreadCount > 0 ? Color.brand : .primary) {
                    if let uid { Task { notifications = await NotificationRepository.getAll(uid) } }
                    showNotifications = true
                }
                circleButton("gearshape.fill", tint: .primary) { showSettings = true }
            }
            .padding(.trailing, 10)
            .padding(.top, 4)
        }
        .sheet(isPresented: $showNotifications, onDismiss: {
            Task { if let uid { await NotificationRepository.markAllRead(uid); unreadCount = 0 } }
        }) {
            NotificationListView(notifications: notifications, onDelete: { id in
                if let uid {
                    Task {
                        await NotificationRepository.delete(uid: uid, id: id)
                        notifications.removeAll { $0.id == id }
                    }
                }
            }, onNavigate: { dest in
                showNotifications = false
                onNavigate(dest)
            })
        }
        .task(id: refreshID) { await load() }
        .sheet(item: $galleryTarget) { t in
            GallerySheet(observations: t.key == galleryAllKey ? myObservations : myObservations.filter { $0.category == t.key })
        }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
        .fullScreenCover(isPresented: $showCustomize, onDismiss: { Task { await load() } }) {
            DecorView()
        }
        .alert("edit_nickname", isPresented: $showEditName) {
            TextField("nickname_hint", text: $newName)
            Button("cancel", role: .cancel) {}
            Button("save") {
                Task {
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty, trimmed != displayName else { return }
                    switch await UserRepository.renameNickname(trimmed) {
                    case nil: nameOverride = trimmed; await load()
                    case "taken": showNameTaken = true
                    default: showNameInsufficient = true
                    }
                }
            }
        } message: {
            if appUser?.nicknameChanged == false {
                Text("nickname_change_free")
            } else {
                Text(String(format: NSLocalizedString("nickname_change_cost", comment: ""), appUser?.coins ?? 0))
            }
        }
        .alert("nickname_taken", isPresented: $showNameTaken) {
            Button("confirm", role: .cancel) {}
        }
        .alert("nickname_insufficient", isPresented: $showNameInsufficient) {
            Button("confirm", role: .cancel) {}
        }
        }
    }

    private var avatarBlock: some View {
        ZStack {
            EmojiAvatar(
                emoji: appUser?.avatarEmoji ?? "",
                name: displayName,
                bg: (appUser?.avatarBg).flatMap { $0.isEmpty ? nil : $0 } ?? ProfileDecor.defaultBg,
                size: 150, fontSize: 84,
                effect: (appUser?.avatarEffect).flatMap { $0.isEmpty ? nil : $0 } ?? "none",
                photoUrl: appUser?.avatarPhoto ?? ""
            )
            if let team {
                GuildBorderRing(borderId: team.borderId ?? "white", borderColor: team.borderColor ?? "#FFFFFF", size: 150 * 1.45)
            }
        }
        .frame(width: 150 * 1.45, height: 150 * 1.45)
    }

    private func circleButton(_ symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .glassCircle()
        }
        .buttonStyle(.plain)
    }

    private func header(topInset: CGFloat) -> some View {
        VStack(spacing: 12) {
            if appUser == nil {
                ProgressView().frame(width: 150, height: 170).padding(.top, topInset + 52)
            } else if let h = appUser?.avatarHeader, !h.isEmpty {
                ZStack(alignment: .top) {
                    Color(.tertiarySystemFill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 170 + topInset)
                        .overlay {
                            AsyncImage(url: URL(string: h)) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color(.tertiarySystemFill)
                            }
                        }
                        .clipped()
                        .contentShape(Rectangle())
                    avatarBlock.padding(.top, 170 + topInset - (150 * 1.45) / 2)
                }
            } else {
                avatarBlock.padding(.top, topInset + 52)
            }
            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    DecorNameText(text: displayName, token: (appUser?.avatarNameColor).flatMap { $0.isEmpty ? nil : $0 } ?? ProfileDecor.defaultNameColor, font: .title3.weight(.semibold))
                    Button { newName = displayName; showEditName = true } label: {
                        Image(systemName: "pencil").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if let team {
                    Button { showGuild = true } label: {
                        HStack(spacing: 4) {
                            if uid == team.ownerId {
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
                if let email = auth.user?.email {
                    Text(email).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }


    private func load() async {
        allObservations = await ObservationRepository.getAll()
        if let uid {
            let user = await UserRepository.getUser(uid)
            appUser = user
            team = (user?.teamId).flatMap { $0.isEmpty ? nil : $0 } != nil ? await TeamRepository.getTeam(user!.teamId) : nil
            missionXp = user?.missionXp ?? 0
            unreadCount = await NotificationRepository.unreadCount(uid)
        }
    }
}

struct NotificationListView: View {
    let notifications: [AppNotification]
    let onDelete: (String) -> Void
    var onNavigate: (NotifDestination) -> Void = { _ in }

    var body: some View {
        NavigationStack {
            Group {
                if notifications.isEmpty {
                    ContentUnavailableView {
                        Label("notifications_empty", systemImage: "bell.slash")
                    }
                } else {
                    List {
                        ForEach(notifications) { n in
                            Button {
                                if let dest = n.destination { onNavigate(dest) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(message(n)).font(.subheadline).foregroundStyle(.primary)
                                        Text(relativeTime(n.createdAt)).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if n.destination != nil {
                                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                            .listRowBackground(n.read ? Color(.systemBackground) : Color.brand.opacity(0.08))
                        }
                        .onDelete { idx in idx.map { notifications[$0].id }.forEach(onDelete) }
                    }
                }
            }
            .navigationTitle(Text("notifications_title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .adaptiveDetents()
    }

    private func message(_ n: AppNotification) -> String {
        switch n.type {
        case AppNotification.typeFriend:
            return String(format: NSLocalizedString("notif_friend", comment: ""), n.fromName)
        case AppNotification.typeFriendRequest:
            return String(format: NSLocalizedString("notif_friend_request", comment: ""), n.fromName)
        case AppNotification.typeFriendAccepted:
            return String(format: NSLocalizedString("notif_friend_accepted", comment: ""), n.fromName)
        case AppNotification.typeSuggestion:
            return String(format: NSLocalizedString("notif_suggestion", comment: ""), n.fromName, n.speciesName)
        case AppNotification.typeSuggestionAccepted:
            return String(format: NSLocalizedString("notif_suggestion_accepted", comment: ""), n.speciesName)
        case AppNotification.typeComment:
            return String(format: NSLocalizedString("notif_comment", comment: ""), n.fromName)
        case "guild_request":
            return String(format: NSLocalizedString("notif_guild_request", comment: ""), n.fromName, n.speciesName)
        case "guild_approved":
            return String(format: NSLocalizedString("notif_guild_approved", comment: ""), n.speciesName)
        case "guild_transferred":
            return String(format: NSLocalizedString("notif_guild_transferred", comment: ""), n.speciesName)
        case "guild_kicked":
            return String(format: NSLocalizedString("notif_guild_kicked", comment: ""), n.speciesName)
        case "rank_overtake":
            return String(format: NSLocalizedString("notif_rank_overtake", comment: ""), n.fromName)
        case "duel_challenge":
            return String(format: NSLocalizedString("notif_duel_challenge", comment: ""), n.fromName, n.speciesName)
        case "duel_accepted":
            return String(format: NSLocalizedString("notif_duel_accepted", comment: ""), n.fromName)
        case "duel_declined":
            return String(format: NSLocalizedString("notif_duel_declined", comment: ""), n.fromName)
        case "duel_won":
            return String(format: NSLocalizedString("notif_duel_won", comment: ""), n.speciesName)
        case "duel_lost":
            return NSLocalizedString("notif_duel_lost", comment: "")
        case "duel_draw":
            return NSLocalizedString("notif_duel_draw", comment: "")
        case "duel_lead_up":
            return NSLocalizedString("notif_duel_lead_up", comment: "")
        case "duel_lead_down":
            return NSLocalizedString("notif_duel_lead_down", comment: "")
        case "gduel_challenge":
            return String(format: NSLocalizedString("notif_gduel_challenge", comment: ""), n.fromName)
        case "gduel_accepted":
            return String(format: NSLocalizedString("notif_gduel_accepted", comment: ""), n.fromName)
        case "gduel_declined":
            return String(format: NSLocalizedString("notif_gduel_declined", comment: ""), n.fromName)
        case "gduel_won":
            return String(format: NSLocalizedString("notif_gduel_won", comment: ""), n.speciesName)
        case "gduel_lost":
            return NSLocalizedString("notif_gduel_lost", comment: "")
        case "gduel_draw":
            return NSLocalizedString("notif_gduel_draw", comment: "")
        case "gduel_lead_up":
            return NSLocalizedString("notif_gduel_lead_up", comment: "")
        case "gduel_lead_down":
            return NSLocalizedString("notif_gduel_lead_down", comment: "")
        default:
            return n.fromName
        }
    }

    private func relativeTime(_ millis: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(millis) / 1000)
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
