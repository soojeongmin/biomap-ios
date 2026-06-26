import Foundation

struct Observation: Codable, Identifiable, Hashable {
    var id: String = ""
    var userId: String = ""
    var userName: String = ""
    var photoUrl: String = ""
    var speciesName: String = ""
    var scientificName: String = ""
    var category: String = ""
    var taxonId: Int64 = 0
    var latitude: Double = 0
    var longitude: Double = 0
    var note: String = ""
    var timestamp: Int64 = 0
    var freshness: String? = nil
    var mediaType: String? = nil
    var audioUrl: String? = nil
    var boomedBy: [String]? = nil
    var commentCount: Int? = nil

    var isSound: Bool { mediaType == "sound" }
    var boomCount: Int { boomedBy?.count ?? 0 }
    func isBoomed(by uid: String?) -> Bool {
        guard let uid else { return false }
        return boomedBy?.contains(uid) ?? false
    }
}

struct Suggestion: Codable, Identifiable, Hashable {
    var id: String = ""
    var suggesterId: String = ""
    var suggesterName: String = ""
    var speciesName: String = ""
    var scientificName: String = ""
    var category: String = ""
    var taxonId: Int64 = 0
    var timestamp: Int64 = 0
    var accepted: Bool? = false
}

struct Comment: Codable, Identifiable, Hashable {
    var id: String = ""
    var authorId: String = ""
    var authorName: String = ""
    var text: String = ""
    var timestamp: Int64 = 0
}

struct HofWinner: Codable, Hashable {
    var uid: String? = nil
    var id: String? = nil
    var name: String = ""
    var count: Int = 0
}

struct HallOfFameEntry: Codable {
    var weekStart: Int64 = 0
    var weekEnd: Int64 = 0
    var topUser: HofWinner? = nil
    var topGuild: HofWinner? = nil
}

struct SpeciesCandidate: Identifiable, Hashable {
    var taxonId: Int64
    var name: String
    var scientificName: String
    var rank: String
    var score: Double
    var iconUrl: String
    var iconicTaxon: String

    var id: Int64 { taxonId }
}

enum ObservationCategory: String, CaseIterable {
    case plant
    case insect
    case fungi
    case bird
    case animal
    case other

    var iconicTaxa: [String] {
        switch self {
        case .plant: return ["Plantae"]
        case .insect: return ["Insecta"]
        case .fungi: return ["Fungi"]
        case .bird: return ["Aves"]
        case .animal: return ["Animalia", "Mammalia", "Reptilia", "Amphibia", "Actinopterygii", "Mollusca", "Arachnida"]
        case .other: return []
        }
    }

    static func fromIconicTaxon(_ value: String) -> ObservationCategory {
        allCases.first { c in c.iconicTaxa.contains { $0.caseInsensitiveCompare(value) == .orderedSame } } ?? .other
    }

    static func fromKey(_ key: String) -> ObservationCategory {
        ObservationCategory(rawValue: key) ?? .other
    }
}
