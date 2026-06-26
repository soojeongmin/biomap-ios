import SwiftUI

struct GuildBorder: Identifiable {
    let id: String
    let nameKey: String
    let price: Int
    let asset: String?
}

enum GuildBorders {
    static let none = "white"

    static let all: [GuildBorder] = [
        .init(id: none, nameKey: "border_white", price: 0, asset: nil),
        .init(id: "double", nameKey: "border_double", price: 30, asset: nil),
        .init(id: "gear", nameKey: "border_gear", price: 40, asset: nil),
        .init(id: "star", nameKey: "border_star", price: 50, asset: nil),
        .init(id: "bubble", nameKey: "border_bubble", price: 50, asset: nil),
        .init(id: "neon", nameKey: "border_neon", price: 60, asset: nil),
        .init(id: "gem", nameKey: "border_gem", price: 70, asset: nil),
        .init(id: "bacteria", nameKey: "border_bacteria", price: 80, asset: nil),
        .init(id: "phage", nameKey: "border_phage", price: 100, asset: nil),
        .init(id: "leaf", nameKey: "border_leaf", price: 15, asset: "border_leaf"),
        .init(id: "vine", nameKey: "border_vine", price: 20, asset: "border_vine"),
        .init(id: "ladybug", nameKey: "border_ladybug", price: 25, asset: "border_ladybug"),
        .init(id: "snake", nameKey: "border_snake", price: 35, asset: "border_snake"),
        .init(id: "bee", nameKey: "border_bee", price: 45, asset: nil),
        .init(id: "frost", nameKey: "border_frost", price: 55, asset: nil),
        .init(id: "ocean", nameKey: "border_ocean", price: 70, asset: nil),
        .init(id: "rainbow", nameKey: "border_rainbow", price: 90, asset: nil),
    ]

    static let procedural: Set<String> = [
        "bee", "frost", "star", "rainbow",
        "neon", "double", "gear", "gem", "bubble", "bacteria", "ocean", "phage",
    ]

    static let tintable: Set<String> = ["star", "neon", "double", "gear", "gem", "bubble", "bacteria", "phage"]

    static let palette: [String] = [
        "#FFFFFF", "#16A34A", "#00C98A", "#2563EB", "#7C3AED",
        "#E5484D", "#F97316", "#FACC15", "#EC4899", "#14B8A6",
        "#1F2937", "#8B5E3C",
    ]

    static func byId(_ id: String) -> GuildBorder { all.first { $0.id == id } ?? all[0] }
    static func assetOf(_ id: String) -> String? { byId(id).asset }
    static func owned(_ team: Team?) -> Set<String> {
        Set([none] + (team?.ownedBorders ?? []))
    }
}
