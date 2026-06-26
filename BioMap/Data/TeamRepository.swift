import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

enum CreateTeamResult {
    case success(Team)
    case duplicateName
    case failed
}

enum JoinResult {
    case joined
    case requested
    case failed
}

enum TeamRepository {
    private static var db: Firestore { Firestore.firestore() }
    private static let codeChars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    private static func generateCode() -> String {
        String((0..<6).map { _ in codeChars.randomElement()! })
    }

    static func nameTaken(_ name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let snap = try? await db.collection("teams")
            .whereField("name", isEqualTo: trimmed).limit(to: 1).getDocuments()
        return (snap?.documents.isEmpty == false)
    }

    static func createTeam(name: String, owner: User) async -> CreateTeamResult {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if await nameTaken(trimmed) { return .duplicateName }
        let ref = db.collection("teams").document()
        let team = Team(
            id: ref.documentID,
            name: trimmed,
            code: generateCode(),
            ownerId: owner.uid,
            ownerName: owner.displayName ?? "",
            createdAt: Int64(Date().timeIntervalSince1970 * 1000)
        )
        do {
            try ref.setData(from: team)
            try await db.collection("users").document(owner.uid).updateData([
                "teamId": ref.documentID,
                "teamJoinedAt": Int64(Date().timeIntervalSince1970 * 1000),
            ])
            return .success(team)
        } catch {
            return .failed
        }
    }

    static func getTeam(_ teamId: String) async -> Team? {
        guard !teamId.isEmpty else { return nil }
        return try? await db.collection("teams").document(teamId).getDocument().data(as: Team.self)
    }

    static func getAllTeams() async -> [Team] {
        do {
            let snap = try await db.collection("teams").getDocuments()
            return snap.documents.compactMap { try? $0.data(as: Team.self) }
        } catch {
            return []
        }
    }

    static func leave(uid: String) async {
        let teamId = (try? await db.collection("users").document(uid).getDocument().data()?["teamId"] as? String) ?? ""
        try? await db.collection("users").document(uid).updateData(["teamId": ""])
        await callDisbandIfEmpty(teamId ?? "")
    }

    static func callDisbandIfEmpty(_ teamId: String) async {
        guard !teamId.isEmpty else { return }
        _ = try? await Functions.functions().httpsCallable("disbandIfEmpty").call(["teamId": teamId])
    }

    static func buyBorder(teamId: String, borderId: String) async -> Bool {
        do {
            _ = try await Functions.functions().httpsCallable("buyGuildBorder")
                .call(["teamId": teamId, "borderId": borderId])
            return true
        } catch {
            return false
        }
    }

    static func kickMember(teamId: String, memberUid: String) async -> Bool {
        do {
            _ = try await Functions.functions().httpsCallable("kickGuildMember")
                .call(["teamId": teamId, "memberUid": memberUid])
            return true
        } catch {
            return false
        }
    }

    static func setBorder(teamId: String, borderId: String, color: String) async {
        try? await db.collection("teams").document(teamId).updateData([
            "borderId": borderId, "borderColor": color,
        ])
    }

    @discardableResult
    static func sendChat(teamId: String, me: AppUser, text: String) async -> Bool {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !teamId.isEmpty, !trimmed.isEmpty else { return false }
        let ref = db.collection("teams").document(teamId).collection("messages").document()
        do {
            try await ref.setData([
                "id": ref.documentID,
                "uid": me.uid,
                "name": me.name,
                "emoji": me.avatarEmoji,
                "bg": me.avatarBg,
                "nameColor": me.avatarNameColor,
                "text": trimmed,
                "at": Int64(Date().timeIntervalSince1970 * 1000),
            ])
            return true
        } catch {
            return false
        }
    }

    static func blockUser(myUid: String, targetUid: String) async {
        guard !myUid.isEmpty, !targetUid.isEmpty, myUid != targetUid else { return }
        try? await db.collection("users").document(myUid).updateData([
            "blockedUids": FieldValue.arrayUnion([targetUid]),
        ])
    }

    static func reportMessage(reporter: AppUser, teamId: String, message: ChatMessage) async {
        let ref = db.collection("reports").document()
        try? await ref.setData([
            "id": ref.documentID,
            "type": "chat",
            "reporterUid": reporter.uid,
            "reporterName": reporter.name,
            "targetUid": message.uid,
            "targetName": message.name,
            "teamId": teamId,
            "messageId": message.id,
            "text": String(message.text.prefix(1000)),
            "at": Int64(Date().timeIntervalSince1970 * 1000),
        ])
    }

    static func setPinned(teamId: String, message: ChatMessage) async {
        try? await db.collection("teams").document(teamId).updateData([
            "pinnedText": String(message.text.prefix(500)),
            "pinnedBy": message.name,
            "pinnedAt": Int64(Date().timeIntervalSince1970 * 1000),
        ])
    }

    static func clearPinned(teamId: String) async {
        try? await db.collection("teams").document(teamId).updateData([
            "pinnedText": "", "pinnedBy": "", "pinnedAt": 0,
        ])
    }

    static func renameTeam(teamId: String, name: String) async -> String? {
        do {
            _ = try await Functions.functions().httpsCallable("renameTeam")
                .call(["teamId": teamId, "name": name.trimmingCharacters(in: .whitespacesAndNewlines)])
            return nil
        } catch {
            let code = FunctionsErrorCode(rawValue: (error as NSError).code)
            switch code {
            case .alreadyExists: return "taken"
            case .resourceExhausted: return "coins"
            default: return "error"
            }
        }
    }

    static func setDescription(teamId: String, description: String) async {
        let text = String(description.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        try? await db.collection("teams").document(teamId).updateData(["description": text])
    }

    static func searchTeams(_ query: String) async -> [Team] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return await getAllTeams()
            .filter { $0.name.localizedCaseInsensitiveContains(q) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
            .prefix(20)
            .map { $0 }
    }

    static func setAutoAccept(teamId: String, enabled: Bool) async {
        try? await db.collection("teams").document(teamId).updateData(["autoAccept": enabled])
    }

    static func cancelRequest(teamId: String, uid: String) async {
        try? await db.collection("teams").document(teamId).collection("joinRequests").document(uid).delete()
        try? await db.collection("users").document(uid).updateData(["pendingTeamId": ""])
    }

    @discardableResult
    static func requestJoin(teamId: String, uid: String, name: String) async -> JoinResult {
        guard let team = await getTeam(teamId) else { return .failed }
        if team.autoAccept == true {
            do {
                try await db.collection("users").document(uid)
                    .updateData([
                        "teamId": teamId, "pendingTeamId": "",
                        "teamJoinedAt": Int64(Date().timeIntervalSince1970 * 1000),
                    ])
                return .joined
            } catch {
                return .failed
            }
        }
        do {
            try await db.collection("teams").document(teamId).collection("joinRequests").document(uid).setData([
                "uid": uid, "name": name, "approved": false,
                "requestedAt": Int64(Date().timeIntervalSince1970 * 1000),
            ])
            try? await db.collection("users").document(uid).updateData(["pendingTeamId": teamId])
            await NotificationRepository.notify(
                targetUid: team.ownerId, type: "guild_request", fromId: uid, fromName: name, speciesName: team.name)
            return .requested
        } catch {
            return .failed
        }
    }

    static func pendingRequests(teamId: String) async -> [JoinRequest] {
        do {
            let snap = try await db.collection("teams").document(teamId).collection("joinRequests")
                .whereField("approved", isEqualTo: false).getDocuments()
            return snap.documents.map { JoinRequest(id: $0.documentID, name: $0.data()["name"] as? String ?? "") }
        } catch {
            return []
        }
    }

    static func approveRequest(teamId: String, teamName: String, uid: String) async {
        _ = try? await Functions.functions().httpsCallable("approveGuildJoin").call(["teamId": teamId, "memberUid": uid])
    }

    static func rejectRequest(teamId: String, uid: String) async {
        _ = try? await Functions.functions().httpsCallable("rejectGuildJoin").call(["teamId": teamId, "memberUid": uid])
    }

    static func transferOwnership(teamId: String, toUid: String) async {
        _ = try? await Functions.functions().httpsCallable("transferGuildOwnership").call(["teamId": teamId, "toUid": toUid])
    }

    static func myPendingRequestTeamId(uid: String) async -> String? {
        guard let snap = try? await db.collectionGroup("joinRequests").whereField("uid", isEqualTo: uid).getDocuments() else { return nil }
        return snap.documents.first(where: { ($0.data()["approved"] as? Bool) != true })?.reference.parent.parent?.documentID
    }

    @discardableResult
    static func completeApprovedJoins(uid: String) async -> Bool {
        guard let snap = try? await db.collectionGroup("joinRequests").whereField("uid", isEqualTo: uid).getDocuments() else { return false }
        let approved = snap.documents.first { ($0.data()["approved"] as? Bool) == true }
        guard let approved, let teamId = approved.reference.parent.parent?.documentID else { return false }
        try? await db.collection("users").document(uid).updateData([
            "teamId": teamId,
            "teamJoinedAt": Int64(Date().timeIntervalSince1970 * 1000),
        ])
        for doc in snap.documents { try? await doc.reference.delete() }
        return true
    }

    static func getMembers(_ teamId: String) async -> [AppUser] {
        guard !teamId.isEmpty else { return [] }
        do {
            let snap = try await db.collection("users").whereField("teamId", isEqualTo: teamId).getDocuments()
            return snap.documents.map { AppUser(firestore: $0.data(), id: $0.documentID) }.filter { !$0.name.isEmpty }
        } catch {
            return []
        }
    }
}
