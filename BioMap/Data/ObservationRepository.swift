import Foundation
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage

enum ObservationRepository {
    private static var db: Firestore { Firestore.firestore() }

    static func getAll() async -> [Observation] {
        do {
            let snap = try await db.collection("observations").getDocuments()
            return snap.documents
                .compactMap { try? $0.data(as: Observation.self) }
                .sorted { $0.timestamp > $1.timestamp }
        } catch {
            return []
        }
    }

    static func getByUser(_ userId: String) async -> [Observation] {
        do {
            let snap = try await db.collection("observations")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            return snap.documents
                .compactMap { try? $0.data(as: Observation.self) }
                .sorted { $0.timestamp > $1.timestamp }
        } catch {
            return []
        }
    }

    static func getSuggestions(_ observationId: String) async -> [Suggestion] {
        do {
            let snap = try await db.collection("observations").document(observationId)
                .collection("suggestions")
                .getDocuments()
            return snap.documents
                .compactMap { try? $0.data(as: Suggestion.self) }
                .sorted { $0.timestamp > $1.timestamp }
        } catch {
            return []
        }
    }

    static func add(_ observation: Observation, imageData: Data) async throws {
        let fileName = "\(Int64(Date().timeIntervalSince1970 * 1000)).jpg"
        let ref = Storage.storage().reference().child("observations/\(observation.userId)/\(fileName)")
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(imageData, metadata: meta)
        let url = try await ref.downloadURL().absoluteString
        let doc = db.collection("observations").document()
        var toSave = observation
        toSave.id = doc.documentID
        toSave.photoUrl = url
        if toSave.timestamp <= 0 {
            toSave.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        }
        try doc.setData(from: toSave)
    }

    static func addSound(_ observation: Observation, audioData: Data, iconUrl: String) async throws {
        let fileName = "\(Int64(Date().timeIntervalSince1970 * 1000)).m4a"
        let ref = Storage.storage().reference().child("observations/\(observation.userId)/\(fileName)")
        let meta = StorageMetadata()
        meta.contentType = "audio/mp4"
        _ = try await ref.putDataAsync(audioData, metadata: meta)
        let url = try await ref.downloadURL().absoluteString
        let doc = db.collection("observations").document()
        var toSave = observation
        toSave.id = doc.documentID
        toSave.mediaType = "sound"
        toSave.audioUrl = url
        toSave.photoUrl = iconUrl
        if toSave.timestamp <= 0 {
            toSave.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        }
        try doc.setData(from: toSave)
    }

    static func toggleBoom(_ observationId: String) async -> (boomed: Bool, count: Int)? {
        do {
            let result = try await Functions.functions().httpsCallable("toggleBoom")
                .call(["observationId": observationId])
            guard let map = result.data as? [String: Any] else { return nil }
            let boomed = map["boomed"] as? Bool ?? false
            let count = (map["count"] as? NSNumber)?.intValue ?? 0
            return (boomed, count)
        } catch {
            return nil
        }
    }

    static func addSuggestion(_ observationId: String, _ suggestion: Suggestion) async throws {
        let rawKey = suggestion.taxonId != 0
            ? "t\(suggestion.taxonId)"
            : (suggestion.scientificName.isEmpty ? suggestion.speciesName : suggestion.scientificName)
                .lowercased()
        let dedupKey = rawKey.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
        let docId = "\(suggestion.suggesterId)_\(dedupKey)"
        let ref = db.collection("observations").document(observationId)
            .collection("suggestions").document(docId)
        let isNew = (try? await ref.getDocument())?.exists != true
        guard isNew else { return }
        var toSave = suggestion
        toSave.id = ref.documentID
        toSave.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        try ref.setData(from: toSave)

        if let obs = try? await db.collection("observations").document(observationId).getDocument().data(as: Observation.self),
           obs.userId != suggestion.suggesterId {
            await NotificationRepository.notify(
                targetUid: obs.userId,
                type: AppNotification.typeSuggestion,
                fromId: suggestion.suggesterId,
                fromName: suggestion.suggesterName,
                speciesName: obs.speciesName,
                observationId: observationId
            )
        }
    }

    static func deleteSuggestion(_ observationId: String, _ suggestionId: String) async throws {
        try await db.collection("observations").document(observationId)
            .collection("suggestions").document(suggestionId).delete()
    }

    static func acceptSuggestion(_ observationId: String, _ suggestionId: String) async throws {
        _ = try await Functions.functions().httpsCallable("acceptSuggestion")
            .call(["observationId": observationId, "suggestionId": suggestionId])
    }

    static func recentHallOfFame(limit: Int) async -> [HallOfFameEntry] {
        do {
            let snap = try await db.collection("hallOfFame")
                .order(by: "weekStart", descending: true).limit(to: limit).getDocuments()
            return snap.documents.compactMap { try? $0.data(as: HallOfFameEntry.self) }
        } catch {
            return []
        }
    }

    static func getComments(_ observationId: String) async -> [Comment] {
        do {
            let snap = try await db.collection("observations").document(observationId)
                .collection("comments")
                .getDocuments()
            return snap.documents
                .compactMap { try? $0.data(as: Comment.self) }
                .sorted { $0.timestamp < $1.timestamp }
        } catch {
            return []
        }
    }

    static func addComment(_ observationId: String, authorId: String, authorName: String, text: String) async throws {
        let ref = db.collection("observations").document(observationId)
            .collection("comments").document()
        let comment = Comment(id: ref.documentID, authorId: authorId, authorName: authorName, text: text,
                              timestamp: Int64(Date().timeIntervalSince1970 * 1000))
        try ref.setData(from: comment)
        try? await db.collection("observations").document(observationId)
            .updateData(["commentCount": FieldValue.increment(Int64(1))])

        if let obs = try? await db.collection("observations").document(observationId).getDocument().data(as: Observation.self),
           obs.userId != authorId {
            await NotificationRepository.notify(
                targetUid: obs.userId,
                type: AppNotification.typeComment,
                fromId: authorId,
                fromName: authorName,
                speciesName: obs.speciesName,
                observationId: observationId
            )
        }
    }

    static func deleteComment(_ observationId: String, _ commentId: String) async throws {
        try await db.collection("observations").document(observationId)
            .collection("comments").document(commentId).delete()
        try? await db.collection("observations").document(observationId)
            .updateData(["commentCount": FieldValue.increment(Int64(-1))])
    }

    static func updateFields(id: String, speciesName: String, scientificName: String, note: String) async -> Bool {
        do {
            try await db.collection("observations").document(id).updateData([
                "speciesName": speciesName,
                "scientificName": scientificName,
                "note": note
            ])
            return true
        } catch {
            return false
        }
    }

    static func delete(_ observation: Observation) async throws {
        try await db.collection("observations").document(observation.id).delete()
        if let audio = observation.audioUrl, !audio.isEmpty {
            try? await Storage.storage().reference(forURL: audio).delete()
        }
        if !observation.photoUrl.isEmpty, observation.photoUrl.contains("firebasestorage") {
            try? await Storage.storage().reference(forURL: observation.photoUrl).delete()
        }
    }
}
