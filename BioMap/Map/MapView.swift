import SwiftUI
import MapKit
import CoreLocation
import FirebaseAuth

private let clusterMergeDeg = 0.0015

private struct ObsCluster: Identifiable {
    let id: String
    let center: CLLocationCoordinate2D
    let observations: [Observation]
    var perUser: Bool = false
}

private struct ClusterSelection: Identifiable {
    let id: String
    let items: [Observation]
    let nickname: String
    let emoji: String
    let bg: String
    var photo: String = ""
}

struct MapView: View {
    let refreshID: Int

    @State private var observations: [Observation] = []
    @State private var users: [AppUser] = []
    @State private var teams: [Team] = []
    @State private var selected: Observation?
    @State private var selectedCluster: ClusterSelection?
    @State private var highlighted: Observation?
    @State private var highlightedSpecies: String?

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.7889, longitude: 127.0856),
            span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        )
    )
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 36.7889, longitude: 127.0856),
        span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
    )
    @StateObject private var locationProvider = LocationProvider()
    @State private var didCenter = false
    @State private var missionsExpanded = false
    @State private var searchQuery = ""
    @State private var searchExpanded = false

    private var uid: String? { Auth.auth().currentUser?.uid }
    private var missions: [DailyMission] { Missions.today(all: observations, uid: uid) }

    private var userByUid: [String: AppUser] {
        Dictionary(users.map { ($0.uid, $0) }, uniquingKeysWith: { a, _ in a })
    }
    private var nameByUid: [String: String] {
        Dictionary(users.map { ($0.uid, $0.name) }, uniquingKeysWith: { a, _ in a })
    }
    private var borderByUid: [String: (String, String)] {
        let teamById = Dictionary(teams.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return Dictionary(users.map { u -> (String, (String, String)) in
            let t = teamById[u.teamId]
            return (u.uid, (t?.borderId ?? "white", t?.borderColor ?? "#FFFFFF"))
        }, uniquingKeysWith: { a, _ in a })
    }
    private var clusters: [ObsCluster] {
        let base = observations
            .filter { $0.latitude != 0 || $0.longitude != 0 }
            .filter { highlighted == nil || $0.id != highlighted!.id }
        return makeClusters(base, span: region.span, perUserEnabled: true)
    }

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(clusters) { cluster in
                Annotation("", coordinate: cluster.center) {
                    if cluster.observations.count == 1 {
                        let obs = cluster.observations[0]
                        let u = userByUid[obs.userId]
                        let border = borderByUid[obs.userId] ?? ("white", "#FFFFFF")
                        let resolvedName = nameByUid[obs.userId].flatMap { $0.isEmpty ? nil : $0 } ?? obs.userName
                        let speciesMatch = highlightedSpecies != nil && obs.speciesName == highlightedSpecies
                        MarkerPin(
                            emoji: u?.avatarEmoji ?? "",
                            bg: (u?.avatarBg).flatMap { $0.isEmpty ? nil : $0 } ?? ProfileDecor.defaultBg,
                            name: resolvedName,
                            borderId: border.0,
                            borderColorHex: border.1,
                            photoUrl: u?.avatarPhoto ?? ""
                        )
                        .scaleEffect(speciesMatch ? 1.6 : 1)
                        .overlay {
                            if speciesMatch {
                                Circle().stroke(Color.brand, lineWidth: 3).frame(width: 48, height: 48)
                            }
                        }
                        .onTapGesture { selected = obs }
                    } else if cluster.perUser {
                        let first = cluster.observations[0]
                        let u = userByUid[first.userId]
                        let border = borderByUid[first.userId] ?? ("white", "#FFFFFF")
                        let resolvedName = nameByUid[first.userId].flatMap { $0.isEmpty ? nil : $0 } ?? first.userName
                        let clusterMatch = highlightedSpecies != nil && cluster.observations.contains { $0.speciesName == highlightedSpecies }
                        MarkerPin(
                            emoji: u?.avatarEmoji ?? "",
                            bg: (u?.avatarBg).flatMap { $0.isEmpty ? nil : $0 } ?? ProfileDecor.defaultBg,
                            name: resolvedName,
                            borderId: border.0,
                            borderColorHex: border.1,
                            badge: cluster.observations.count,
                            photoUrl: u?.avatarPhoto ?? ""
                        )
                        .overlay {
                            if clusterMatch {
                                Circle().stroke(Color.brand, lineWidth: 3).frame(width: 48, height: 48)
                            }
                        }
                        .onTapGesture {
                            selectedCluster = ClusterSelection(
                                id: cluster.id,
                                items: cluster.observations,
                                nickname: resolvedName,
                                emoji: u?.avatarEmoji ?? "",
                                bg: (u?.avatarBg).flatMap { $0.isEmpty ? nil : $0 } ?? ProfileDecor.defaultBg,
                                photo: u?.avatarPhoto ?? ""
                            )
                        }
                    } else {
                        let clusterMatch = highlightedSpecies != nil && cluster.observations.contains { $0.speciesName == highlightedSpecies }
                        ClusterBubble(count: cluster.observations.count)
                            .overlay {
                                if clusterMatch {
                                    Circle().stroke(Color.brand, lineWidth: 3).frame(width: 42, height: 42)
                                }
                            }
                            .onTapGesture { zoomTo(cluster) }
                    }
                }
            }
            if let h = highlighted {
                let u = userByUid[h.userId]
                let border = borderByUid[h.userId] ?? ("white", "#FFFFFF")
                let resolvedName = nameByUid[h.userId].flatMap { $0.isEmpty ? nil : $0 } ?? h.userName
                Annotation(h.speciesName, coordinate: CLLocationCoordinate2D(latitude: h.latitude, longitude: h.longitude)) {
                    MarkerPin(
                        emoji: u?.avatarEmoji ?? "",
                        bg: (u?.avatarBg).flatMap { $0.isEmpty ? nil : $0 } ?? ProfileDecor.defaultBg,
                        name: resolvedName,
                        borderId: border.0,
                        borderColorHex: border.1,
                        photoUrl: u?.avatarPhoto ?? ""
                    )
                    .scaleEffect(1.6)
                    .overlay(Circle().stroke(Color.brand, lineWidth: 3).frame(width: 48, height: 48))
                    .onTapGesture { selected = h }
                }
            }
        }
        .mapControls {
            MapCompass()
        }
        .onTapGesture { highlighted = nil; highlightedSpecies = nil }
        .onMapCameraChange(frequency: .onEnd) { ctx in region = ctx.region }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if !missions.isEmpty {
                    MissionOverlay(missions: missions, expanded: $missionsExpanded)
                }
                HStack(spacing: 8) {
                    if searchExpanded {
                        MapSearchBar(
                            query: $searchQuery,
                            region: region,
                            observations: observations,
                            onPick: { r in
                                highlightedSpecies = r.isSpecies ? r.name : nil
                                withAnimation { position = .region(searchRegion(for: r)) }
                                searchExpanded = false
                            },
                            onCollapse: { highlightedSpecies = nil; withAnimation(.snappy) { searchExpanded = false } }
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        Spacer()
                        Button {
                            withAnimation(.snappy) { searchExpanded = true }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.brand)
                                .frame(width: 44, height: 44)
                                .glassCircle()
                        }
                    }
                }
            }
            .padding(.horizontal, 12).padding(.top, 8)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                guard let coord = locationProvider.coordinate else { locationProvider.request(); return }
                withAnimation {
                    position = .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brand)
                    .frame(width: 44, height: 44)
                    .glassCircle()
            }
            .padding(.trailing, 12).padding(.bottom, 6)
        }
        .task(id: refreshID) {
            observations = await ObservationRepository.getAll()
            users = await UserRepository.getAllUsers()
            teams = await TeamRepository.getAllTeams()
            let m = Missions.today(all: observations, uid: uid)
            if let uid, m.contains(where: { $0.done }) {
                await MissionRepository.syncCompletions(uid: uid, missions: m)
            }
        }
        .onAppear { locationProvider.request() }
        .onChange(of: locationProvider.coordinate?.latitude) { _, _ in
            guard !didCenter, let coord = locationProvider.coordinate else { return }
            didCenter = true
            withAnimation {
                position = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        }
        .sheet(item: $selected) { obs in
            ObservationDetailView(observation: obs, displayName: nameByUid[obs.userId].flatMap { $0.isEmpty ? nil : $0 } ?? obs.userName, onChanged: {
                Task { observations = await ObservationRepository.getAll() }
            })
            .adaptiveDetents()
        }
        .sheet(item: $selectedCluster) { sel in
            ObservationClusterSheet(
                items: sel.items,
                nickname: sel.nickname,
                emoji: sel.emoji,
                bg: sel.bg,
                photoUrl: sel.photo,
                onSelect: { obs in
                    selectedCluster = nil
                    highlighted = obs
                }
            )
        }
    }

    private func zoomTo(_ cluster: ObsCluster) {
        withAnimation {
            position = .region(MKCoordinateRegion(
                center: cluster.center,
                span: MKCoordinateSpan(
                    latitudeDelta: max(region.span.latitudeDelta / 3, 0.002),
                    longitudeDelta: max(region.span.longitudeDelta / 3, 0.002)
                )
            ))
        }
    }
}

private func makeClusters(_ obs: [Observation], span: MKCoordinateSpan, perUserEnabled: Bool) -> [ObsCluster] {
    let m = max(span.latitudeDelta, span.longitudeDelta)
    guard m > 0 else {
        return obs.map { ObsCluster(id: $0.id, center: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude), observations: [$0]) }
    }
    let qm = pow(2.0, (log2(m)).rounded(.down))
    if qm <= 0.008 {
        if !perUserEnabled {
            return obs.map { ObsCluster(id: $0.id, center: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude), observations: [$0]) }
        }
        // 1) per-user buckets (avatar + count badge), as before
        var perBuckets: [(lat: Double, lng: Double, items: [Observation])] = []
        for (_, list) in Dictionary(grouping: obs, by: { $0.userId }).sorted(by: { $0.key < $1.key }) {
            var buckets: [[Observation]] = []
            var seeds: [(Double, Double)] = []
            for o in list {
                var placed = false
                for i in seeds.indices {
                    if abs(o.latitude - seeds[i].0) < clusterMergeDeg && abs(o.longitude - seeds[i].1) < clusterMergeDeg {
                        buckets[i].append(o); placed = true; break
                    }
                }
                if !placed { buckets.append([o]); seeds.append((o.latitude, o.longitude)) }
            }
            for v in buckets {
                perBuckets.append((v.map(\.latitude).reduce(0, +) / Double(v.count),
                                   v.map(\.longitude).reduce(0, +) / Double(v.count), v))
            }
        }
        // 2) merge overlapping buckets across users into number clusters
        perBuckets.sort { $0.lat != $1.lat ? $0.lat < $1.lat : $0.lng < $1.lng }
        let crossDeg = qm * 0.12
        var groups: [[(lat: Double, lng: Double, items: [Observation])]] = []
        var gseeds: [(Double, Double)] = []
        for b in perBuckets {
            var placed = false
            for i in gseeds.indices {
                if abs(b.lat - gseeds[i].0) < crossDeg && abs(b.lng - gseeds[i].1) < crossDeg {
                    groups[i].append(b); placed = true; break
                }
            }
            if !placed { groups.append([b]); gseeds.append((b.lat, b.lng)) }
        }
        return groups.map { g in
            let all = g.flatMap { $0.items }
            let lat = all.map(\.latitude).reduce(0, +) / Double(all.count)
            let lng = all.map(\.longitude).reduce(0, +) / Double(all.count)
            let idBase = all.map { $0.id }.min() ?? ""
            let single = g.count == 1
            return ObsCluster(id: (single ? "u:" : "m:") + idBase,
                              center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                              observations: single ? g[0].items : all, perUser: single)
        }
    }
    let cell = qm / 10
    var groups: [String: [Observation]] = [:]
    for o in obs {
        let gx = (o.longitude / cell).rounded(.down)
        let gy = (o.latitude / cell).rounded(.down)
        groups["\(gx):\(gy)", default: []].append(o)
    }
    let cellKey = Int((cell * 1_000_000).rounded())
    return groups.map { key, list in
        let lat = list.map(\.latitude).reduce(0, +) / Double(list.count)
        let lng = list.map(\.longitude).reduce(0, +) / Double(list.count)
        return ObsCluster(id: "g\(cellKey):\(key)", center: CLLocationCoordinate2D(latitude: lat, longitude: lng), observations: list)
    }
}

private struct MarkerPin: View {
    let emoji: String
    let bg: String
    let name: String
    let borderId: String
    let borderColorHex: String
    var badge: Int? = nil
    var photoUrl: String = ""

    var body: some View {
        ZStack {
            EmojiAvatar(emoji: emoji, name: name, bg: bg, size: 28, fontSize: 16, photoUrl: photoUrl)
            Circle().stroke(.white, lineWidth: 2).frame(width: 28, height: 28)
            GuildBorderRing(borderId: borderId, borderColor: borderColorHex, size: 40)
        }
        .frame(width: 40, height: 40)
        .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge > 99 ? "99+" : "\(badge)")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, badge > 9 ? 4 : 0)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Circle().fill(Color.brand))
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .offset(x: 7, y: -7)
            }
        }
    }
}

private struct MissionOverlay: View {
    let missions: [DailyMission]
    @Binding var expanded: Bool

    private var doneCount: Int { missions.filter { $0.done }.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "checklist").foregroundStyle(Color.brand)
                Text("mission_title").font(.subheadline.weight(.bold))
                Spacer()
                Text("\(doneCount)/\(missions.count)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.brand)
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.snappy) { expanded.toggle() } }

            HStack(spacing: 6) {
                Text(NSLocalizedString(ThemeWeek.titleKey, comment: ""))
                    .font(.caption.weight(.bold)).foregroundStyle(Color.brand)
                Text(String(format: NSLocalizedString("theme_week_desc", comment: ""),
                            NSLocalizedString("category_\(ThemeWeek.current().rawValue)", comment: "")))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.bottom, 10)

            if expanded {
                VStack(spacing: 10) {
                    ForEach(missions) { m in
                        HStack(spacing: 10) {
                            Image(systemName: m.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(m.done ? Color.brand : Color(.tertiaryLabel))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(m.titleArg.map { String(format: NSLocalizedString(m.titleKey, comment: ""), $0) }
                                    ?? NSLocalizedString(m.titleKey, comment: ""))
                                    .font(.caption).foregroundStyle(m.done ? .secondary : .primary)
                                    .strikethrough(m.done)
                                ProgressView(value: Double(m.current), total: Double(m.target))
                                    .tint(Color.brand)
                            }
                            Text("\(m.current)/\(m.target)")
                                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
            }
        }
        .glassCard(radius: 16)
    }
}

private struct ObservationClusterSheet: View {
    let items: [Observation]
    let nickname: String
    let emoji: String
    let bg: String
    var photoUrl: String = ""
    let onSelect: (Observation) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                EmojiAvatar(emoji: emoji, name: nickname, bg: bg, size: 34, fontSize: 18, photoUrl: photoUrl)
                Text(nickname).font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: NSLocalizedString("map_cluster_count", comment: ""), items.count))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.brand)
            }
            .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 10)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { obs in
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: obs.photoUrl)) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Color(.tertiarySystemFill)
                            }
                            .frame(width: 52, height: 52)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(obs.speciesName).font(.system(size: 16, weight: .medium))
                                if !obs.scientificName.isEmpty {
                                    Text(obs.scientificName)
                                        .font(.system(size: 13)).italic().foregroundStyle(.secondary)
                                }
                                Text(formatTimestamp(obs.timestamp))
                                    .font(.system(size: 13)).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelect(obs) }
                    }
                }
            }
        }
        .adaptiveDetents()
    }
}

private struct ClusterBubble: View {
    let count: Int

    var body: some View {
        Text(count > 99 ? "99+" : "\(count)")
            .font(.subheadline.weight(.bold)).foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(Circle().fill(Color.brand))
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
    }
}

private func searchRegion(for r: GeoResult) -> MKCoordinateRegion {
    if r.isSpecies, r.coords.count > 1 {
        let lats = r.coords.map { $0.latitude }
        let lngs = r.coords.map { $0.longitude }
        let minLat = lats.min() ?? r.coordinate.latitude
        let maxLat = lats.max() ?? r.coordinate.latitude
        let minLng = lngs.min() ?? r.coordinate.longitude
        let maxLng = lngs.max() ?? r.coordinate.longitude
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.01),
            longitudeDelta: max((maxLng - minLng) * 1.4, 0.01)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
    let d = r.isSpecies ? 0.008 : 0.05
    return MKCoordinateRegion(center: r.coordinate, span: MKCoordinateSpan(latitudeDelta: d, longitudeDelta: d))
}

private struct MapSearchBar: View {
    @Binding var query: String
    let region: MKCoordinateRegion
    let observations: [Observation]
    let onPick: (GeoResult) -> Void
    let onCollapse: () -> Void

    @State private var results: [GeoResult] = []
    @State private var searching = false
    @FocusState private var focused: Bool
    private let geocoder = CLGeocoder()

    private func speciesResults(_ q: String) -> [GeoResult] {
        let matched = observations.filter {
            ($0.latitude != 0 || $0.longitude != 0) &&
            $0.speciesName.range(of: q, options: .caseInsensitive) != nil
        }
        var groups: [String: [Observation]] = [:]
        var order: [String] = []
        for o in matched {
            if groups[o.speciesName] == nil { order.append(o.speciesName) }
            groups[o.speciesName, default: []].append(o)
        }
        return order
            .sorted { (groups[$0]?.count ?? 0) > (groups[$1]?.count ?? 0) }
            .prefix(4)
            .map { nm in
                let list = groups[nm] ?? []
                let pts = list.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                return GeoResult(
                    name: nm,
                    subtitle: String(format: NSLocalizedString("map_search_spots", comment: ""), pts.count),
                    coordinate: pts.first ?? CLLocationCoordinate2D(),
                    isSpecies: true,
                    count: pts.count,
                    coords: pts,
                )
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("map_search_hint", text: $query)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        if let first = results.first {
                            onPick(first)
                        }
                    }
                if searching {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        query = ""
                        results = []
                        onCollapse()
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            if !results.isEmpty {
                Divider()
                ForEach(Array(results.prefix(6).enumerated()), id: \.offset) { _, item in
                    Button {
                        onPick(item)
                        query = ""
                        results = []
                        focused = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.isSpecies ? "eye.fill" : "mappin.circle.fill").foregroundStyle(Color.brand)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name).font(.subheadline).lineLimit(1)
                                if let sub = item.subtitle {
                                    Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 14).padding(.vertical, 9)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .glassCard(radius: 14)
        .onAppear { focused = true }
        .task(id: query) {
            let q = query.trimmingCharacters(in: .whitespaces)
            if q.count < 1 { results = []; searching = false; return }
            searching = true
            let species = speciesResults(q)
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            geocoder.cancelGeocode()
            let bias = CLCircularRegion(center: region.center, radius: 100_000, identifier: "mapSearchBias")
            let placemarks = (try? await geocoder.geocodeAddressString(q, in: bias)) ?? []
            if Task.isCancelled { return }
            results = species + placemarks.compactMap { GeoResult(placemark: $0) }
            searching = false
        }
    }
}

private struct GeoResult {
    let name: String
    let subtitle: String?
    let coordinate: CLLocationCoordinate2D
    let isSpecies: Bool
    let count: Int
    let coords: [CLLocationCoordinate2D]

    init(name: String, subtitle: String?, coordinate: CLLocationCoordinate2D, isSpecies: Bool = false, count: Int = 0, coords: [CLLocationCoordinate2D] = []) {
        self.name = name
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.isSpecies = isSpecies
        self.count = count
        self.coords = coords
    }

    init?(placemark p: CLPlacemark) {
        guard let loc = p.location else { return nil }
        let primary = p.name ?? p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? p.country ?? ""
        guard !primary.isEmpty else { return nil }
        var seen = Set<String>([primary])
        let parts = [p.locality, p.subAdministrativeArea, p.administrativeArea, p.country].compactMap { $0 }
        let unique = parts.filter { seen.insert($0).inserted }
        let sub = unique.joined(separator: " ")
        self.name = primary
        self.subtitle = sub.isEmpty ? nil : sub
        self.coordinate = loc.coordinate
        self.isSpecies = false
        self.count = 0
        self.coords = []
    }
}

final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var coordinate: CLLocationCoordinate2D?

    func request() {
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        coordinate = locations.last?.coordinate
    }
}
