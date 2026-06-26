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
        VStack(spacing: 10) {
            Group {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFill()
                } else {
                    Color(.systemGray5)
                }
            }
            .frame(width: 260, height: 260)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text(observation.speciesName)
                    .font(.system(size: 22, weight: .bold))
                if !observation.scientificName.isEmpty {
                    Text(observation.scientificName)
                        .font(.system(size: 14)).italic()
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "person.fill").font(.system(size: 13)).foregroundStyle(Color.brand)
                    Text(observation.userName.isEmpty ? "—" : observation.userName)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("\(categoryName(observation.category)) · \(formatTimestamp(observation.timestamp))")
                    .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    Image("SplashLogo").resizable().scaledToFit().frame(width: 26, height: 26)
                    Text("app_name").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.brand)
                }
            }
        }
        .frame(width: 300)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(Color(.systemBackground))
    }
}

struct ShareCardSheet: View {
    let observation: Observation
    @Environment(\.dismiss) private var dismiss

    @State private var photo: UIImage?
    @State private var rendered: UIImage?
    @State private var showResult = false
    @State private var saveOk = false

    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                ShareCard(photo: photo, observation: observation)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.15), radius: 20)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            }
            .scrollClipDisabled()
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
                Button { Task { await save() } } label: {
                    Label("share_save", systemImage: "arrow.down.to.line")
                }
                .buttonStyle(FilledBrandButton())
                .disabled(rendered == nil)
                .opacity(rendered == nil ? 0.5 : 1)
                Button("close") { dismiss() }
                    .buttonStyle(OutlineBrandButton(color: Color(.systemGray)))
            }
        }
        .padding(20)
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
