import SwiftUI
import Photos

func categoryName(_ key: String) -> String {
    let value: String.LocalizationValue
    switch ObservationCategory.fromKey(key) {
    case .plant: value = "category_plant"
    case .insect: value = "category_insect"
    case .fungi: value = "category_fungi"
    case .bird: value = "category_bird"
    case .animal: value = "category_animal"
    case .other: value = "category_other"
    }
    return String(localized: value)
}

private func downloadImage(_ urlString: String) async -> UIImage? {
    guard let url = URL(string: urlString) else { return nil }
    guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
    return UIImage(data: data)
}

enum PhotoSaver {
    static func save(_ image: UIImage) async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { return false }
        return await withCheckedContinuation { cont in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in cont.resume(returning: success) }
        }
    }
}

struct ShareCard: View {
    let photo: UIImage?
    let observation: Observation

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    Color(.systemGray5)
                }
            }
            .frame(width: 340, height: 300)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text(observation.speciesName)
                    .font(.system(size: 24, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                if !observation.scientificName.isEmpty {
                    Text(observation.scientificName)
                        .font(.system(size: 14)).italic()
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Text(categoryName(observation.category))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.brand)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Color.brand.opacity(0.12)))
                    Text(formatTimestamp(observation.timestamp))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Image(systemName: "person.fill").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(observation.userName.isEmpty ? "—" : observation.userName)
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18).padding(.vertical, 16)

            HStack(spacing: 10) {
                Image("AppLogoTile").resizable().scaledToFit().frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("app_name").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    Text("share_cta").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.92))
                }
                Spacer()
                Text("App Store · Google Play")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 18).padding(.vertical, 13)
            .background(
                LinearGradient(colors: [Color.brand, Color(red: 0, green: 0.66, blue: 0.47)],
                               startPoint: .leading, endPoint: .trailing)
            )
        }
        .frame(width: 340)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ShareCardSheet: View {
    let observation: Observation
    @Environment(\.dismiss) private var dismiss

    @State private var photo: UIImage?
    @State private var rendered: UIImage?
    @State private var showResult = false
    @State private var saveOk = false

    private var observationLink: URL {
        URL(string: "https://soojeongmin.github.io/biomap-legal/o/?id=\(observation.id)")
            ?? URL(string: "https://soojeongmin.github.io/biomap-legal/")!
    }

    var body: some View {
        ScrollView {
            ShareCard(photo: photo, observation: observation)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 20)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 8)
        }
        .scrollClipDisabled()
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if let rendered {
                    ShareLink(
                        item: Image(uiImage: rendered),
                        preview: SharePreview(observation.speciesName, image: Image(uiImage: rendered))
                    ) {
                        Label("share_card", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(OutlineBrandButton())
                }
                ShareLink(item: observationLink) {
                    Label("share_link", systemImage: "link")
                }
                .buttonStyle(OutlineBrandButton())
                Button { Task { await save() } } label: {
                    Label("share_save", systemImage: "arrow.down.to.line")
                }
                .buttonStyle(FilledBrandButton())
                .disabled(rendered == nil)
                .opacity(rendered == nil ? 0.5 : 1)
                Button("close") { dismiss() }
                    .buttonStyle(OutlineBrandButton(color: Color(.systemGray)))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        }
        .task {
            photo = await downloadImage(observation.photoUrl)
            rendered = renderCard()
        }
        .alert(saveOk ? Text("saved") : Text("save_failed"), isPresented: $showResult) {
            Button("close") {}
        }
    }

    @MainActor private func renderCard() -> UIImage? {
        let renderer = ImageRenderer(content: ShareCard(photo: photo, observation: observation))
        renderer.scale = 3
        return renderer.uiImage
    }

    private func save() async {
        guard let rendered else { return }
        saveOk = await PhotoSaver.save(rendered)
        showResult = true
    }
}
