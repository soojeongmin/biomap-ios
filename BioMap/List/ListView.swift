import SwiftUI

private struct ListFilter: Identifiable {
    let key: String?
    let titleKey: LocalizedStringKey
    var id: String { key ?? "all" }
}

private let listFilters: [ListFilter] = [
    .init(key: nil, titleKey: "category_all"),
    .init(key: ObservationCategory.plant.rawValue, titleKey: "category_plant"),
    .init(key: ObservationCategory.insect.rawValue, titleKey: "category_insect"),
    .init(key: ObservationCategory.bird.rawValue, titleKey: "category_bird"),
    .init(key: ObservationCategory.animal.rawValue, titleKey: "category_animal"),
    .init(key: ObservationCategory.fungi.rawValue, titleKey: "category_fungi"),
    .init(key: ObservationCategory.other.rawValue, titleKey: "category_other"),
]

struct ListView: View {
    let refreshID: Int

    @State private var observations: [Observation] = []
    @State private var users: [AppUser] = []
    @State private var loading = true
    @State private var filterKey: String?
    @State private var query = ""
    @State private var selected: Observation?

    private var nameByUid: [String: String] {
        Dictionary(users.map { ($0.uid, $0.name) }, uniquingKeysWith: { a, _ in a })
    }

    private var filtered: [Observation] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return observations.filter { obs in
            (filterKey == nil || obs.category == filterKey) &&
                (q.isEmpty
                    || obs.speciesName.localizedCaseInsensitiveContains(q)
                    || obs.scientificName.localizedCaseInsensitiveContains(q))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            filterRow
            listBody
        }
        .appBackground()
        .task(id: refreshID) { await load() }
        .sheet(item: $selected) { obs in
            ObservationDetailView(observation: obs, displayName: nameByUid[obs.userId].flatMap { $0.isEmpty ? nil : $0 } ?? obs.userName, onChanged: {
                Task { await load() }
            })
            .adaptiveDetents()
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("list_search_hint", text: $query)
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .glassCard(radius: 22, shadowRadius: 18, shadowY: 1)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(listFilters) { filter in
                    let active = filterKey == filter.key
                    Button { filterKey = filter.key } label: {
                        Text(filter.titleKey).glassPill(active: active)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder private var listBody: some View {
        if loading {
            Spacer(); ProgressView().frame(maxWidth: .infinity); Spacer()
        } else if filtered.isEmpty {
            Spacer()
            Text("list_empty").foregroundStyle(.secondary).frame(maxWidth: .infinity)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    seasonBanner
                    recentStrip
                    ForEach(filtered) { obs in
                        Button { selected = obs } label: {
                            ObservationRow(observation: obs, displayName: nameByUid[obs.userId].flatMap { $0.isEmpty ? nil : $0 } ?? obs.userName)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }

    private var season: (category: String, emoji: String, key: String) {
        switch Calendar.current.component(.month, from: Date()) {
        case 3, 4, 5: return ("plant", "🌸", "season_spring")
        case 6, 7, 8: return ("insect", "🦋", "season_summer")
        case 9, 10, 11: return ("fungi", "🍄", "season_fall")
        default: return ("bird", "🐦", "season_winter")
        }
    }

    @ViewBuilder private var seasonBanner: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty && filterKey == nil {
            let s = season
            Button { withAnimation { filterKey = s.category } } label: {
                HStack(spacing: 12) {
                    Text(s.emoji).font(.system(size: 30))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("season_title").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(LocalizedStringKey(s.key)).font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.85))
                }
                .padding(16)
                .background(
                    LinearGradient(colors: [Color.brand, Color(red: 0, green: 0.66, blue: 0.47)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var recent: [Observation] {
        Array(observations.sorted { $0.timestamp > $1.timestamp }.prefix(12))
    }

    @ViewBuilder private var recentStrip: some View {
        if query.trimmingCharacters(in: .whitespaces).isEmpty && filterKey == nil && recent.count >= 3 {
            VStack(alignment: .leading, spacing: 8) {
                Text("explore_recent").font(.headline).padding(.horizontal, 2)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recent) { obs in
                            Button { selected = obs } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    AsyncImage(url: URL(string: obs.photoUrl)) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: {
                                        Color(.tertiarySystemFill)
                                    }
                                    .frame(width: 118, height: 118).clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    Text(obs.speciesName).font(.caption).lineLimit(1)
                                        .frame(width: 118, alignment: .leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func load() async {
        loading = true
        observations = await ObservationRepository.getAll()
        users = await UserRepository.getAllUsers()
        loading = false
    }
}

private struct ObservationRow: View {
    let observation: Observation
    let displayName: String

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: observation.photoUrl)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(.tertiarySystemFill)
            }
            .frame(width: 64, height: 64)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(observation.speciesName)
                    .font(.system(size: 16, weight: .medium))
                if !observation.scientificName.isEmpty {
                    Text(observation.scientificName)
                        .font(.system(size: 13))
                        .italic()
                        .foregroundStyle(.secondary)
                }
                Text("\(displayName) · \(formatTimestamp(observation.timestamp))")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                if !observation.note.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.brand)
                        Text(observation.note)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.top, 1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 10) {
                if (observation.commentCount ?? 0) > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "bubble.left").font(.system(size: 12))
                        Text("\(observation.commentCount ?? 0)").font(.system(size: 13, weight: .medium))
                    }
                }
                if observation.boomCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "hand.thumbsdown.fill")
                            .font(.system(size: 12))
                            .scaleEffect(x: -1, y: 1)
                        Text("\(observation.boomCount)").font(.system(size: 13, weight: .medium))
                    }
                }
            }
            .foregroundStyle(.secondary)
            .padding(12)
        }
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}
