import Foundation

struct ChatMessage: Identifiable, Hashable {
    var id: String = ""
    var uid: String = ""
    var name: String = ""
    var emoji: String = ""
    var bg: String = ""
    var nameColor: String = ""
    var text: String = ""
    var at: Int64 = 0

    init(id: String = "", uid: String = "", name: String = "", emoji: String = "",
         bg: String = "", nameColor: String = "", text: String = "", at: Int64 = 0) {
        self.id = id; self.uid = uid; self.name = name; self.emoji = emoji
        self.bg = bg; self.nameColor = nameColor; self.text = text; self.at = at
    }

    init(firestore d: [String: Any], id: String) {
        self.init(
            id: d["id"] as? String ?? id,
            uid: d["uid"] as? String ?? "",
            name: d["name"] as? String ?? "",
            emoji: d["emoji"] as? String ?? "",
            bg: d["bg"] as? String ?? "",
            nameColor: d["nameColor"] as? String ?? "",
            text: d["text"] as? String ?? "",
            at: (d["at"] as? NSNumber)?.int64Value ?? 0
        )
    }
}
