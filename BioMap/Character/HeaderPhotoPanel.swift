import SwiftUI
import UIKit
import PhotosUI

let headerChangeCost = 150
let headerAspect: CGFloat = 3

private struct HeaderEditingItem: Identifiable {
    let image: UIImage
    let id = UUID()
}

struct HeaderPhotoPanel: View {
    let uid: String?
    let user: AppUser?
    let onChanged: () -> Void

    @State private var pickedItem: PhotosPickerItem?
    @State private var editing: HeaderEditingItem?
    @State private var busy = false
    @State private var errorMessage: String?

    private var isFree: Bool { !(user?.headerEverSet ?? false) }

    var body: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $pickedItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.fill.on.rectangle.fill")
                    Text("header_pick")
                    HStack(spacing: 3) {
                        if isFree {
                            Text("header_free")
                        } else {
                            Image(systemName: "leaf.fill").font(.system(size: 11))
                            Text("\(headerChangeCost)")
                        }
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
            if !(user?.avatarHeader ?? "").isEmpty {
                Button("header_remove") {
                    let previous = user?.avatarHeader ?? ""
                    Task {
                        if await UserRepository.applyProfileHeader(url: "") == nil {
                            await UserRepository.deleteStoredPhoto(url: previous)
                            onChanged()
                        }
                    }
                }
                .buttonStyle(OutlineBrandButton())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .onChange(of: pickedItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    editing = HeaderEditingItem(image: image)
                }
                pickedItem = nil
            }
        }
        .fullScreenCover(item: $editing) { item in
            HeaderCropEditorView(
                source: item.image,
                busy: busy,
                free: isFree,
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
            let previous = user?.avatarHeader ?? ""
            let uploaded = await UserRepository.uploadProfilePhoto(uid: uid, data: data)
            let err: String?
            if let uploaded {
                err = await UserRepository.applyProfileHeader(url: uploaded)
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
                errorMessage = localizedFormat("decor_photo_insufficient", headerChangeCost)
            case "upload":
                errorMessage = NSLocalizedString("decor_photo_upload_failed", comment: "")
            default:
                errorMessage = NSLocalizedString("decor_photo_failed", comment: "")
            }
        }
    }
}

private struct HeaderCropEditorView: View {
    let source: UIImage
    let busy: Bool
    let free: Bool
    let onCancel: () -> Void
    let onApply: (UIImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var frameW: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = w / headerAspect
                editorCanvas(source, w: w, h: h)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onAppear { frameW = w }
                    .onChange(of: geo.size) { _ in frameW = geo.size.width }
            }
            Text("header_edit_hint")
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24).padding(.vertical, 14)
            HStack(spacing: 12) {
                Button("cancel", action: onCancel)
                    .buttonStyle(OutlineBrandButton())
                    .disabled(busy)
                Button {
                    guard frameW > 0 else { return }
                    onApply(cropBanner(source, w: frameW, h: frameW / headerAspect, scale: scale, offset: offset))
                } label: {
                    if busy {
                        ProgressView().tint(.white)
                    } else {
                        HStack(spacing: 6) {
                            Text("decor_photo_apply_short")
                            HStack(spacing: 3) {
                                if free {
                                    Text("header_free")
                                } else {
                                    Image(systemName: "leaf.fill").font(.system(size: 11))
                                    Text("\(headerChangeCost)")
                                }
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
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
    }

    private func editorCanvas(_ img: UIImage, w: CGFloat, h: CGFloat) -> some View {
        let t = baseScaleRect(img, w: w, h: h) * scale
        let off = clampRect(offset, img: img, w: w, h: h, t: t)
        return Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                Color.clear
                    .frame(width: w, height: h)
                    .overlay {
                        Image(uiImage: img)
                            .resizable()
                            .frame(width: img.size.width * t, height: img.size.height * t)
                            .offset(off)
                    }
                    .clipped()
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 2))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { v in
                        offset = clampRect(
                            CGSize(width: lastOffset.width + v.translation.width, height: lastOffset.height + v.translation.height),
                            img: img, w: w, h: h, t: baseScaleRect(img, w: w, h: h) * scale
                        )
                    }
                    .onEnded { _ in lastOffset = offset }
                    .simultaneously(with:
                        MagnificationGesture()
                            .onChanged { v in
                                scale = min(max(lastScale * v, 1), 5)
                                offset = clampRect(offset, img: img, w: w, h: h, t: baseScaleRect(img, w: w, h: h) * scale)
                            }
                            .onEnded { _ in lastScale = scale; lastOffset = offset }
                    )
            )
    }
}

private func baseScaleRect(_ img: UIImage, w: CGFloat, h: CGFloat) -> CGFloat {
    guard img.size.width > 0, img.size.height > 0, w > 0, h > 0 else { return 1 }
    return max(w / img.size.width, h / img.size.height)
}

private func clampRect(_ o: CGSize, img: UIImage, w: CGFloat, h: CGFloat, t: CGFloat) -> CGSize {
    let maxX = max((img.size.width * t - w) / 2, 0)
    let maxY = max((img.size.height * t - h) / 2, 0)
    return CGSize(width: min(max(o.width, -maxX), maxX), height: min(max(o.height, -maxY), maxY))
}

private func cropBanner(_ img: UIImage, w: CGFloat, h: CGFloat, scale: CGFloat, offset: CGSize) -> UIImage {
    let t = baseScaleRect(img, w: w, h: h) * scale
    let off = clampRect(offset, img: img, w: w, h: h, t: t)
    let cx = img.size.width / 2 - off.width / t
    let cy = img.size.height / 2 - off.height / t
    let halfW = (w / 2) / t
    let halfH = (h / 2) / t
    let src = CGRect(x: cx - halfW, y: cy - halfH, width: halfW * 2, height: halfH * 2)
    let outW: CGFloat = 1200
    let outH: CGFloat = outW / headerAspect
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: outW, height: outH), format: .init())
    return renderer.image { _ in
        let s = outW / src.width
        img.draw(in: CGRect(x: -src.minX * s, y: -src.minY * s, width: img.size.width * s, height: img.size.height * s))
    }
}
