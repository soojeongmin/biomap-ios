import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import FirebaseFunctions

enum UserRepository {
    private static var db: Firestore { Firestore.firestore() }

    static func referralCode(for uid: String) -> String {
        String(uid.prefix(6)).uppercased()
    }

    static func epochDay() -> Int {
        let tz = Double(TimeZone.current.secondsFromGMT())
        return Int((Date().timeIntervalSince1970 + tz) / 86400)
    }

    @discardableResult
    static func touchStreak() async -> Int {
        guard let uid = Auth.auth().currentUser?.uid else { return 0 }
        let ref = db.collection("users").document(uid)
        let today = epochDay()
        let snap = try? await ref.getDocument()
        let last = snap?.get("lastActiveDay") as? Int ?? 0
        let prev = snap?.get("streak") as? Int ?? 0
        if last == today { return prev }
        let streak = (last == today - 1) ? prev + 1 : 1
        try? await ref.updateData(["lastActiveDay": today, "streak": streak])
        return streak
    }

    static func upsert(_ user: User) async {
        let ref = db.collection("users").document(user.uid)
        let code = referralCode(for: user.uid)
        do {
            let snapshot = try await ref.getDocument()
            if snapshot.exists {
                try await ref.setData(["photoUrl": user.photoURL?.absoluteString ?? "", "referralCode": code], merge: true)
            } else {
                try await ref.setData([
                    "uid": user.uid,
                    "name": "",
                    "photoUrl": user.photoURL?.absoluteString ?? "",
                    "teamId": "",
                    "referralCode": code,
                    "createdAt": Int64(Date().timeIntervalSince1970 * 1000),
                ])
            }
        } catch {
        }
    }

    static func redeemReferral(_ code: String) async -> String? {
        do {
            _ = try await Functions.functions().httpsCallable("redeemReferral")
                .call(["code": code.trimmingCharacters(in: .whitespaces).uppercased()])
            return nil
        } catch {
            let ns = error as NSError
            return ns.userInfo["message"] as? String ?? ns.localizedDescription
        }
    }

    static func getUser(_ uid: String) async -> AppUser? {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            guard let d = doc.data() else { return nil }
            return AppUser(firestore: d, id: doc.documentID)
        } catch {
            return nil
        }
    }

    static func getAllUsers() async -> [AppUser] {
        do {
            let snap = try await db.collection("users").getDocuments()
            return snap.documents.map { AppUser(firestore: $0.data(), id: $0.documentID) }
        } catch {
            return []
        }
    }

    static func search(_ query: String) async -> [AppUser] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return await getAllUsers()
            .filter { !$0.name.isEmpty && $0.name.localizedCaseInsensitiveContains(q) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
            .prefix(20)
            .map { $0 }
    }

    static func getFriends(_ uid: String) async -> [AppUser] {
        do {
            let snap = try await db.collection("users").document(uid).collection("friends").getDocuments()
            let snapshots = snap.documents.map { AppUser(firestore: $0.data(), id: $0.documentID) }
            var result: [AppUser] = []
            for f in snapshots {
                result.append(await getUser(f.uid) ?? f)
            }
            return result
        } catch {
            return []
        }
    }

    static func sendFriendRequest(myUid: String, to friend: AppUser) async {
        let myName = await getUser(myUid)?.name ?? ""
        let ref = db.collection("users").document(friend.uid)
            .collection("friendRequests").document(myUid)
        try? await ref.setData([
            "uid": myUid,
            "name": myName,
            "photoUrl": "",
            "requestedAt": Int64(Date().timeIntervalSince1970 * 1000),
        ])
        await NotificationRepository.notify(
            targetUid: friend.uid,
            type: AppNotification.typeFriendRequest,
            fromId: myUid,
            fromName: myName
        )
    }

    static func cancelFriendRequest(myUid: String, to friendUid: String) async {
        try? await db.collection("users").document(friendUid)
            .collection("friendRequests").document(myUid).delete()
    }

    static func incomingRequests(_ uid: String) async -> [AppUser] {
        do {
            let snap = try await db.collection("users").document(uid)
                .collection("friendRequests").getDocuments()
            return snap.documents.map { AppUser(firestore: $0.data(), id: $0.documentID) }
        } catch {
            return []
        }
    }

    static func outgoingRequestUids(_ uid: String) async -> Set<String> {
        do {
            let snap = try await db.collectionGroup("friendRequests")
                .whereField("uid", isEqualTo: uid).getDocuments()
            let ids = snap.documents.compactMap { $0.reference.parent.parent?.documentID }
            return Set(ids)
        } catch {
            return []
        }
    }

    @discardableResult
    static func acceptFriend(fromUid: String) async -> Bool {
        do {
            let result = try await Functions.functions().httpsCallable("acceptFriend")
                .call(["fromUid": fromUid])
            return (result.data as? [String: Any])?["ok"] as? Bool == true
        } catch {
            return false
        }
    }

    static func rejectFriend(myUid: String, fromUid: String) async {
        try? await db.collection("users").document(myUid)
            .collection("friendRequests").document(fromUid).delete()
    }

    static func removeFriend(myUid: String, friendUid: String) async {
        try? await db.collection("users").document(myUid)
            .collection("friends").document(friendUid).delete()
        try? await db.collection("users").document(friendUid)
            .collection("friends").document(myUid).delete()
    }

    static func nicknameTaken(_ name: String, uid: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let snap = try? await db.collection("users").whereField("name", isEqualTo: trimmed).getDocuments()
        return snap?.documents.contains(where: { $0.documentID != uid }) == true
    }

    static func setNickname(uid: String, name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        try? await db.collection("users").document(uid).updateData(["name": trimmed])
        if let obs = try? await db.collection("observations").whereField("userId", isEqualTo: uid).getDocuments() {
            for doc in obs.documents { try? await doc.reference.updateData(["userName": trimmed]) }
        }
        if let teams = try? await db.collection("teams").whereField("ownerId", isEqualTo: uid).getDocuments() {
            for doc in teams.documents { try? await doc.reference.updateData(["ownerName": trimmed]) }
        }
        let req = Auth.auth().currentUser?.createProfileChangeRequest()
        req?.displayName = trimmed
        try? await req?.commitChanges()
    }

    static func saveFcmToken(uid: String, token: String) async {
        try? await db.collection("users").document(uid)
            .collection("private").document("push").setData(["fcmToken": token], merge: true)
    }

    static func setAvatarEmoji(uid: String, emoji: String) async {
        try? await db.collection("users").document(uid).updateData(["avatarEmoji": emoji, "avatarMode": "emoji"])
    }

    static func setAvatarBg(uid: String, hex: String) async {
        try? await db.collection("users").document(uid).updateData(["avatarBg": hex])
    }

    static func setAvatarEffect(uid: String, effect: String) async {
        try? await db.collection("users").document(uid).updateData(["avatarEffect": effect])
    }

    static func setAvatarNameColor(uid: String, token: String) async {
        try? await db.collection("users").document(uid).updateData(["avatarNameColor": token])
    }

    static func buyDecor(kind: String, value: String) async -> Bool {
        do {
            let result = try await Functions.functions().httpsCallable("purchaseDecor")
                .call(["kind": kind, "value": value])
            let data = result.data as? [String: Any]
            return data?["ok"] as? Bool == true
        } catch {
            return false
        }
    }

    static func setGuildChatMuted(uid: String, muted: Bool) async {
        try? await db.collection("users").document(uid).updateData(["guildChatMuted": muted])
    }

    static func setDmMuted(uid: String, muted: Bool) async {
        try? await db.collection("users").document(uid).updateData(["dmMuted": muted])
    }

    static func dmUnreadFrom(_ uid: String) async -> Set<String> {
        let snap = try? await db.collection("users").document(uid).collection("dmUnread").getDocuments()
        return Set((snap?.documents ?? []).map { $0.documentID })
    }

    static func clearDmUnread(myUid: String, peerUid: String) async {
        try? await db.collection("users").document(myUid).collection("dmUnread").document(peerUid).delete()
    }

    static func uploadProfilePhoto(uid: String, data: Data) async -> String? {
        let name = "profile_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        let ref = Storage.storage().reference().child("avatars/\(uid)/\(name)")
        do {
            let meta = StorageMetadata()
            meta.contentType = "image/jpeg"
            _ = try await ref.putDataAsync(data, metadata: meta)
            return try await ref.downloadURL().absoluteString
        } catch {
            return nil
        }
    }

    static func applyProfilePhoto(url: String) async -> String? {
        do {
            _ = try await Functions.functions().httpsCallable("applyProfilePhoto").call(["url": url])
            return nil
        } catch {
            let code = FunctionsErrorCode(rawValue: (error as NSError).code)
            return code == .failedPrecondition ? "coins" : "error"
        }
    }

    static func applyProfileHeader(url: String) async -> String? {
        do {
            _ = try await Functions.functions().httpsCallable("applyProfileHeader").call(["url": url])
            return nil
        } catch {
            let code = FunctionsErrorCode(rawValue: (error as NSError).code)
            return code == .failedPrecondition ? "coins" : "error"
        }
    }

    static func deleteStoredPhoto(url: String) async {
        guard !url.isEmpty else { return }
        try? await Storage.storage().reference(forURL: url).delete()
    }

    static func renameNickname(_ name: String) async -> String? {
        do {
            _ = try await Functions.functions().httpsCallable("renameNickname").call(["name": name])
            return nil
        } catch {
            let code = FunctionsErrorCode(rawValue: (error as NSError).code)
            switch code {
            case .alreadyExists: return "taken"
            case .failedPrecondition: return "coins"
            default: return "error"
            }
        }
    }

    @discardableResult
    static func deleteAccount(_ uid: String) async -> Bool {
        do {
            _ = try await Functions.functions().httpsCallable("deleteAccount").call()
            try? Auth.auth().signOut()
            return true
        } catch {
            return false
        }
    }
}
