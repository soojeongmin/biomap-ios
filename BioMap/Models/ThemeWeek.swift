import Foundation

enum ThemeWeek {
    static let order: [ObservationCategory] = [.plant, .insect, .bird, .animal, .fungi]

    static func current() -> ObservationCategory {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        guard let midnightUTC = utc.date(from: comps) else { return .plant }
        let day = Int(floor(midnightUTC.timeIntervalSince1970 / 86400))
        let weekIndex = Int(floor(Double(day - 4) / 7.0))
        return order[((weekIndex % 5) + 5) % 5]
    }

    static var titleKey: String { "theme_week_\(current().rawValue)" }
}
