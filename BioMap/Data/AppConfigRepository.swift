import Foundation
import FirebaseFirestore

struct AppConfig {
    var iosLatestBuild: Int = 0
    var iosUrl: String = ""
    var updateMessage: String = ""
}

enum AppConfigRepository {
    static func get() async -> AppConfig? {
        guard let snap = try? await Firestore.firestore().collection("config").document("app").getDocument(),
              let d = snap.data() else { return nil }
        return AppConfig(
            iosLatestBuild: (d["iosLatestBuild"] as? NSNumber)?.intValue ?? 0,
            iosUrl: d["iosUrl"] as? String ?? "",
            updateMessage: d["updateMessage"] as? String ?? ""
        )
    }
}
