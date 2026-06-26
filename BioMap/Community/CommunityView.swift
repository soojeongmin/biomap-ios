import SwiftUI
import FirebaseAuth

struct CommunityView: View {
    let refreshID: Int
    var externalTab: Binding<Int>? = nil
    var requestChat: Binding<Bool>? = nil
    var requestDuels: Binding<Bool>? = nil
    var requestDmPeer: Binding<String?>? = nil
    @State private var tab = 2

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SectionTab(title: "team_title", selected: tab == 2) { tab = 2 }
                    .frame(maxWidth: .infinity)
                SectionTab(title: "friends_title", selected: tab == 1) { tab = 1 }
                    .frame(maxWidth: .infinity)
                SectionTab(title: "tab_ranking", selected: tab == 0) { tab = 0 }
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            Divider()

            switch tab {
            case 0: RankingView(refreshID: refreshID)
            case 1: FriendsView(refreshID: refreshID, requestDuels: requestDuels, requestDmPeer: requestDmPeer)
            default: TeamView(refreshID: refreshID, requestChat: requestChat)
            }
        }
        .appBackground()
        .onAppear { if let ext = externalTab?.wrappedValue { tab = ext } }
        .onChange(of: externalTab?.wrappedValue) { _, v in if let v { tab = v } }
    }
}

private struct SectionTab: View {
    let title: LocalizedStringKey
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(selected ? .bold : .regular))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                Capsule()
                    .fill(selected ? Color.brand : Color.clear)
                    .frame(width: 22, height: 2.5)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RankChip: View {
    let title: LocalizedStringKey
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title).glassPill(active: selected)
        }
        .buttonStyle(.plain)
    }
}

struct GuildBorderRing: View {
    let borderId: String
    let borderColor: String
    let size: CGFloat

    private var isWhite: Bool {
        let c = borderColor.trimmingCharacters(in: .whitespaces)
        return c.isEmpty || c.caseInsensitiveCompare("#FFFFFF") == .orderedSame || c.caseInsensitiveCompare("#FFF") == .orderedSame
    }

    var body: some View {
        if GuildBorders.procedural.contains(borderId) {
            ProceduralBorder(borderId: borderId, borderColor: borderColor, size: size)
        } else if let asset = GuildBorders.assetOf(borderId), let img = UIImage(named: asset) {
            Image(uiImage: img).resizable().scaledToFit()
                .frame(width: size, height: size)
                .colorMultiply(Color(uiColor: UIColor(hexString: borderColor) ?? .white))
        } else if !isWhite {
            Circle()
                .stroke(Color(uiColor: UIColor(hexString: borderColor) ?? .white), lineWidth: size * 0.06)
                .frame(width: size * 0.72, height: size * 0.72)
        }
    }
}

private func borderStarPath(_ center: CGPoint, _ outer: CGFloat, _ inner: CGFloat, _ rot: Double) -> Path {
    var p = Path()
    for i in 0..<10 {
        let rr = i % 2 == 0 ? outer : inner
        let a = rot + Double(i) * (.pi / 5) - .pi / 2
        let pt = CGPoint(x: center.x + cos(a) * rr, y: center.y + sin(a) * rr)
        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
    }
    p.closeSubpath()
    return p
}

private func borderDiamondPath(_ c: CGPoint, _ r: CGFloat) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: c.x, y: c.y - r))
    p.addLine(to: CGPoint(x: c.x + r, y: c.y))
    p.addLine(to: CGPoint(x: c.x, y: c.y + r))
    p.addLine(to: CGPoint(x: c.x - r, y: c.y))
    p.closeSubpath()
    return p
}

struct ProceduralBorder: View {
    let borderId: String
    var borderColor: String = "#FFFFFF"
    let size: CGFloat

    private func col(_ hex: String) -> Color { Color(uiColor: UIColor(hexString: hex) ?? .white) }
    private var tint: Color {
        let c = borderColor.trimmingCharacters(in: .whitespaces)
        let isWhite = c.isEmpty || c.caseInsensitiveCompare("#FFFFFF") == .orderedSame || c.caseInsensitiveCompare("#FFF") == .orderedSame
        if isWhite { return Color.brand }
        return Color(uiColor: UIColor(hexString: c) ?? .white)
    }

    var body: some View {
        Canvas { ctx, sz in
            let d = min(sz.width, sz.height)
            let r = d * 0.37
            let sw = d * 0.08
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
            func stud(_ n: Int, _ radius: CGFloat, _ draw: (CGPoint, Double, Int) -> Void) {
                for i in 0..<n {
                    let a = Double(i) / Double(n) * 2 * .pi - .pi / 2
                    draw(CGPoint(x: c.x + cos(a) * radius, y: c.y + sin(a) * radius), a, i)
                }
            }
            func ringPath(_ radius: CGFloat) -> Path {
                var p = Path()
                p.addArc(center: c, radius: radius, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                return p
            }
            func rotated(_ path: Path, _ around: CGPoint, _ angle: Double) -> Path {
                path.applying(CGAffineTransform(translationX: around.x, y: around.y)
                    .rotated(by: angle)
                    .translatedBy(x: -around.x, y: -around.y))
            }
            let ring = ringPath(r)
            switch borderId {
            case "rainbow":
                let colors = ["#FF5F6D", "#FFC371", "#47E891", "#36D1DC", "#5B86E5", "#C471ED", "#FF5F6D"].map(col)
                ctx.stroke(ring, with: .conicGradient(Gradient(colors: colors), center: c), lineWidth: sw)
            case "ocean":
                let colors = ["#1FB6C9", "#2B6FE0", "#23D6B0", "#1FB6C9"].map(col)
                ctx.stroke(ring, with: .conicGradient(Gradient(colors: colors), center: c), lineWidth: sw)
            case "bee":
                let seg = 14
                for i in 0..<seg {
                    var arc = Path()
                    arc.addArc(center: c, radius: r,
                               startAngle: .degrees(Double(i) * 360.0 / Double(seg)),
                               endAngle: .degrees(Double(i + 1) * 360.0 / Double(seg)), clockwise: false)
                    ctx.stroke(arc, with: .color(i % 2 == 0 ? col("#FBBF24") : col("#1A1A1A")), lineWidth: sw)
                }
            case "frost":
                ctx.stroke(ring, with: .color(col("#67E8F9").opacity(0.4)), lineWidth: sw)
                ctx.stroke(ring, with: .color(col("#A5F3FC")),
                           style: StrokeStyle(lineWidth: sw * 0.7, dash: [d * 0.07, d * 0.05]))
            case "star":
                stud(8, r) { p, a, _ in
                    ctx.fill(borderStarPath(p, sw * 0.95, sw * 0.42, a + .pi / 2), with: .color(tint))
                }
            case "neon":
                ctx.stroke(ring, with: .color(tint.opacity(0.28)), lineWidth: sw * 1.8)
                ctx.stroke(ring, with: .color(tint), lineWidth: sw * 0.5)
            case "double":
                ctx.stroke(ringPath(r * 1.12), with: .color(tint), lineWidth: sw * 0.55)
                ctx.stroke(ringPath(r * 0.88), with: .color(tint.opacity(0.6)), lineWidth: sw * 0.55)
            case "gear":
                ctx.stroke(ring, with: .color(tint), lineWidth: sw * 0.8)
                stud(12, r) { p, a, _ in
                    let sq = Path(roundedRect: CGRect(x: p.x - sw * 0.45, y: p.y - sw * 0.45, width: sw * 0.9, height: sw * 0.9), cornerRadius: sw * 0.15)
                    ctx.fill(rotated(sq, p, a), with: .color(tint))
                }
            case "gem":
                stud(8, r) { p, _, _ in ctx.fill(borderDiamondPath(p, sw * 0.7), with: .color(tint)) }
            case "bubble":
                stud(13, r) { p, _, i in
                    let rad = sw * (0.32 + CGFloat(i % 3) * 0.18)
                    let dot = Path(ellipseIn: CGRect(x: p.x - rad, y: p.y - rad, width: rad * 2, height: rad * 2))
                    ctx.fill(dot, with: .color(tint.opacity(0.65 + Double(i % 3) * 0.12)))
                }
            case "bacteria":
                let rr = d * 0.36
                let knob = d * 0.028
                ctx.stroke(ringPath(rr), with: .color(tint), lineWidth: d * 0.024)
                stud(14, d * 0.45) { p, a, _ in
                    let inner = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
                    let end = CGPoint(x: p.x - cos(a) * knob, y: p.y - sin(a) * knob)
                    var stem = Path()
                    stem.move(to: inner)
                    stem.addLine(to: end)
                    ctx.stroke(stem, with: .color(tint), style: StrokeStyle(lineWidth: d * 0.020, lineCap: .round))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - knob, y: p.y - knob, width: knob * 2, height: knob * 2)), with: .color(tint))
                }
            case "phage":
                let hr = d * 0.41
                var head = Path()
                for k in 0..<6 {
                    let ang = .pi / 6 + Double(k) * .pi / 3
                    let pt = CGPoint(x: c.x + cos(ang) * hr, y: c.y + sin(ang) * hr)
                    if k == 0 { head.move(to: pt) } else { head.addLine(to: pt) }
                }
                head.closeSubpath()
                ctx.stroke(head, with: .color(tint), style: StrokeStyle(lineWidth: d * 0.022, lineJoin: .round))
                let attachY = c.y + hr
                let baseY = attachY + d * 0.025
                var tail = Path()
                tail.move(to: CGPoint(x: c.x, y: attachY)); tail.addLine(to: CGPoint(x: c.x, y: baseY))
                ctx.stroke(tail, with: .color(tint), style: StrokeStyle(lineWidth: d * 0.022, lineCap: .round))
                var plate = Path()
                plate.move(to: CGPoint(x: c.x - d * 0.05, y: baseY)); plate.addLine(to: CGPoint(x: c.x + d * 0.05, y: baseY))
                ctx.stroke(plate, with: .color(tint), style: StrokeStyle(lineWidth: d * 0.022, lineCap: .round))
                for fr in [-0.16, -0.09, -0.03, 0.03, 0.09, 0.16] as [CGFloat] {
                    let f = fr * d
                    var leg = Path()
                    leg.move(to: CGPoint(x: c.x + f * 0.22, y: baseY))
                    leg.addLine(to: CGPoint(x: c.x + f * 0.62, y: baseY - d * 0.022))
                    leg.addLine(to: CGPoint(x: c.x + f, y: baseY + d * 0.045))
                    ctx.stroke(leg, with: .color(tint), style: StrokeStyle(lineWidth: d * 0.018, lineCap: .round, lineJoin: .round))
                }
            default:
                break
            }
        }
        .frame(width: size, height: size)
    }
}

private struct TeamRef: Identifiable {
    let id: String
}

private struct RankEntry: Identifiable {
    let id: String
    let name: String
    let count: Int
    let emoji: String
    let bg: String
    var borderId: String = "white"
    var borderColor: String = "#FFFFFF"
    var nameColor: String = ProfileDecor.defaultNameColor
    var effect: String = "none"
    var photo: String = ""
}

private let pageSize = 10
private let gold = Color(red: 1.0, green: 0.78, blue: 0.24)
private let silver = Color(red: 0.75, green: 0.77, blue: 0.80)
private let bronze = Color(red: 0.82, green: 0.55, blue: 0.31)

private func medalColor(_ rank: Int) -> Color {
    switch rank {
    case 1: return gold
    case 2: return silver
    default: return bronze
    }
}

private func medalGradient(_ rank: Int) -> LinearGradient {
    let base = medalColor(rank)
    return LinearGradient(
        colors: [base.opacity(0.95), base.opacity(0.65)],
        startPoint: .top, endPoint: .bottom
    )
}

private struct RankingView: View {
    let refreshID: Int

    @State private var observations: [Observation] = []
    @State private var users: [AppUser] = []
    @State private var teams: [Team] = []
    @State private var loading = true
    @State private var page = 0
    @State private var teamMode = false
    @State private var weeklyMode = true
    @State private var nearbyMode = false
    @State private var friendsMode = false
    @State private var friendUids: Set<String> = []
    @State private var selectedUser: UserRef?
    @State private var selectedTeam: TeamRef?
    @State private var hofList: [HallOfFameEntry] = []

    private var weekStartMillis: Int64 {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = .current
        let start = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return Int64(start.timeIntervalSince1970 * 1000)
    }
    private var scopedObs: [Observation] {
        weeklyMode ? observations.filter { $0.timestamp >= weekStartMillis } : observations
    }

    private var speciesCountByUid: [String: Int] {
        Dictionary(grouping: scopedObs.filter { !$0.userId.isEmpty }, by: { $0.userId })
            .mapValues { Set($0.map { $0.speciesName }.filter { !$0.isEmpty }).count }
    }
    private var nameByUid: [String: String] {
        Dictionary(users.map { ($0.uid, $0.name) }, uniquingKeysWith: { a, _ in a })
    }
    private var emojiByUid: [String: String] {
        Dictionary(users.map { ($0.uid, $0.avatarEmoji) }, uniquingKeysWith: { a, _ in a })
    }
    private var bgByUid: [String: String] {
        Dictionary(users.map { ($0.uid, $0.avatarBg) }, uniquingKeysWith: { a, _ in a })
    }
    private var nameColorByUid: [String: String] {
        Dictionary(users.map { ($0.uid, $0.avatarNameColor) }, uniquingKeysWith: { a, _ in a })
    }
    private var effectByUid: [String: String] {
        Dictionary(users.map { ($0.uid, $0.avatarEffect) }, uniquingKeysWith: { a, _ in a })
    }
    private var photoByUid: [String: String] {
        Dictionary(users.map { ($0.uid, $0.avatarPhoto) }, uniquingKeysWith: { a, _ in a })
    }
    private var borderByUid: [String: (String, String)] {
        let teamById = Dictionary(teams.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return Dictionary(users.map { u -> (String, (String, String)) in
            let t = teamById[u.teamId]
            return (u.uid, (t?.borderId ?? "white", t?.borderColor ?? "#FFFFFF"))
        }, uniquingKeysWith: { a, _ in a })
    }

    private var individualRanking: [RankEntry] {
        let valid = scopedObs.filter { !$0.userId.isEmpty }
        return Dictionary(grouping: valid, by: { $0.userId })
            .filter { nameByUid.isEmpty || nameByUid[$0.key] != nil }
            .map { uid, list in
                let name = nameByUid[uid].flatMap { $0.isEmpty ? nil : $0 }
                    ?? (list.first?.userName.isEmpty == false ? list.first!.userName : "—")
                let border = borderByUid[uid] ?? ("white", "#FFFFFF")
                return RankEntry(id: uid, name: name, count: speciesCountByUid[uid] ?? 0,
                                 emoji: emojiByUid[uid] ?? "", bg: bgByUid[uid] ?? ProfileDecor.defaultBg,
                                 borderId: border.0, borderColor: border.1,
                                 nameColor: nameColorByUid[uid].flatMap { $0.isEmpty ? nil : $0 } ?? ProfileDecor.defaultNameColor,
                                 effect: effectByUid[uid].flatMap { $0.isEmpty ? nil : $0 } ?? "none",
                                 photo: photoByUid[uid] ?? "")
            }
            .sorted { $0.count > $1.count }
    }

    private var teamRanking: [RankEntry] {
        let sc = speciesCountByUid
        return teams.compactMap { team -> RankEntry? in
            let members = users.filter { $0.teamId == team.id }
            guard !members.isEmpty else { return nil }
            let contribution = members.reduce(0) { $0 + (sc[$1.uid] ?? 0) }
            guard contribution > 0 else { return nil }
            let owner = members.first(where: { $0.uid == team.ownerId }) ?? members.first
            return RankEntry(id: team.id, name: team.name.isEmpty ? "—" : team.name, count: contribution,
                             emoji: owner?.avatarEmoji ?? "", bg: owner?.avatarBg ?? ProfileDecor.defaultBg,
                             borderId: team.borderId ?? "white", borderColor: team.borderColor ?? "#FFFFFF")
        }
        .sorted { $0.count > $1.count }
    }

    private func median(_ xs: [Double]) -> Double {
        let s = xs.sorted(); let n = s.count
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }
    private func medianPoint(_ pts: [(Double, Double)]) -> (Double, Double)? {
        guard !pts.isEmpty else { return nil }
        return (median(pts.map { $0.0 }), median(pts.map { $0.1 }))
    }
    private func homeOf(_ obs: [Observation]) -> (Double, Double)? {
        medianPoint(obs.filter { $0.latitude != 0 || $0.longitude != 0 }.map { ($0.latitude, $0.longitude) })
    }
    private func haversineKm(_ a: (Double, Double), _ b: (Double, Double)) -> Double {
        let r = 6371.0
        let dLat = (b.0 - a.0) * .pi / 180
        let dLon = (b.1 - a.1) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(a.0 * .pi / 180) * cos(b.0 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * atan2(sqrt(h), sqrt(1 - h))
    }
    private var homeByUid: [String: (Double, Double)] {
        Dictionary(grouping: observations.filter { !$0.userId.isEmpty }, by: { $0.userId })
            .compactMapValues { homeOf($0) }
    }
    private var viewerHome: (Double, Double)? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return homeByUid[uid]
    }
    private var teamHomeById: [String: (Double, Double)] {
        var result: [String: (Double, Double)] = [:]
        for team in teams {
            let homes = users.filter { $0.teamId == team.id }.compactMap { homeByUid[$0.uid] }
            if let h = medianPoint(homes) { result[team.id] = h }
        }
        return result
    }

    private var friendTeamIds: Set<String> {
        Set(users.filter { friendUids.contains($0.uid) }.map { $0.teamId }.filter { !$0.isEmpty })
    }

    private var ranking: [RankEntry] {
        let base = teamMode ? teamRanking : individualRanking
        if friendsMode {
            return teamMode
                ? base.filter { friendTeamIds.contains($0.id) }
                : base.filter { friendUids.contains($0.id) }
        }
        guard nearbyMode else { return base }
        guard let vh = viewerHome else { return [] }
        let homes = teamMode ? teamHomeById : homeByUid
        return base.filter { entry in
            guard let h = homes[entry.id] else { return false }
            return haversineKm(vh, h) <= 30
        }
    }

    private var rankByCount: [Int: Int] {
        var result: [Int: Int] = [:]
        for (index, count) in Array(Set(ranking.map { $0.count })).sorted(by: >).enumerated() {
            result[count] = index + 1
        }
        return result
    }

    private var totalPages: Int {
        ranking.isEmpty ? 1 : (ranking.count + pageSize - 1) / pageSize
    }
    private var safePage: Int { min(max(page, 0), totalPages - 1) }
    private var pageItems: [RankEntry] {
        Array(ranking.dropFirst(safePage * pageSize).prefix(pageSize))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    RankChip(title: teamMode ? "team_title" : "ranking_individual", selected: true) { teamMode.toggle() }
                    Divider().frame(height: 20)
                    RankChip(title: weeklyMode ? "ranking_weekly" : "ranking_all", selected: true) { weeklyMode.toggle() }
                    Divider().frame(height: 20)
                    RankChip(title: "ranking_global", selected: !nearbyMode && !friendsMode) { nearbyMode = false; friendsMode = false }
                    RankChip(title: "ranking_nearby", selected: nearbyMode && !friendsMode) { nearbyMode = true; friendsMode = false }
                    RankChip(title: "ranking_friends", selected: friendsMode) { friendsMode = true; nearbyMode = false }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)
            }

            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if ranking.isEmpty {
                Text("ranking_empty").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        hallOfFameCard
                        Podium(ranking: ranking, rankByCount: rankByCount) {
                            if teamMode { selectedTeam = TeamRef(id: $0.id) } else { selectedUser = $0 }
                        }
                            .padding(.vertical, 16)
                        ForEach(pageItems) { entry in
                            RankRow(rank: rankByCount[entry.count] ?? 0, entry: entry) {
                                if teamMode { selectedTeam = TeamRef(id: entry.id) }
                                else { selectedUser = UserRef(id: entry.id, name: entry.name) }
                            }
                        }
                        if totalPages > 1 {
                            PageNav(page: safePage, totalPages: totalPages,
                                    onPrev: { page = max(safePage - 1, 0) },
                                    onNext: { page = min(safePage + 1, totalPages - 1) })
                        }
                    }
                    .padding(16)
                }
            }
        }
        .task(id: refreshID) { await load() }
        .onChange(of: teamMode) { _, _ in page = 0 }
        .onChange(of: weeklyMode) { _, _ in page = 0 }
        .onChange(of: nearbyMode) { _, _ in page = 0 }
        .onChange(of: friendsMode) { _, _ in page = 0 }
        .sheet(item: $selectedTeam) { ref in
            GuildPreviewSheet(teamId: ref.id).largeSheet()
        }
        .sheet(item: $selectedUser) { ref in
            UserProfileSheet(userId: ref.id, userName: ref.name)
                .largeSheet()
        }
    }

    private func load() async {
        loading = true
        observations = await ObservationRepository.getAll()
        users = await UserRepository.getAllUsers()
        teams = await TeamRepository.getAllTeams()
        if let uid = Auth.auth().currentUser?.uid {
            friendUids = Set(await UserRepository.getFriends(uid).map { $0.uid } + [uid])
        }
        hofList = await ObservationRepository.recentHallOfFame(limit: 2)
        page = 0
        loading = false
    }

    private func weeksAgoLabel(_ weekStart: Int64) -> String {
        let week = 7.0 * 24 * 60 * 60 * 1000
        let n = max(1, Int(((Double(weekStartMillis) - Double(weekStart)) / week).rounded()))
        return localizedFormat("hof_weeks_ago", n)
    }

    @ViewBuilder private var hallOfFameCard: some View {
        if !hofList.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                    Text("hall_of_fame").font(.headline)
                    Spacer()
                    Text(teamMode ? "team_title" : "ranking_individual")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(hofList.enumerated()), id: \.offset) { _, entry in
                    let winner = teamMode ? entry.topGuild : entry.topUser
                    hofRow(weeksAgoLabel(entry.weekStart), name: winner?.name, count: winner?.count)
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    private func hofRow(_ title: String, name: String?, count: Int?) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.subheadline).foregroundStyle(.secondary).frame(width: 56, alignment: .leading)
            Text((name?.isEmpty == false) ? name! : "—").font(.subheadline.weight(.semibold)).lineLimit(1)
            Spacer(minLength: 8)
            if let count, count > 0 {
                Text(localizedFormat("rank_unit", count)).font(.subheadline).foregroundStyle(Color.brand)
            }
        }
    }
}

private struct Podium: View {
    let ranking: [RankEntry]
    let rankByCount: [Int: Int]
    let onSelect: (UserRef) -> Void

    private func entries(_ rank: Int) -> [RankEntry] {
        ranking.filter { rankByCount[$0.count] == rank }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            PodiumColumn(rank: 2, entries: Array(entries(2).prefix(2)), onSelect: onSelect)
            PodiumColumn(rank: 1, entries: Array(entries(1).prefix(2)), onSelect: onSelect)
            PodiumColumn(rank: 3, entries: Array(entries(3).prefix(2)), onSelect: onSelect)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PodiumColumn: View {
    let rank: Int
    let entries: [RankEntry]
    let onSelect: (UserRef) -> Void

    private var height: CGFloat { rank == 1 ? 104 : rank == 2 ? 76 : 58 }
    private var avatarSize: CGFloat {
        let tied = entries.count > 1
        if tied { return rank == 1 ? 46 : 40 }
        return rank == 1 ? 66 : 54
    }

    var body: some View {
        VStack(spacing: 8) {
            if rank == 1 {
                Image(systemName: "crown.fill")
                    .font(.title3).foregroundStyle(medalColor(1))
                    .shadow(color: medalColor(1).opacity(0.5), radius: 4, y: 1)
            }
            if entries.isEmpty {
                Circle().fill(Color(.tertiarySystemFill)).frame(width: avatarSize, height: avatarSize)
                Text("—").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    ForEach(entries) { entry in
                        Button { onSelect(UserRef(id: entry.id, name: entry.name)) } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    EmojiAvatar(emoji: entry.emoji, name: entry.name, bg: entry.bg, size: avatarSize, fontSize: avatarSize * 0.5, effect: entry.effect, photoUrl: entry.photo)
                                        .overlay(Circle().stroke(medalGradient(rank), lineWidth: 3))
                                        .shadow(color: medalColor(rank).opacity(0.35), radius: 5, y: 2)
                                    GuildBorderRing(borderId: entry.borderId, borderColor: entry.borderColor, size: avatarSize * 1.45)
                                }
                                .frame(width: avatarSize * 1.45, height: avatarSize * 1.45)
                                DecorNameText(text: entry.name, token: entry.nameColor, font: .caption.weight(.semibold)).lineLimit(1)
                                Text(localizedFormat("rank_unit", entry.count))
                                    .font(.caption2.weight(.medium)).foregroundStyle(Color.brand)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            ZStack {
                UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14)
                    .fill(medalGradient(rank))
                UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14)
                    .fill(.ultraThinMaterial.opacity(0.18))
                Text("\(rank)")
                    .font(.title2.weight(.heavy)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            }
            .frame(height: height)
            .shadow(color: medalColor(rank).opacity(0.3), radius: 6, y: 3)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RankRow: View {
    let rank: Int
    let entry: RankEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("\(rank)")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(rank <= 3 ? medalColor(rank) : Color.secondary)
                    .frame(width: 30)
                ZStack {
                    EmojiAvatar(emoji: entry.emoji, name: entry.name, bg: entry.bg, size: 40, fontSize: 22, effect: entry.effect, photoUrl: entry.photo)
                        .overlay(Circle().stroke(Color.brand.opacity(0.15), lineWidth: 1))
                    GuildBorderRing(borderId: entry.borderId, borderColor: entry.borderColor, size: 58)
                }
                .frame(width: 58, height: 58)
                DecorNameText(text: entry.name, token: entry.nameColor, font: .body.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(localizedFormat("rank_unit", entry.count))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.brand)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.brand.opacity(0.12)))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .glassCard(radius: 14)
        }
        .buttonStyle(.plain)
    }
}

private struct PageNav: View {
    let page: Int
    let totalPages: Int
    let onPrev: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrev) { Image(systemName: "chevron.left") }.disabled(page == 0)
            Text("\(page + 1) / \(totalPages)")
            Button(action: onNext) { Image(systemName: "chevron.right") }.disabled(page >= totalPages - 1)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}
