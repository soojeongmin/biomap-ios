import Foundation

enum Stats {
    static let baseXp = 10
    static let newSpeciesBonus = 5
    static let xpPerLevel = 50

    static func calculateXp(all: [Observation], mine: [Observation], uid: String?) -> Int {
        guard let uid else { return 0 }
        let firstFinder = Dictionary(grouping: all.filter { $0.taxonId != 0 }, by: { $0.taxonId })
            .mapValues { $0.min(by: { $0.timestamp < $1.timestamp })?.userId }
        var total = 0
        for (index, obs) in mine.sorted(by: { $0.timestamp < $1.timestamp }).enumerated() {
            switch obs.freshness ?? "" {
            case "none": total += 1
            case "old": total += 1
            default:
                let base = max(baseXp >> min(index, 4), 1)
                let bonus = (obs.taxonId != 0 && firstFinder[obs.taxonId] == uid) ? newSpeciesBonus : 0
                total += base + bonus
            }
        }
        return total
    }

    static func level(_ xp: Int) -> Int { xp / xpPerLevel + 1 }

    static func daysSince(_ created: Date?) -> Int {
        guard let created else { return 1 }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: created), to: cal.startOfDay(for: Date())).day ?? 0
        return max(days + 1, 1)
    }
}

func localizedFormat(_ key: String, _ args: CVarArg...) -> String {
    String(format: String(localized: String.LocalizationValue(key)), arguments: args)
}
