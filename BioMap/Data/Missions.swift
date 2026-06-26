import Foundation

struct DailyMission: Identifiable {
    let id: String
    let titleKey: String
    let current: Int
    let target: Int
    var titleArg: Int? = nil
    var done: Bool { current >= target }
}

private let obsLadder = [10, 20, 30, 40, 50, 75, 100, 150, 200, 300, 500, 750, 1000]
private let speciesLadder = [10, 20, 30, 40, 50, 75, 100, 150, 200, 300, 500]
private func nextMilestone(_ current: Int, _ ladder: [Int]) -> Int {
    ladder.first { $0 > current } ?? ((current / 250) + 1) * 250
}

private struct MissionTemplate {
    let id: String
    let titleKey: String
    let target: Int
    var dynamicTarget: ((MissionCtx) -> Int)? = nil
    var dynamicTitle: Bool = false
    let compute: (MissionCtx) -> Int
}

private struct MissionCtx {
    let all: [Observation]
    let uid: String
    let cal: Calendar
    let dayStart: Date
    let dayEnd: Date

    private func date(_ ts: Int64) -> Date { Date(timeIntervalSince1970: Double(ts) / 1000) }
    private func isToday(_ ts: Int64) -> Bool {
        let d = date(ts)
        return d >= dayStart && d < dayEnd
    }
    var mineToday: [Observation] {
        all.filter { $0.userId == uid && isToday($0.timestamp) }
    }
    var mine: [Observation] { all.filter { $0.userId == uid } }
    var speciesCount: Int { Set(mine.map { $0.speciesName }.filter { !$0.isEmpty }).count }
    var firstFinderByTaxon: [Int64: String] {
        Dictionary(grouping: all.filter { $0.taxonId != 0 }, by: { $0.taxonId })
            .compactMapValues { $0.min(by: { $0.timestamp < $1.timestamp })?.userId }
    }

    func countTodayCategory(_ key: String) -> Int { mineToday.filter { $0.category == key }.count }
    func countTodayHour(_ start: Int, _ end: Int) -> Int {
        mineToday.filter {
            let h = cal.component(.hour, from: date($0.timestamp))
            return h >= start && h < end
        }.count
    }
    func hasTwoSpotsApart(_ meters: Double) -> Bool {
        let obs = mineToday.filter { $0.latitude != 0 || $0.longitude != 0 }
        for i in obs.indices {
            for j in (i + 1)..<obs.count {
                if haversine(obs[i].latitude, obs[i].longitude, obs[j].latitude, obs[j].longitude) > meters { return true }
            }
        }
        return false
    }
}

private func haversine(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
    let r = 6_371_000.0
    let dLat = (lat2 - lat1) * .pi / 180
    let dLon = (lon2 - lon1) * .pi / 180
    let a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
    return 2 * r * atan2(sqrt(a), sqrt(1 - a))
}

private let pool: [MissionTemplate] = [
    .init(id: "record_one", titleKey: "mission_record_one", target: 1) { $0.mineToday.count },
    .init(id: "record_two", titleKey: "mission_record_two", target: 2) { $0.mineToday.count },
    .init(id: "record_three", titleKey: "mission_record_three", target: 3) { $0.mineToday.count },
    .init(id: "two_categories", titleKey: "mission_two_categories", target: 2) { Set($0.mineToday.map { $0.category }).count },
    .init(id: "three_categories", titleKey: "mission_three_categories", target: 3) { Set($0.mineToday.map { $0.category }).count },
    .init(id: "plant_one", titleKey: "mission_plant_one", target: 1) { $0.countTodayCategory("plant") },
    .init(id: "plant_two", titleKey: "mission_plant_two", target: 2) { $0.countTodayCategory("plant") },
    .init(id: "insect_one", titleKey: "mission_insect_one", target: 1) { $0.countTodayCategory("insect") },
    .init(id: "insect_two", titleKey: "mission_insect_two", target: 2) { $0.countTodayCategory("insect") },
    .init(id: "bird_one", titleKey: "mission_bird_one", target: 1) { $0.countTodayCategory("bird") },
    .init(id: "fungi_one", titleKey: "mission_fungi_one", target: 1) { $0.countTodayCategory("fungi") },
    .init(id: "other_one", titleKey: "mission_other_one", target: 1) { $0.countTodayCategory("other") },
    .init(id: "new_species", titleKey: "mission_new_species", target: 1) { ctx in
        ctx.mineToday.filter { $0.taxonId != 0 && ctx.firstFinderByTaxon[$0.taxonId] == ctx.uid }.count },
    .init(id: "new_species_two", titleKey: "mission_new_species_two", target: 2) { ctx in
        ctx.mineToday.filter { $0.taxonId != 0 && ctx.firstFinderByTaxon[$0.taxonId] == ctx.uid }.count },
    .init(id: "note_one", titleKey: "mission_note_one", target: 1) { $0.mineToday.filter { !$0.note.isEmpty }.count },
    .init(id: "note_two", titleKey: "mission_note_two", target: 2) { $0.mineToday.filter { !$0.note.isEmpty }.count },
    .init(id: "scientific_one", titleKey: "mission_scientific_one", target: 1) { $0.mineToday.filter { $0.taxonId != 0 || !$0.scientificName.isEmpty }.count },
    .init(id: "scientific_two", titleKey: "mission_scientific_two", target: 2) { $0.mineToday.filter { $0.taxonId != 0 || !$0.scientificName.isEmpty }.count },
    .init(id: "morning", titleKey: "mission_morning", target: 1) { $0.countTodayHour(6, 12) },
    .init(id: "afternoon", titleKey: "mission_afternoon", target: 1) { $0.countTodayHour(12, 18) },
    .init(id: "evening", titleKey: "mission_evening", target: 1) { $0.countTodayHour(18, 24) },
    .init(id: "two_spots", titleKey: "mission_two_spots", target: 1) { $0.hasTwoSpotsApart(50) ? 1 : 0 },
    .init(id: "lifetime_obs", titleKey: "mission_lifetime_dynamic", target: 0,
          dynamicTarget: { nextMilestone($0.mine.count, obsLadder) }, dynamicTitle: true) { $0.mine.count },
    .init(id: "lifetime_species", titleKey: "mission_lifetime_species_dynamic", target: 0,
          dynamicTarget: { nextMilestone($0.speciesCount, speciesLadder) }, dynamicTitle: true) { $0.speciesCount },
]

enum Missions {
    static func todayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.string(from: Date())
    }

    static func today(all: [Observation], uid: String?) -> [DailyMission] {
        guard let uid else { return [] }
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: Date())
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        var rng = SeededRNG(seed: stableSeed("\(uid)_\(todayKey())"))
        let picked = pool.shuffled(using: &rng).prefix(3)
        let ctx = MissionCtx(all: all, uid: uid, cal: cal, dayStart: dayStart, dayEnd: dayEnd)
        return picked.map { t in
            let tgt = t.dynamicTarget?(ctx) ?? t.target
            return DailyMission(id: t.id, titleKey: t.titleKey, current: min(t.compute(ctx), tgt), target: tgt,
                                titleArg: t.dynamicTitle ? tgt : nil)
        }
    }
}

private func stableSeed(_ s: String) -> UInt64 {
    var h: UInt64 = 1469598103934665603
    for b in s.utf8 { h ^= UInt64(b); h = h &* 1099511628211 }
    return h
}

private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}
