import SwiftUI
import UIKit

struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> ConfettiUIView { ConfettiUIView() }
    func updateUIView(_ uiView: ConfettiUIView, context: Context) {}
}

final class ConfettiUIView: UIView {
    private let emitter = CAEmitterLayer()
    private var started = false

    static let palette: [UIColor] = [
        UIColor(red: 1.00, green: 0.83, blue: 0.23, alpha: 1),
        UIColor(red: 1.00, green: 0.56, blue: 0.64, alpha: 1),
        UIColor(red: 0.49, green: 0.91, blue: 0.65, alpha: 1),
        UIColor(red: 0.45, green: 0.75, blue: 0.99, alpha: 1),
        UIColor(red: 0.85, green: 0.66, blue: 1.00, alpha: 1),
        UIColor(red: 1.00, green: 0.70, blue: 0.48, alpha: 1),
        UIColor(red: 0.37, green: 0.88, blue: 0.85, alpha: 1),
        UIColor(red: 1.00, green: 0.44, blue: 0.71, alpha: 1),
    ]

    private static let rectImage: CGImage = {
        let size = CGSize(width: 8, height: 12)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return img.cgImage!
    }()

    override func layoutSubviews() {
        super.layoutSubviews()
        isUserInteractionEnabled = false
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY * 0.82)
        emitter.emitterSize = CGSize(width: 2, height: 2)
        if emitter.superlayer == nil { layer.addSublayer(emitter) }
        if !started, bounds.width > 0 { start() }
    }

    private func start() {
        started = true
        emitter.emitterShape = .point
        emitter.emitterMode = .outline
        emitter.beginTime = CACurrentMediaTime()
        emitter.emitterCells = ConfettiUIView.palette.map { cell($0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.emitter.birthRate = 0
        }
    }

    private func cell(_ color: UIColor) -> CAEmitterCell {
        let c = CAEmitterCell()
        c.contents = ConfettiUIView.rectImage
        c.color = color.cgColor
        c.birthRate = 42
        c.lifetime = 5
        c.velocity = 300
        c.velocityRange = 150
        c.emissionLongitude = -.pi / 2
        c.emissionRange = .pi
        c.yAcceleration = 240
        c.spin = 3.2
        c.spinRange = 4
        c.scale = 0.6
        c.scaleRange = 0.35
        return c
    }
}
