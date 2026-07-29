import SwiftUI
import PhotosUI
import MapKit
import CoreLocation
import FirebaseAuth

struct AddObservationView: View {
    let onDone: () -> Void
    let onCancel: () -> Void

    @StateObject private var location = LocationProvider()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showRecorder = false
    @State private var uiImage: UIImage?
    @State private var imageData: Data?
    @State private var audioData: Data?
    @StateObject private var soundPreview = SoundPlayer()
    @State private var meta = ImageMeta()
    @State private var fromCamera = false
    @State private var candidates: [SpeciesCandidate] = []
    @State private var selected: SpeciesCandidate?
    @State private var customName = ""
    @State private var customResults: [SpeciesCandidate] = []
    @State private var customPicked: SpeciesCandidate?
    @State private var customSearching = false
    @State private var note = ""
    @State private var identifying = false
    @State private var saving = false
    @State private var showSuccess = false
    @State private var pickedLocation: CLLocationCoordinate2D?
    @State private var showLocationPicker = false

    private let minConfidence = 30.0
    private var useCustom: Bool { !customName.trimmingCharacters(in: .whitespaces).isEmpty }
    private var topReliable: Bool { (candidates.first?.score ?? 0) >= minConfidence }
    private var hasLocation: Bool {
        pickedLocation != nil || meta.latitude != nil || location.coordinate != nil
    }
    private var hasMedia: Bool { imageData != nil || audioData != nil }
    private var canSave: Bool { hasMedia && topReliable && hasLocation && (useCustom || selected != nil) }

    var body: some View {
        NavigationStack {
            Group {
                if uiImage == nil && audioData == nil { pickerView } else { editView }
            }
            .navigationTitle(Text("add_observation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onCancel) { Image(systemName: "xmark") }
                }
            }
            .onAppear { location.request() }
            .overlay {
                if showSuccess {
                    ZStack {
                        Color(.systemBackground).ignoresSafeArea()
                        VStack(spacing: 10) {
                            Text("🎉").font(.system(size: 64))
                            Text("add_success_title").font(.title2.bold())
                            Text("add_success_sub").font(.subheadline).foregroundStyle(.secondary)
                        }
                        ConfettiView().ignoresSafeArea().allowsHitTesting(false)
                    }
                    .task {
                        try? await Task.sleep(nanoseconds: 2_800_000_000)
                        showSuccess = false
                        onDone()
                    }
                }
            }
            .onChange(of: pickerItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        await process(data, fromCamera: false)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { img in
                    Task { _ = await PhotoSaver.save(img) }
                    if let d = img.jpegData(compressionQuality: 1) {
                        Task { await process(d, fromCamera: true) }
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showRecorder) {
                SoundRecorderSheet { data in
                    Task { await processAudio(data) }
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(
                    initial: pickedLocation
                        ?? meta.latitude.flatMap { lat in meta.longitude.map { CLLocationCoordinate2D(latitude: lat, longitude: $0) } }
                        ?? location.coordinate
                        ?? CLLocationCoordinate2D(latitude: 36.7889, longitude: 127.0856),
                    onConfirm: { coord in pickedLocation = coord; showLocationPicker = false }
                )
            }
        }
    }

    private var pickerView: some View {
        VStack(spacing: 14) {
            Spacer()
            HStack(spacing: 14) {
                Button {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
                } label: { sourceCard("camera.fill", "take_photo") }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    sourceCard("photo.on.rectangle", "pick_gallery")
                }
            }
            Button {
                Task {
                    let ok = await AudioRecorder().requestPermission()
                    if ok { showRecorder = true }
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "waveform").font(.system(size: 28)).foregroundStyle(Color.brand)
                    Text("record_sound").font(.headline).foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .glassCard()
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 16)
        .appBackground()
    }

    private func sourceCard(_ symbol: String, _ key: LocalizedStringKey) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 36)).foregroundStyle(Color.brand)
            Text(key).font(.headline).foregroundStyle(Color.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .glassCard()
    }

    private var editView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let uiImage {
                    Image(uiImage: uiImage).resizable().scaledToFill()
                        .frame(width: 220, height: 220).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if audioData != nil {
                    soundPreviewCard
                }
                Button(audioData != nil ? "rerecord" : "retake") { reset() }
                if identifying {
                    HStack(spacing: 10) { ProgressView(); Text("identifying") }
                } else if candidates.isEmpty {
                    Text("no_candidates").foregroundStyle(.secondary).multilineTextAlignment(.center)
                } else {
                    candidateGrid
                    if !topReliable {
                        Text("low_confidence").font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                    }
                }
                if !identifying && topReliable {
                    customSpeciesField
                }
                if (!fromCamera && audioData == nil) || !hasLocation {
                    Button { showLocationPicker = true } label: {
                        Label(pickedLocation == nil ? "location_pick" : "location_set",
                              systemImage: "mappin.and.ellipse")
                    }
                    .buttonStyle(OutlineBrandButton())
                }
                if hasMedia && !hasLocation {
                    Text("location_required").font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                if !useCustom, let sel = selected,
                   ObservationCategory.fromIconicTaxon(sel.iconicTaxon) == ThemeWeek.current() {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").font(.caption2)
                        Text("theme_bonus_chip").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.brand)
                }
                TextField("note_hint", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(2...4)
                Button { Task { await save() } } label: {
                    if saving {
                        ProgressView().tint(.white)
                    } else {
                        Text("save")
                    }
                }
                .buttonStyle(FilledBrandButton())
                .disabled(!canSave || saving)
                .opacity(canSave ? 1 : 0.5)
            }
            .padding(20)
        }
    }

    private var candidateGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("select_species").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(candidates.prefix(4)) { c in candidateCard(c) }
            }
        }
    }

    private func candidateCard(_ c: SpeciesCandidate) -> some View {
        let isSel = !useCustom && selected?.id == c.id
        return Button { selected = c; customName = "" } label: {
            VStack(spacing: 4) {
                AsyncImage(url: URL(string: c.iconUrl)) { $0.resizable().scaledToFill() } placeholder: {
                    Color(.tertiarySystemFill)
                }
                .frame(height: 90).frame(maxWidth: .infinity).clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(c.name).font(.subheadline).fontWeight(.medium).lineLimit(1)
                Text(c.scientificName).font(.caption).italic().foregroundStyle(.secondary).lineLimit(1)
                Text(localizedFormat("confidence_format", Int(c.score))).font(.caption).foregroundStyle(Color.brand)
            }
            .padding(8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSel ? Color.brand : Color(.systemGray4), lineWidth: isSel ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var customSpeciesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("custom_species", text: $customName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
            if customSearching {
                ProgressView().controlSize(.small).padding(.leading, 4)
            }
            if customPicked == nil {
                ForEach(customResults) { c in
                    Button { pickCustom(c) } label: {
                        HStack(spacing: 10) {
                            AsyncImage(url: URL(string: c.iconUrl)) { $0.resizable().scaledToFill() } placeholder: {
                                Color(.tertiarySystemFill)
                            }
                            .frame(width: 36, height: 36).clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.name.isEmpty ? c.scientificName : c.name).font(.subheadline).lineLimit(1)
                                if !c.scientificName.isEmpty {
                                    Text(c.scientificName).font(.caption).italic().foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task(id: customName) {
            let q = customName.trimmingCharacters(in: .whitespaces)
            if let picked = customPicked, q != (picked.name.isEmpty ? picked.scientificName : picked.name) {
                customPicked = nil
            }
            if q.count < 2 || customPicked != nil { customResults = []; customSearching = false; return }
            customSearching = true
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            customResults = await SpeciesIdentifier.search(q)
            customSearching = false
        }
    }

    private func pickCustom(_ c: SpeciesCandidate) {
        customPicked = c
        customName = c.name.isEmpty ? c.scientificName : c.name
        customResults = []
        customSearching = false
    }

    private var soundPreviewCard: some View {
        Button {
            if let d = audioData { soundPreview.toggleData(d) }
        } label: {
            VStack(spacing: 12) {
                Image(systemName: soundPreview.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 52)).foregroundStyle(Color.brand)
                Text("sound_recorded").font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(width: 220, height: 220)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func processAudio(_ data: Data) async {
        soundPreview.stop()
        uiImage = nil
        imageData = nil
        meta = ImageMeta()
        fromCamera = false
        pickedLocation = nil
        audioData = data
        identifying = true
        candidates = []
        selected = nil
        customName = ""
        let lat = location.coordinate?.latitude
        let lng = location.coordinate?.longitude
        candidates = await SpeciesIdentifier.identifyBySound(audioData: data, lat: lat, lng: lng)
        selected = candidates.first
        identifying = false
    }

    private func process(_ rawData: Data, fromCamera: Bool) async {
        meta = readImageMeta(rawData)
        self.fromCamera = fromCamera
        pickedLocation = nil
        if !fromCamera, let lat = meta.latitude, let lng = meta.longitude {
            pickedLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        guard let ui = UIImage(data: rawData) else { return }
        uiImage = ui
        let compressed = compressForUpload(ui) ?? rawData
        imageData = compressed
        identifying = true
        candidates = []
        selected = nil
        let lat = meta.latitude ?? location.coordinate?.latitude
        let lng = meta.longitude ?? location.coordinate?.longitude
        candidates = await SpeciesIdentifier.identify(imageData: compressed, lat: lat, lng: lng)
        selected = candidates.first
        identifying = false
    }

    private func reset() {
        soundPreview.stop()
        uiImage = nil; imageData = nil; audioData = nil; candidates = []; selected = nil
        customName = ""; pickerItem = nil
        customResults = []; customPicked = nil; customSearching = false
    }

    private func save() async {
        guard hasMedia else { return }
        saving = true
        let lat = pickedLocation?.latitude ?? meta.latitude ?? location.coordinate?.latitude ?? 0
        let lng = pickedLocation?.longitude ?? meta.longitude ?? location.coordinate?.longitude ?? 0
        let fresh = freshnessValue(captureDate: meta.captureDate, fromCamera: fromCamera)
        let uid = Auth.auth().currentUser?.uid ?? ""
        let uname = Auth.auth().currentUser?.displayName ?? ""
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)
        let capturedMillis = meta.captureDate.map { Int64($0.timeIntervalSince1970 * 1000) } ?? 0
        var obs: Observation
        if useCustom {
            let trimmedName = customName.trimmingCharacters(in: .whitespaces)
            if let p = customPicked, (p.name.isEmpty ? p.scientificName : p.name) == trimmedName {
                obs = Observation(userId: uid, userName: uname, speciesName: trimmedName, scientificName: p.scientificName,
                                  category: ObservationCategory.fromIconicTaxon(p.iconicTaxon).rawValue, taxonId: p.taxonId,
                                  latitude: lat, longitude: lng, note: trimmedNote, freshness: fresh)
            } else {
                obs = Observation(userId: uid, userName: uname, speciesName: trimmedName,
                                  category: ObservationCategory.other.rawValue, latitude: lat, longitude: lng,
                                  note: trimmedNote, freshness: fresh)
            }
        } else if let s = selected {
            obs = Observation(userId: uid, userName: uname, speciesName: s.name, scientificName: s.scientificName,
                              category: ObservationCategory.fromIconicTaxon(s.iconicTaxon).rawValue, taxonId: s.taxonId,
                              latitude: lat, longitude: lng, note: trimmedNote, freshness: fresh)
        } else {
            saving = false
            return
        }
        obs.timestamp = capturedMillis
        if let audioData {
            let iconUrl = selected?.iconUrl ?? customPicked?.iconUrl ?? ""
            try? await ObservationRepository.addSound(obs, audioData: audioData, iconUrl: iconUrl)
        } else if let imageData {
            try? await ObservationRepository.add(obs, imageData: imageData)
        }
        saving = false
        showSuccess = true
    }
}

struct LocationPickerView: View {
    let initial: CLLocationCoordinate2D
    let onConfirm: (CLLocationCoordinate2D) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D

    init(initial: CLLocationCoordinate2D, onConfirm: @escaping (CLLocationCoordinate2D) -> Void) {
        self.initial = initial
        self.onConfirm = onConfirm
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: initial, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))))
        _center = State(initialValue: initial)
    }

    var body: some View {
        ZStack {
            Map(position: $position)
                .onMapCameraChange(frequency: .continuous) { ctx in center = ctx.region.center }
                .ignoresSafeArea()
            Image(systemName: "mappin")
                .font(.system(size: 38)).foregroundStyle(Color.brand)
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                .offset(y: -19)
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.headline).padding(10)
                            .glassCircle()
                    }
                    Spacer()
                }
                .padding()
                Spacer()
                Button { onConfirm(center) } label: {
                    Label("location_confirm", systemImage: "checkmark")
                }
                .buttonStyle(FilledBrandButton())
                .padding()
            }
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let img = info[.originalImage] as? UIImage { onImage(img) }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
