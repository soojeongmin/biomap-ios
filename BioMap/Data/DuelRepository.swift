import Foundation
import FirebaseFirestore
import FirebaseFunctions

struct Duel: Identifiable, Hashable {
    var id: String = ""
    var aUid: String = ""
    var bUid: String = ""
    var aName: String = ""
    var bName: String = ""
    var stake: Int = 0
    var metric: String = "obs"
    var durationDays: Int = 1
    var status: String = ""
    var createdAt: Int64 = 0
    var startAt: Int64 = 0
    var endAt: Int64 = 0
    var aScore: Int = 0
    var bScore: Int = 0
    var winner: String = ""
    var aEscrow: Int = 0
    var bEscrow: Int = 0

    init(firestore d: [String: Any], id: String) {
        self.id = id
        aUid = d["aUid"] as? String ?? ""
        bUid = d["bUid"] as? String ?? ""
        aName = d["aName"] as? String ?? ""
        bName = d["bName"] as? String ?? ""
        stake = (d["stake"] as? NSNumber)?.intValue ?? 0
        metric = d["metric"] as? String ?? "obs"
        durationDays = (d["durationDays"] as? NSNumber)?.intValue ?? 1
        status = d["status"] as? String ?? ""
        createdAt = (d["createdAt"] as? NSNumber)?.int64Value ?? 0
        startAt = (d["startAt"] as? NSNumber)?.int64Value ?? 0
        endAt = (d["endAt"] as? NSNumber)?.int64Value ?? 0
        aScore = (d["aScore"] as? NSNumber)?.intValue ?? 0
        bScore = (d["bScore"] as? NSNumber)?.intValue ?? 0
        winner = d["winner"] as? String ?? ""
        aEscrow = (d["aEscrow"] as? NSNumber)?.intValue ?? 0
        bEscrow = (d["bEscrow"] as? NSNumber)?.intValue ?? 0
    }

    var pot: Int { aEscrow + bEscrow }
    func myEscrow(_ my: String) -> Int { aUid == my ? aEscrow : bEscrow }

    func opponentName(_ my: String) -> String { aUid == my ? bName : aName }
    func myScore(_ my: String) -> Int { aUid == my ? aScore : bScore }
    func theirScore(_ my: String) -> Int { aUid == my ? bScore : aScore }
}

final class DuelStore: ObservableObject {
    @Published var duels: [Duel] = []
    private var listener: ListenerRegistration?

    func start(uid: String) {
        guard listener == nil, !uid.isEmpty else { return }
        listener = Firestore.firestore().collection("duels").whereField("pair", arrayContains: uid)
            .addSnapshotListener { [weak self] snap, _ in
                self?.duels = (snap?.documents ?? [])
                    .map { Duel(firestore: $0.data(), id: $0.documentID) }
                    .sorted { $0.createdAt > $1.createdAt }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }
}

enum DuelRepository {
    private static var db: Firestore { Firestore.firestore() }

    static func myDuels(_ uid: String) async -> [Duel] {
        let snap = try? await db.collection("duels").whereField("pair", arrayContains: uid).getDocuments()
        return (snap?.documents ?? [])
            .map { Duel(firestore: $0.data(), id: $0.documentID) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func create(opponentUid: String, stake: Int, metric: String, durationDays: Int) async -> String? {
        do {
            _ = try await Functions.functions().httpsCallable("createDuel").call([
                "opponentUid": opponentUid, "stake": stake, "metric": metric, "durationDays": durationDays,
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
        _ = try? await Functions.functions().httpsCallable("respondDuel").call(["duelId": duelId, "accept": accept])
    }

    static func cancel(duelId: String) async {
        _ = try? await Functions.functions().httpsCallable("cancelDuel").call(["duelId": duelId])
    }
}
