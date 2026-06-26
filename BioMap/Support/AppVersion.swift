import Foundation

enum AppVersion {
    static let storeURL = URL(string: "https://apps.apple.com/kr/app/%EC%83%9D%EB%8F%99%EA%B0%90/id6775654322")

    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static func latest() async -> String? {
        guard let bid = Bundle.main.bundleIdentifier,
              let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bid)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let v = results.first?["version"] as? String else { return nil }
        return v
    }

    static func isOutdated(_ current: String, _ latest: String) -> Bool {
        let c = current.split(separator: ".").map { Int($0) ?? 0 }
        let l = latest.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(c.count, l.count) {
            let cv = i < c.count ? c[i] : 0
            let lv = i < l.count ? l[i] : 0
            if lv != cv { return lv > cv }
        }
        return false
    }
}
