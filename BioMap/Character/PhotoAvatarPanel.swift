import SwiftUI
import UIKit
import PhotosUI

let photoTicketCost = 200

private struct EditingItem: Identifiable {
    let image: UIImage
    let id = UUID()
}

struct PhotoAvatarPanel: View {
    let uid: String?
    let user: AppUser?
    let onChanged: () -> Void

    @State private var pickedItem: PhotosPickerItem?
    @State private var editing: EditingItem?
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $pickedItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("decor_photo_pick")
                    HStack(spacing: 3) {
                        Image(systemName: "leaf.fill").font(.system(size: 11))
                        Text("\(photoTicketCost)")
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(.white.opacity(0.22)))
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.brand, in: RoundedRectangle(cornerRadius: 14))
            }
            if !(user?.avatarPhoto ?? "").isEmpty {
                Button("decor_photo_reset") {
                    let previous = user?.avatarPhoto ?? ""
                    Task {
                        if await UserRepository.applyProfilePhoto(url: "") == nil {
                            await UserRepository.deleteStoredPhoto(url: previous)
                            onChanged()
                        }
                    }
                }
                .buttonStyle(OutlineBrandButton())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .onChange(of: pickedItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    editing = EditingItem(image: image)
                }
                pickedItem = nil
            }
        }
        .fullScreenCover(item: $editing) { item in
            PhotoCropEditorView(
                source: item.image,
                busy: busy,
                onCancel: { if !busy { editing = nil } },
                onApply: { image in apply(image) }
            )
        }
        .alert(errorMessage ?? "", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("confirm", role: .cancel) {}
        }
    }

    private func apply(_ image: UIImage) {
        guard let uid, !busy, let data = image.jpegData(compressionQuality: 0.85) else { return }
        busy = true
        Task {
            let previous = user?.avatarPhoto ?? ""
            let uploaded = await UserRepository.uploadProfilePhoto(uid: uid, data: data)
            let err: String?
            if let uploaded {
                err = await UserRepository.applyProfilePhoto(url: uploaded)
                if err != nil { await UserRepository.deleteStoredPhoto(url: uploaded) }
            } else {
                err = "upload"
            }
            busy = false
            switch err {
            case nil:
                await UserRepository.deleteStoredPhoto(url: previous)
                editing = nil
                onChanged()
            case "coins":
                errorMessage = localizedFormat("decor_photo_insufficient", photoTicketCost)
            case "upload":
                errorMessage = NSLocalizedString("decor_photo_upload_failed", comment: "")
            default:
                errorMessage = NSLocalizedString("decor_photo_failed", comment: "")
            }
        }
    }
}

private struct PhotoCropEditorView: View {
    let source: UIImage
    let busy: Bool
    let onCancel: () -> Void
    let onApply: (UIImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var viewSide: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                ZStack {
                    editorCanvas(source, side: side)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .onAppear { viewSide = side }
                .onChange(of: geo.size) { _ in viewSide = min(geo.size.width, geo.size.height) }
            }
            Text("decor_photo_edit_hint")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
            HStack(spacing: 12) {
                Button("cancel", action: onCancel)
                    .buttonStyle(OutlineBrandButton())
                    .disabled(busy)
                Button {
                    guard viewSide > 0 else { return }
                    onApply(cropRegion(source, side: viewSide, scale: scale, offset: offset))
                } label: {
                    if busy {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 6) {
                            Text("decor_photo_apply_short")
                            HStack(spacing: 3) {
                                Image(systemName: "leaf.fill").font(.system(size: 11))
                                Text("\(photoTicketCost)")
                            }
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.22)))
                        }
                    }
                }
                .buttonStyle(FilledBrandButton())
                .disabled(busy)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
    }

    private func editorCanvas(_ img: UIImage, side: CGFloat) -> some View {
        let t = baseScale(img, side: side) * scale
        let off = clampOffset(offset, img: img, side: side, t: t)
        return Color.clear
            .frame(width: side, height: side)
            .overlay {
                Image(uiImage: img)
                    .resizable()
                    .frame(width: img.size.width * t, height: img.size.height * t)
                    .offset(off)
            }
            .clipped()
            .overlay { CircleMask().frame(width: side, height: side) }
            .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { v in
                    offset = clampOffset(
                        CGSize(width: lastOffset.width + v.translation.width, height: lastOffset.height + v.translation.height),
                        img: img, side: side, t: baseScale(img, side: side) * scale
                    )
                }
                .onEnded { _ in lastOffset = offset }
                .simultaneously(with:
                    MagnificationGesture()
                        .onChanged { v in
                            scale = min(max(lastScale * v, 1), 5)
                            offset = clampOffset(offset, img: img, side: side, t: baseScale(img, side: side) * scale)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            lastOffset = offset
                        }
                )
        )
    }
}

private struct CircleMask: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .mask {
                        Rectangle()
                            .overlay(Circle().frame(width: side, height: side).blendMode(.destinationOut))
                            .compositingGroup()
                    }
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: side - 2, height: side - 2)
            }
        }
        .allowsHitTesting(false)
    }
}

private func baseScale(_ img: UIImage, side: CGFloat) -> CGFloat {
    guard img.size.width > 0, img.size.height > 0, side > 0 else { return 1 }
    return max(side / img.size.width, side / img.size.height)
}

private func clampOffset(_ o: CGSize, img: UIImage, side: CGFloat, t: CGFloat) -> CGSize {
    let maxX = max((img.size.width * t - side) / 2, 0)
    let maxY = max((img.size.height * t - side) / 2, 0)
    return CGSize(width: min(max(o.width, -maxX), maxX), height: min(max(o.height, -maxY), maxY))
}

private func cropRegion(_ img: UIImage, side: CGFloat, scale: CGFloat, offset: CGSize) -> UIImage {
    let t = baseScale(img, side: side) * scale
    let off = clampOffset(offset, img: img, side: side, t: t)
    let cx = img.size.width / 2 - off.width / t
    let cy = img.size.height / 2 - off.height / t
    let half = (side / 2) / t
    let src = CGRect(x: cx - half, y: cy - half, width: half * 2, height: half * 2)
    let out: CGFloat = 512
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: out, height: out), format: .init())
    return renderer.image { _ in
        let s = out / src.width
        img.draw(in: CGRect(x: -src.minX * s, y: -src.minY * s, width: img.size.width * s, height: img.size.height * s))
    }
}
