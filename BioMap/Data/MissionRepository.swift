import Foundation
import FirebaseFirestore

enum MissionRepository {
    private static var db: Firestore { Firestore.firestore() }

    static func syncCompletions(uid: String, missions: [DailyMission]) async {
        let dateKey = Missions.todayKey()
        let logCol = db.collection("users").document(uid).collection("missionLog")
        for mission in missions where mission.done {
            let ref = logCol.document("\(dateKey)_\(mission.id)")
            if let exists = try? await ref.getDocument().exists, exists { continue }
            try? await ref.setData([
                "date": dateKey,
                "missionId": mission.id,
                "at": Int64(Date().timeIntervalSince1970 * 1000),
            ])
        }
    }
}
