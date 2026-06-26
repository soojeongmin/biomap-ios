import Foundation
import FirebaseFirestore
import FirebaseFunctions

struct GuildDuel: Identifiable, Hashable {
    var id = ""
    var aTeam = ""
    var bTeam = ""
    var aName = ""
    var bName = ""
    var aOwner = ""
    var bOwner = ""
    var stake = 0
    var metric = "obs"
    var durationDays = 1
    var status = ""
    var createdAt: Int64 = 0
    var startAt: Int64 = 0
    var endAt: Int64 = 0
    var aScore = 0
    var bScore = 0
    var aEscrow = 0
    var bEscrow = 0
    var winner = ""

    init(firestore d: [String: Any], id: String) {
        self.id = id
        aTeam = d["aTeam"] as? String ?? ""
        bTeam = d["bTeam"] as? String ?? ""
        aName = d["aName"] as? String ?? ""
        bName = d["bName"] as? String ?? ""
        aOwner = d["aOwner"] as? String ?? ""
        bOwner = d["bOwner"] as? String ?? ""
        stake = (d["stake"] as? NSNumber)?.intValue ?? 0
        metric = d["metric"] as? String ?? "obs"
        durationDays = (d["durationDays"] as? NSNumber)?.intValue ?? 1
        status = d["status"] as? String ?? ""
        createdAt = (d["createdAt"] as? NSNumber)?.int64Value ?? 0
        startAt = (d["startAt"] as? NSNumber)?.int64Value ?? 0
        endAt = (d["endAt"] as? NSNumber)?.int64Value ?? 0
        aScore = (d["aScore"] as? NSNumber)?.intValue ?? 0
        bScore = (d["bScore"] as? NSNumber)?.intValue ?? 0
        aEscrow = (d["aEscrow"] as? NSNumber)?.intValue ?? 0
        bEscrow = (d["bEscrow"] as? NSNumber)?.intValue ?? 0
        winner = d["winner"] as? String ?? ""
    }

    var pot: Int { aEscrow + bEscrow }
    func myName(_ team: String) -> String { aTeam == team ? aName : bName }
    func oppName(_ team: String) -> String { aTeam == team ? bName : aName }
    func myScore(_ team: String) -> Int { aTeam == team ? aScore : bScore }
    func theirScore(_ team: String) -> Int { aTeam == team ? bScore : aScore }
    func oppTeam(_ team: String) -> String { aTeam == team ? bTeam : aTeam }
}

final class GuildDuelStore: ObservableObject {
    @Published var duels: [GuildDuel] = []
    private var listener: ListenerRegistration?

    func start(teamId: String) {
        guard listener == nil, !teamId.isEmpty else { return }
        listener = Firestore.firestore().collection("guildDuels").whereField("pair", arrayContains: teamId)
            .addSnapshotListener { [weak self] snap, _ in
                self?.duels = (snap?.documents ?? [])
                    .map { GuildDuel(firestore: $0.data(), id: $0.documentID) }
                    .sorted { $0.createdAt > $1.createdAt }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }
}

enum GuildDuelRepository {
    static func create(opponentTeamId: String, stake: Int, metric: String, durationDays: Int) async -> String? {
        do {
            _ = try await Functions.functions().httpsCallable("createGuildDuel").call([
                "opponentTeamId": opponentTeamId, "stake": stake, "metric": metric, "durationDays": durationDays,
            ])
            return nil
        } catch {
            let ns = error as NSError
            if ns.domain == FunctionsErrorDomain && ns.code == FunctionsErrorCode.alreadyExists.rawValue {
                return NSLocalizedString("duel_exists", comment: "")
            }
            return NSLocalizedString("duel_failed", comment: "")
        }
    }

    static func respond(duelId: String, accept: Bool) async {
        _ = try? await Functions.functions().httpsCallable("respondGuildDuel").call(["duelId": duelId, "accept": accept])
    }

    static func cancel(duelId: String) async {
        _ = try? await Functions.functions().httpsCallable("cancelGuildDuel").call(["duelId": duelId])
    }
}
