import SwiftUI
import UIKit

struct ZoomableImageView: View {
    let url: String
    var onClose: () -> Void

    @State private var uiImage: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private func fittedSize(_ image: CGSize, in container: CGSize) -> CGSize {
        guard image.width > 0, image.height > 0 else { return container }
        let s = min(container.width / image.width, container.height / image.height)
        return CGSize(width: image.width * s, height: image.height * s)
    }

    private func clamp(_ proposed: CGSize, scale: CGFloat, container: CGSize) -> CGSize {
        let fit = fittedSize(uiImage?.size ?? container, in: container)
        let maxX = max(0, (fit.width * scale - container.width) / 2)
        let maxY = max(0, (fit.height * scale - container.height) / 2)
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    private func loadImage(_ string: String) async -> UIImage? {
        guard let u = URL(string: string),
              let (data, _) = try? await URLSession.shared.data(from: u) else { return nil }
        return UIImage(data: data)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                let size = geo.size
                Group {
                    if let uiImage {
                        Image(uiImage: uiImage).resizable().scaledToFit()
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = min(max(lastScale * value, 1), 6)
                                offset = clamp(offset, scale: scale, container: size)
                            }
                            .onEnded { _ in
                                lastScale = scale
                                withAnimation(.spring(response: 0.3)) {
                                    offset = clamp(offset, scale: scale, container: size)
                                }
                                lastOffset = clamp(offset, scale: scale, container: size)
                            },
                        DragGesture()
                            .onChanged { value in
                                guard scale > 1 else { return }
                                let proposed = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                                offset = clamp(proposed, scale: scale, container: size)
                            }
                            .onEnded { _ in lastOffset = offset }
                    )
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3)) {
                        if scale > 1 {
                            scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
                        } else {
                            scale = 3; lastScale = 3
                        }
                    }
                }
            }
            .ignoresSafeArea()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.trailing, 20)
            .padding(.top, 8)
        }
        .task { uiImage = await loadImage(url) }
    }
}
