import Foundation
import FirebaseFirestore

enum NotificationRepository {
    private static var db: Firestore { Firestore.firestore() }
    private static func col(_ uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("notifications")
    }

    static func notify(targetUid: String, type: String, fromId: String, fromName: String,
                       speciesName: String = "", observationId: String = "") async {
        guard !targetUid.isEmpty, !fromId.isEmpty else { return }
        _ = try? await col(targetUid).addDocument(data: [
            "type": type,
            "fromId": fromId,
            "fromName": fromName,
            "speciesName": speciesName,
            "observationId": observationId,
            "read": false,
            "createdAt": Int64(Date().timeIntervalSince1970 * 1000),
        ])
    }

    static func getAll(_ uid: String) async -> [AppNotification] {
        do {
            let snap = try await col(uid).order(by: "createdAt", descending: true).limit(to: 50).getDocuments()
            return snap.documents.map { doc in
                let d = doc.data()
                return AppNotification(
                    id: doc.documentID,
                    type: d["type"] as? String ?? "",
                    fromName: d["fromName"] as? String ?? "",
                    speciesName: d["speciesName"] as? String ?? "",
                    observationId: d["observationId"] as? String ?? "",
                    read: d["read"] as? Bool ?? false,
                    createdAt: (d["createdAt"] as? NSNumber)?.int64Value ?? 0
                )
            }
        } catch {
            return []
        }
    }

    static func unreadCount(_ uid: String) async -> Int {
        (try? await col(uid).whereField("read", isEqualTo: false).getDocuments().count) ?? 0
    }

    static func markAllRead(_ uid: String) async {
        guard let snap = try? await col(uid).whereField("read", isEqualTo: false).getDocuments() else { return }
        for doc in snap.documents { try? await doc.reference.updateData(["read": true]) }
    }

    static func delete(uid: String, id: String) async {
        try? await col(uid).document(id).delete()
    }
}
