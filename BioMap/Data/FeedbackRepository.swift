import Foundation
import FirebaseAuth
import FirebaseFirestore

enum FeedbackRepository {
    @discardableResult
    static func submit(type: String, text: String) async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        do {
            try await Firestore.firestore().collection("feedback").addDocument(data: [
                "uid": uid,
                "type": type,
                "text": text.trimmingCharacters(in: .whitespacesAndNewlines),
                "platform": "ios",
                "appVersion": version,
                "at": Int(Date().timeIntervalSince1970 * 1000),
            ])
            return true
        } catch {
            return false
        }
    }
}
