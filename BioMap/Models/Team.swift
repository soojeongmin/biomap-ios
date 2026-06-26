import Foundation

struct Team: Codable, Identifiable, Hashable {
    var id: String = ""
    var name: String = ""
    var description: String? = ""
    var code: String = ""
    var ownerId: String = ""
    var ownerName: String = ""
    var autoAccept: Bool? = false
    var createdAt: Int64 = 0
    var borderId: String? = "white"
    var borderColor: String? = "#FFFFFF"
    var ownedBorders: [String]? = []
    var borderSpent: Int? = 0
    var guildCoins: Int? = 0
    var weeklyProgress: [String: Int]? = [:]
    var weeklyGoal: [String: Int]? = [:]
    var weekKey: String? = ""
    var weeklyRewarded: [String]? = []
    var pinnedText: String? = ""
    var pinnedBy: String? = ""
    var pinnedAt: Int64? = 0
}

struct JoinRequest: Identifiable, Hashable {
    let id: String
    let name: String
}
