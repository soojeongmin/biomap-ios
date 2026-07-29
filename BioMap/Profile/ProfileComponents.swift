import SwiftUI

let galleryAllKey = "__ALL__"

struct GalleryTarget: Identifiable {
    let id = UUID()
    let key: String
}

struct GallerySheet: View {
    let observations: [Observation]
    var body: some View {
        ScrollView {
            GalleryGrid(observations: observations).padding(16)
        }
        .largeSheet()
    }
}

struct ProfileStatsView: View {
    let speciesCount: Int
    let days: Int
    let level: Int
    let xp: Int

    var body: some View {
        SectionCard(titleKey: "profile_stats") {
            VStack(spacing: 20) {
                HStack {
                    StatItem(titleKey: "profile_stat_species", value: "\(speciesCount)")
                    StatItem(titleKey: "profile_stat_since", value: localizedFormat("days_format", days))
                }
                HStack {
                    StatItem(titleKey: "profile_stat_level", value: localizedFormat("level_format", level))
                    StatItem(titleKey: "profile_stat_xp", value: localizedFormat("xp_format", xp))
                }
            }
        }
    }
}

struct CollectionTierView: View {
    let speciesCount: Int

    private static let tiers: [(threshold: Int, emoji: String, nameKey: String)] = [
        (0, "🌰", "tier_seed"), (10, "🌱", "tier_sprout"), (25, "🌿", "tier_leaf"),
        (50, "🌳", "tier_tree"), (100, "🌲", "tier_forest"),
    ]

    var body: some View {
        let idx = Self.tiers.lastIndex { speciesCount >= $0.threshold } ?? 0
        let cur = Self.tiers[idx]
        let next: (threshold: Int, emoji: String, nameKey: String)? =
            idx + 1 < Self.tiers.count ? Self.tiers[idx + 1] : nil
        return SectionCard(titleKey: "collection_grade") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(cur.emoji).font(.system(size: 34))
                    Text(LocalizedStringKey(cur.nameKey)).font(.system(size: 20, weight: .bold))
                    Spacer()
                    Text(localizedFormat("collection_species", speciesCount))
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.brand)
                }
                if let next {
                    let span = next.threshold - cur.threshold
                    let prog = span > 0 ? Double(speciesCount - cur.threshold) / Double(span) : 1
                    ProgressView(value: min(max(prog, 0), 1)).tint(Color.brand)
                    Text(String(format: NSLocalizedString("collection_next", comment: ""),
                                NSLocalizedString(next.nameKey, comment: ""), next.threshold - speciesCount))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ProfileObservationsView: View {
    let observations: [Observation]
    var onSelect: (String) -> Void = { _ in }

    private func count(_ c: ObservationCategory) -> Int {
        observations.filter { $0.category == c.rawValue }.count
    }

    var body: some View {
        SectionCard(titleKey: "profile_observations") {
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 0) {
                    CategoryBadge(symbol: "square.grid.2x2.fill", titleKey: "category_all", count: observations.count) { onSelect(galleryAllKey) }
                    CategoryBadge(symbol: "leaf.fill", titleKey: "category_plant", count: count(.plant)) { onSelect(ObservationCategory.plant.rawValue) }
                    CategoryBadge(symbol: "ant.fill", titleKey: "category_insect", count: count(.insect)) { onSelect(ObservationCategory.insect.rawValue) }
                    CategoryBadge(symbol: "bird.fill", titleKey: "category_bird", count: count(.bird)) { onSelect(ObservationCategory.bird.rawValue) }
                }
                HStack(alignment: .top, spacing: 0) {
                    CategoryBadge(symbol: "pawprint.fill", titleKey: "category_animal", count: count(.animal)) { onSelect(ObservationCategory.animal.rawValue) }
                    CategoryBadge(symbol: "mushroom", titleKey: "category_fungi", count: count(.fungi), asset: true) { onSelect(ObservationCategory.fungi.rawValue) }
                    CategoryBadge(symbol: "circle.grid.cross.fill", titleKey: "category_other", count: count(.other)) { onSelect(ObservationCategory.other.rawValue) }
                    Spacer().frame(maxWidth: .infinity)
                }
            }
        }
    }
}

struct GalleryGrid: View {
    let observations: [Observation]
    @State private var selected: Observation?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        Group {
            if observations.isEmpty {
                Text("list_empty").foregroundStyle(.secondary).padding(.vertical, 24)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(observations) { obs in
                        Button { selected = obs } label: { cell(obs) }.buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(item: $selected) { obs in
            ObservationDetailView(observation: obs).adaptiveDetents()
        }
    }

    private func cell(_ obs: Observation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemFill))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    AsyncImage(url: URL(string: obs.photoUrl)) { $0.resizable().scaledToFill() } placeholder: {
                        Color.clear
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(obs.speciesName).font(.callout).fontWeight(.medium).lineLimit(1).foregroundStyle(.primary)
            if !obs.scientificName.isEmpty {
                Text(obs.scientificName).font(.caption).italic().foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}

struct SectionCard<Content: View>: View {
    let titleKey: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titleKey).font(.headline)
            content
                .padding(16)
                .frame(maxWidth: .infinity)
                .glassCard()
        }
        .padding(.horizontal, 16)
    }
}

struct StatItem: View {
    let titleKey: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.weight(.semibold)).foregroundStyle(Color.brand)
            Text(titleKey).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CategoryBadge: View {
    let symbol: String
    let titleKey: LocalizedStringKey
    let count: Int
    var asset: Bool = false
    var onTap: () -> Void = {}

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(Color(.tertiarySystemFill)).frame(width: 48, height: 48)
                    icon.foregroundStyle(Color.brand)
                }
                Text(titleKey).font(.caption2).lineLimit(1)
                Text("\(count)").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var icon: some View {
        if asset {
            Image(symbol).renderingMode(.template).resizable().scaledToFit().frame(width: 22, height: 22)
        } else {
            Image(systemName: symbol)
        }
    }
}
