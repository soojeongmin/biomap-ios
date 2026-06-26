import SwiftUI
import UIKit
import CoreLocation
import FirebaseAuth

func reverseGeocodeDong(_ lat: Double, _ lng: Double) async -> String {
    guard lat != 0 || lng != 0 else { return "" }
    let loc = CLLocation(latitude: lat, longitude: lng)
    guard let p = try? await CLGeocoder().reverseGeocodeLocation(loc, preferredLocale: Locale(identifier: "ko_KR")).first else { return "" }
    let city = p.locality ?? p.subAdministrativeArea
    let dong = p.subLocality ?? p.thoroughfare
    return [city, dong].compactMap { $0 }.joined(separator: " ")
}

func categoryLabelKey(_ key: String) -> LocalizedStringKey {
    switch ObservationCategory.fromKey(key) {
    case .plant: return "category_plant"
    case .insect: return "category_insect"
    case .fungi: return "category_fungi"
    case .bird: return "category_bird"
    case .animal: return "category_animal"
    case .other: return "category_other"
    }
}

struct ObservationDetailView: View {
    let observation: Observation
    var displayName: String? = nil
    var onChanged: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var suggestions: [Suggestion] = []
    @State private var showSuggest = false
    @State private var working = false
    @State private var selectedUser: UserRef?
    @State private var showShareCard = false
    @StateObject private var player = SoundPlayer()
    @State private var boomed = false
    @State private var boomCount = 0
    @State private var boomWorking = false
    @State private var locationText = ""
    @State private var showEdit = false
    @State private var editSpeciesName = ""
    @State private var editScientificName = ""
    @State private var editNote = ""
    @State private var comments: [Comment] = []
    @State private var commentText = ""
    @State private var commentSending = false
    @FocusState private var commentFocused: Bool

    private var currentUid: String? { Auth.auth().currentUser?.uid }
    private var isOwner: Bool { observation.userId == currentUid }
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private var boomButton: some View {
        Button {
            if boomWorking { return }
            let prevBoomed = boomed
            let prevCount = boomCount
            boomWorking = true
            boomed.toggle()
            boomCount = prevCount + (boomed ? 1 : -1)
            Task {
                if let res = await ObservationRepository.toggleBoom(observation.id) {
                    boomed = res.boomed
                    boomCount = res.count
                } else {
                    boomed = prevBoomed
                    boomCount = prevCount
                }
                boomWorking = false
                onChanged()
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: boomed ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 22))
                    .scaleEffect(x: -1, y: 1)
                    .foregroundStyle(boomed ? Color.brand : Color.secondary)
                if boomCount > 0 {
                    Text("\(boomCount)").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 44)
        }
        .buttonStyle(.plain)
        .disabled(boomWorking)
    }

    private var commentCountButton: some View {
        Button { commentFocused = true } label: {
            VStack(spacing: 2) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.secondary)
                if !comments.isEmpty {
                    Text("\(comments.count)").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 44)
        }
        .buttonStyle(.plain)
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().padding(.vertical, 2)
            Text("comments_title").font(.headline).foregroundStyle(.primary)
            if comments.isEmpty {
                Text("comment_empty").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(comments) { commentRow($0) }
            }
            HStack(spacing: 8) {
                TextField("comment_hint", text: $commentText, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($commentFocused)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .glassCard(radius: 14)
                Button { Task { await sendComment() } } label: {
                    Text("comment_send").fontWeight(.semibold)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Capsule().fill(Color.brand))
                        .foregroundStyle(.white)
                }
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || commentSending)
            }
        }
    }

    private func commentRow(_ c: Comment) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(c.authorName.isEmpty ? "—" : c.authorName)
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(c.text).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if c.authorId == currentUid {
                Button { Task { await deleteComment(c) } } label: {
                    Image(systemName: "xmark").font(.caption2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func sendComment() async {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let uid = currentUid, !commentSending else { return }
        commentSending = true
        let name = await UserRepository.getUser(uid)?.name ?? Auth.auth().currentUser?.displayName ?? ""
        try? await ObservationRepository.addComment(observation.id, authorId: uid, authorName: name, text: trimmed)
        commentText = ""
        commentFocused = false
        comments = await ObservationRepository.getComments(observation.id)
        commentSending = false
        onChanged()
    }

    private func deleteComment(_ c: Comment) async {
        try? await ObservationRepository.deleteComment(observation.id, c.id)
        comments = await ObservationRepository.getComments(observation.id)
        onChanged()
    }

    private func soundOverlay(_ audio: String) -> some View {
        ZStack {
            Color.black.opacity(0.18)
            Button {
                if let url = URL(string: audio) { player.toggleURL(url) }
            } label: {
                Image(systemName: player.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white)
                    .shadow(radius: 6)
            }
            VStack {
                HStack {
                    Label("sound_observation", systemImage: "waveform")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .glassCapsule()
                    Spacer()
                }
                Spacer()
            }
            .padding(12)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.tertiarySystemFill))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        AsyncImage(url: URL(string: observation.photoUrl)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.clear
                        }
                    }
                    .overlay {
                        if observation.isSound, let audio = observation.audioUrl, !audio.isEmpty {
                            soundOverlay(audio)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(observation.speciesName)
                            .font(.title2.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                        if !observation.scientificName.isEmpty {
                            Text(observation.scientificName)
                                .font(.body).italic().foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(categoryLabelKey(observation.category))
                            .font(.subheadline).foregroundStyle(Color.brand)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    boomButton
                    commentCountButton
                }

                let shownName = displayName ?? observation.userName
                VStack(alignment: .leading, spacing: 6) {
                    if !isOwner && !observation.userId.isEmpty {
                        Button {
                            selectedUser = UserRef(id: observation.userId, name: shownName)
                        } label: {
                            infoRow("person.fill", shownName).foregroundStyle(Color.brand)
                        }
                        .buttonStyle(.plain)
                    } else {
                        infoRow("person.fill", shownName)
                    }
                    infoRow("clock", formatTimestamp(observation.timestamp))
                    if !locationText.isEmpty {
                        infoRow("mappin.and.ellipse", locationText)
                    }
                }

                if !observation.note.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("detail_note", systemImage: "note.text")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.brand)
                        Text(observation.note).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .glassCard()
                }

                if !suggestions.isEmpty {
                    Text("suggestions_title").font(.headline).padding(.top, 4)
                    ForEach(suggestions) { suggestion in
                        suggestionRow(suggestion)
                    }
                }

                commentsSection

                actionButtons
            }
            .padding(20)
        }
        .task(id: observation.id) {
            boomed = observation.isBoomed(by: currentUid)
            boomCount = observation.boomCount
            suggestions = await loadSuggestions()
            comments = await ObservationRepository.getComments(observation.id)
            locationText = await reverseGeocodeDong(observation.latitude, observation.longitude)
        }
        .sheet(isPresented: $showSuggest) {
            SuggestSheet { candidate in
                guard !isDuplicate(candidate) else { return false }
                await submitSuggestion(candidate)
                return true
            }
            .largeSheet()
        }
        .sheet(item: $selectedUser) { ref in
            UserProfileSheet(userId: ref.id, userName: ref.name)
                .largeSheet()
        }
        .sheet(isPresented: $showShareCard) {
            ShareCardSheet(observation: observation)
                .largeSheet()
        }
        .sheet(isPresented: $showEdit) {
            EditObservationSheet(
                speciesName: $editSpeciesName,
                scientificName: $editScientificName,
                note: $editNote
            ) {
                await saveEdit()
            }
            .largeSheet()
        }
    }

    @ViewBuilder private var actionButtons: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            if !observation.photoUrl.isEmpty {
                Button { showShareCard = true } label: {
                    Label("share_card", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(OutlineBrandButton())
            }

            if !isOwner && currentUid != nil {
                Button { showSuggest = true } label: {
                    Label("suggest_button", systemImage: "plus")
                }
                .buttonStyle(OutlineBrandButton())
            }

            if isOwner {
                Button {
                    editSpeciesName = observation.speciesName
                    editScientificName = observation.scientificName
                    editNote = observation.note
                    showEdit = true
                } label: {
                    Label("edit_observation", systemImage: "pencil")
                }
                .buttonStyle(OutlineBrandButton())
                .disabled(working)

                Button {
                    Task { await deleteObservation() }
                } label: {
                    Label("delete", systemImage: "trash")
                }
                .buttonStyle(OutlineBrandButton(color: .red))
                .disabled(working)
            }
        }
        .padding(.top, 8)
    }

    private func infoRow(_ symbol: String, _ value: String) -> some View {
        Group {
            if !value.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: symbol).foregroundStyle(.secondary)
                    Text(value)
                }
            }
        }
    }

    private func suggestionRow(_ suggestion: Suggestion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.speciesName).fontWeight(.medium)
                if !suggestion.scientificName.isEmpty {
                    Text(suggestion.scientificName).font(.caption).italic().foregroundStyle(.secondary)
                }
                Text(suggestion.suggesterName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if suggestion.accepted == true {
                Text("suggestion_accepted_badge").font(.caption.weight(.semibold)).foregroundStyle(Color.brand)
            } else {
                if isOwner {
                    Button("apply_suggestion") { Task { await apply(suggestion) } }
                        .font(.subheadline)
                }
                if suggestion.suggesterId == currentUid {
                    Button("delete", role: .destructive) { Task { await deleteSuggestion(suggestion) } }
                        .font(.subheadline)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func isDuplicate(_ candidate: SpeciesCandidate) -> Bool {
        func same(_ name: String, _ sci: String, _ taxonId: Int64) -> Bool {
            if candidate.taxonId != 0 && candidate.taxonId == taxonId { return true }
            if !candidate.scientificName.isEmpty && candidate.scientificName.caseInsensitiveCompare(sci) == .orderedSame { return true }
            let display = candidate.name.isEmpty ? candidate.scientificName : candidate.name
            return display.caseInsensitiveCompare(name) == .orderedSame
        }
        if same(observation.speciesName, observation.scientificName, observation.taxonId) { return true }
        return suggestions.contains { same($0.speciesName, $0.scientificName, $0.taxonId) }
    }

    private func submitSuggestion(_ candidate: SpeciesCandidate) async {
        let suggestion = Suggestion(
            suggesterId: currentUid ?? "",
            suggesterName: Auth.auth().currentUser?.displayName ?? "",
            speciesName: candidate.name.isEmpty ? candidate.scientificName : candidate.name,
            scientificName: candidate.scientificName,
            category: ObservationCategory.fromIconicTaxon(candidate.iconicTaxon).rawValue,
            taxonId: candidate.taxonId
        )
        try? await ObservationRepository.addSuggestion(observation.id, suggestion)
        suggestions = await loadSuggestions()
    }

    private func loadSuggestions() async -> [Suggestion] {
        let loaded = await ObservationRepository.getSuggestions(observation.id)
        var names: [String: String] = [:]
        for id in Set(loaded.map { $0.suggesterId }).filter({ !$0.isEmpty }) {
            if let name = await UserRepository.getUser(id)?.name, !name.isEmpty {
                names[id] = name
            }
        }
        return loaded.map { s in
            guard let fresh = names[s.suggesterId] else { return s }
            var copy = s
            copy.suggesterName = fresh
            return copy
        }
    }

    private func apply(_ suggestion: Suggestion) async {
        working = true
        try? await ObservationRepository.acceptSuggestion(observation.id, suggestion.id)
        working = false
        onChanged()
        dismiss()
    }

    private func deleteSuggestion(_ suggestion: Suggestion) async {
        try? await ObservationRepository.deleteSuggestion(observation.id, suggestion.id)
        suggestions = await loadSuggestions()
    }

    private func saveEdit() async {
        working = true
        let ok = await ObservationRepository.updateFields(
            id: observation.id,
            speciesName: editSpeciesName.trimmingCharacters(in: .whitespacesAndNewlines),
            scientificName: editScientificName.trimmingCharacters(in: .whitespacesAndNewlines),
            note: editNote.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        working = false
        if ok {
            onChanged()
            dismiss()
        }
    }

    private func deleteObservation() async {
        working = true
        try? await ObservationRepository.delete(observation)
        working = false
        onChanged()
        dismiss()
    }
}

private struct EditObservationSheet: View {
    @Binding var speciesName: String
    @Binding var scientificName: String
    @Binding var note: String
    let onSave: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var saving = false
    @State private var results: [SpeciesCandidate] = []
    @State private var searching = false
    @State private var lastPicked = "\u{0}"

    var body: some View {
        NavigationStack {
            Form {
                Section("edit_species_name") {
                    TextField("edit_species_name", text: $speciesName)
                        .autocorrectionDisabled()
                    if searching {
                        ProgressView()
                    }
                    ForEach(results) { c in
                        Button {
                            speciesName = c.name.isEmpty ? c.scientificName : c.name
                            scientificName = c.scientificName
                            lastPicked = speciesName
                            results = []
                        } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: URL(string: c.iconUrl)) { $0.resizable().scaledToFill() } placeholder: {
                                    Color(.tertiarySystemFill)
                                }
                                .frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name.isEmpty ? c.scientificName : c.name).fontWeight(.medium).lineLimit(1)
                                    if !c.scientificName.isEmpty {
                                        Text(c.scientificName).font(.caption).italic().foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section("edit_scientific_name") {
                    TextField("edit_scientific_name", text: $scientificName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section("edit_note") {
                    TextField("edit_note", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(Text("edit_observation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        if saving { return }
                        saving = true
                        Task {
                            await onSave()
                            saving = false
                        }
                    }
                    .disabled(saving || speciesName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task(id: speciesName) {
                let q = speciesName.trimmingCharacters(in: .whitespaces)
                if q.count < 2 || q == lastPicked.trimmingCharacters(in: .whitespaces) {
                    results = []
                    searching = false
                    return
                }
                searching = true
                try? await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }
                results = await SpeciesIdentifier.search(q)
                searching = false
            }
        }
    }
}

private struct SuggestSheet: View {
    let onSubmit: (SpeciesCandidate) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SpeciesCandidate] = []
    @State private var searching = false
    @State private var showDuplicate = false
    @State private var submitting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("suggest_search_hint", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 4)
                if showDuplicate {
                    Text("suggest_duplicate")
                        .font(.caption).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.bottom, 4)
                }
                if searching {
                    ProgressView().padding()
                } else if query.trimmingCharacters(in: .whitespaces).count >= 2 && results.isEmpty {
                    Text("suggest_search_empty").font(.subheadline).foregroundStyle(.secondary).padding()
                }
                List(results) { c in
                    Button {
                        if submitting { return }
                        submitting = true
                        showDuplicate = false
                        Task {
                            if await onSubmit(c) {
                                dismiss()
                            } else {
                                showDuplicate = true
                                submitting = false
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: c.iconUrl)) { $0.resizable().scaledToFill() } placeholder: {
                                Color(.tertiarySystemFill)
                            }
                            .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.name.isEmpty ? c.scientificName : c.name).fontWeight(.medium).lineLimit(1)
                                if !c.scientificName.isEmpty {
                                    Text(c.scientificName).font(.caption).italic().foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            .navigationTitle(Text("suggest_button"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
            }
            .task(id: query) {
                let q = query.trimmingCharacters(in: .whitespaces)
                if q.count < 2 { results = []; searching = false; return }
                searching = true
                try? await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }
                results = await SpeciesIdentifier.search(q)
                searching = false
            }
        }
    }
}
