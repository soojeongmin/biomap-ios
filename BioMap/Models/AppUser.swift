import Foundation

struct AppUser: Codable, Identifiable, Hashable {
    var uid: String = ""
    var name: String = ""
    var photoUrl: String = ""
    var teamId: String = ""
    var teamJoinedAt: Int64 = 0
    var pendingTeamId: String = ""
    var createdAt: Int64 = 0
    var nicknameChanged: Bool = false
    var missionXp: Int = 0
    var coins: Int = 0
    var owned: [String] = []
    var equipped: [String: String] = [:]
    var colors: [String: String] = [:]
    var avatarUrl: String = ""
    var avatarHash: String = ""
    var avatarMode: String = "model"
    var avatarEmoji: String = ""
    var avatarBg: String = ""
    var avatarPhoto: String = ""
    var avatarHeader: String = ""
    var headerEverSet: Bool = false
    var ownedEmojis: [String] = []
    var ownedBgs: [String] = []
    var avatarEffect: String = "none"
    var avatarNameColor: String = ""
    var ownedEffects: [String] = []
    var ownedNameColors: [String] = []
    var blockedUids: [String] = []
    var guildChatMuted: Bool = false
    var dmMuted: Bool = false
    var streak: Int = 0

    var id: String { uid }

    init(uid: String = "", name: String = "", photoUrl: String = "", teamId: String = "",
         teamJoinedAt: Int64 = 0,
         pendingTeamId: String = "",
         createdAt: Int64 = 0, nicknameChanged: Bool = false, missionXp: Int = 0, coins: Int = 0, owned: [String] = [],
         equipped: [String: String] = [:], colors: [String: String] = [:],
         avatarUrl: String = "", avatarHash: String = "",
         avatarMode: String = "model", avatarEmoji: String = "", avatarBg: String = "",
         avatarPhoto: String = "", avatarHeader: String = "", headerEverSet: Bool = false,
         ownedEmojis: [String] = [], ownedBgs: [String] = [],
         avatarEffect: String = "none", avatarNameColor: String = "",
         ownedEffects: [String] = [], ownedNameColors: [String] = [],
         blockedUids: [String] = [], guildChatMuted: Bool = false, dmMuted: Bool = false, streak: Int = 0) {
        self.uid = uid; self.name = name; self.photoUrl = photoUrl; self.teamId = teamId
        self.teamJoinedAt = teamJoinedAt
        self.pendingTeamId = pendingTeamId
        self.createdAt = createdAt; self.nicknameChanged = nicknameChanged
        self.missionXp = missionXp; self.coins = coins
        self.owned = owned; self.equipped = equipped; self.colors = colors
        self.avatarUrl = avatarUrl; self.avatarHash = avatarHash
        self.avatarMode = avatarMode; self.avatarEmoji = avatarEmoji; self.avatarBg = avatarBg
        self.avatarPhoto = avatarPhoto
        self.avatarHeader = avatarHeader; self.headerEverSet = headerEverSet
        self.ownedEmojis = ownedEmojis; self.ownedBgs = ownedBgs
        self.avatarEffect = avatarEffect; self.avatarNameColor = avatarNameColor
        self.ownedEffects = ownedEffects; self.ownedNameColors = ownedNameColors
        self.blockedUids = blockedUids
        self.guildChatMuted = guildChatMuted
        self.dmMuted = dmMuted
        self.streak = streak
    }

    init(firestore d: [String: Any], id: String) {
        self.init(
            uid: d["uid"] as? String ?? id,
            name: d["name"] as? String ?? "",
            photoUrl: d["photoUrl"] as? String ?? "",
            teamId: d["teamId"] as? String ?? "",
            teamJoinedAt: (d["teamJoinedAt"] as? NSNumber)?.int64Value ?? 0,
            pendingTeamId: d["pendingTeamId"] as? String ?? "",
            createdAt: (d["createdAt"] as? NSNumber)?.int64Value ?? 0,
            nicknameChanged: d["nicknameChanged"] as? Bool ?? false,
            missionXp: (d["missionXp"] as? NSNumber)?.intValue ?? 0,
            coins: (d["coins"] as? NSNumber)?.intValue ?? 0,
            owned: d["owned"] as? [String] ?? [],
            equipped: d["equipped"] as? [String: String] ?? [:],
            colors: d["colors"] as? [String: String] ?? [:],
            avatarUrl: d["avatarUrl"] as? String ?? "",
            avatarHash: d["avatarHash"] as? String ?? "",
            avatarMode: d["avatarMode"] as? String ?? "model",
            avatarEmoji: d["avatarEmoji"] as? String ?? "",
            avatarBg: d["avatarBg"] as? String ?? "",
            avatarPhoto: d["avatarPhoto"] as? String ?? "",
            avatarHeader: d["avatarHeader"] as? String ?? "",
            headerEverSet: d["headerEverSet"] as? Bool ?? false,
            ownedEmojis: d["ownedEmojis"] as? [String] ?? [],
            ownedBgs: d["ownedBgs"] as? [String] ?? [],
            avatarEffect: d["avatarEffect"] as? String ?? "none",
            avatarNameColor: d["avatarNameColor"] as? String ?? "",
            ownedEffects: d["ownedEffects"] as? [String] ?? [],
            ownedNameColors: d["ownedNameColors"] as? [String] ?? [],
            blockedUids: d["blockedUids"] as? [String] ?? [],
            guildChatMuted: d["guildChatMuted"] as? Bool ?? false,
            dmMuted: d["dmMuted"] as? Bool ?? false,
            streak: (d["streak"] as? NSNumber)?.intValue ?? 0
        )
    }
}
