import Foundation

struct AppNotification: Identifiable, Codable {
    var id: String = ""
    var type: String = ""
    var fromName: String = ""
    var speciesName: String = ""
    var observationId: String = ""
    var read: Bool = false
    var createdAt: Int64 = 0

    static let typeSuggestion = "suggestion"
    static let typeSuggestionAccepted = "suggestion_accepted"
    static let typeFriend = "friend"
    static let typeFriendRequest = "friend_request"
    static let typeFriendAccepted = "friend_accepted"
    static let typeGuildRequest = "guild_request"
    static let typeGuildApproved = "guild_approved"
    static let typeGuildTransferred = "guild_transferred"
    static let typeGuildKicked = "guild_kicked"
    static let typeComment = "comment"

    var destination: NotifDestination? {
        switch type {
        case AppNotification.typeFriend, AppNotification.typeFriendRequest, AppNotification.typeFriendAccepted:
            return .friends
        case AppNotification.typeGuildRequest, AppNotification.typeGuildApproved, AppNotification.typeGuildTransferred, AppNotification.typeGuildKicked:
            return .guild
        case AppNotification.typeSuggestion, AppNotification.typeSuggestionAccepted, AppNotification.typeComment:
            return observationId.isEmpty ? nil : .observation(observationId)
        case "rank_overtake":
            return .ranking
        case "duel_challenge", "duel_accepted", "duel_declined", "duel_won", "duel_lost", "duel_draw",
             "duel_lead_up", "duel_lead_down":
            return .duels
        case "gduel_challenge", "gduel_accepted", "gduel_declined", "gduel_won", "gduel_lost", "gduel_draw",
             "gduel_lead_up", "gduel_lead_down":
            return .guild
        default:
            return nil
        }
    }
}

enum NotifDestination: Equatable {
    case friends
    case guild
    case guildChat
    case ranking
    case duels
    case dm(String)
    case observation(String)
    case add

    static func fromPush(route: String?, obs: String?, peer: String?) -> NotifDestination? {
        switch route {
        case "guild_chat": return .guildChat
        case "guild": return .guild
        case "friends": return .friends
        case "ranking": return .ranking
        case "duels": return .duels
        case "dm": return (peer?.isEmpty == false) ? .dm(peer!) : .friends
        case "observation": return (obs?.isEmpty == false) ? .observation(obs!) : nil
        default: return nil
        }
    }
}

final class NotifRouter: ObservableObject {
    static let shared = NotifRouter()
    @Published var destination: NotifDestination?
}
