import SwiftUI
import UIKit

struct DecorEmoji: Identifiable { let emoji: String; let price: Int; var id: String { emoji } }
struct DecorBg: Identifiable { let hex: String; let price: Int; var id: String { hex } }
struct DecorEffect: Identifiable { let id: String; let price: Int }
struct DecorNameColor: Identifiable { let token: String; let price: Int; var id: String { token } }

extension UIColor {
    convenience init?(hexString: String) {
        var s = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        self.init(
            red: CGFloat((v & 0xFF0000) >> 16) / 255,
            green: CGFloat((v & 0x00FF00) >> 8) / 255,
            blue: CGFloat(v & 0x0000FF) / 255,
            alpha: 1
        )
    }
}

enum ProfileDecor {
    static let modeEmoji = "emoji"
    static let defaultBg = "#E9FAF3"
    static let defaultNameColor = "#111827"

    static let emojis: [DecorEmoji] = [
        .init(emoji: "🦊", price: 0), .init(emoji: "🐰", price: 0), .init(emoji: "🐸", price: 0), .init(emoji: "🐢", price: 0),
        .init(emoji: "🐶", price: 10), .init(emoji: "🐱", price: 10), .init(emoji: "🐭", price: 10), .init(emoji: "🐹", price: 10), .init(emoji: "🐻", price: 10), .init(emoji: "🐼", price: 10), .init(emoji: "🐨", price: 10),
        .init(emoji: "🐯", price: 20), .init(emoji: "🦁", price: 20), .init(emoji: "🐮", price: 20), .init(emoji: "🐷", price: 20), .init(emoji: "🐵", price: 20), .init(emoji: "🐔", price: 20), .init(emoji: "🐧", price: 20),
        .init(emoji: "🐦", price: 30), .init(emoji: "🐤", price: 30), .init(emoji: "🦆", price: 30), .init(emoji: "🦉", price: 30), .init(emoji: "🐺", price: 30), .init(emoji: "🐗", price: 30), .init(emoji: "🐴", price: 30),
        .init(emoji: "🦄", price: 40), .init(emoji: "🐝", price: 40), .init(emoji: "🐛", price: 40), .init(emoji: "🦋", price: 40), .init(emoji: "🐌", price: 40), .init(emoji: "🐞", price: 40), .init(emoji: "🐜", price: 40),
        .init(emoji: "🦗", price: 50), .init(emoji: "🐍", price: 50), .init(emoji: "🦎", price: 50), .init(emoji: "🐙", price: 50), .init(emoji: "🦑", price: 50), .init(emoji: "🦐", price: 50), .init(emoji: "🦀", price: 50),
        .init(emoji: "🐠", price: 60), .init(emoji: "🐟", price: 60), .init(emoji: "🐬", price: 60), .init(emoji: "🐳", price: 60), .init(emoji: "🐋", price: 60), .init(emoji: "🦈", price: 60), .init(emoji: "🐊", price: 60),
        .init(emoji: "🐅", price: 70), .init(emoji: "🐆", price: 70), .init(emoji: "🦓", price: 70), .init(emoji: "🦍", price: 70), .init(emoji: "🐘", price: 70), .init(emoji: "🦛", price: 70), .init(emoji: "🦏", price: 70), .init(emoji: "🐫", price: 70), .init(emoji: "🦒", price: 70),
        .init(emoji: "🦘", price: 80), .init(emoji: "🐂", price: 80), .init(emoji: "🐄", price: 80), .init(emoji: "🐎", price: 80), .init(emoji: "🐖", price: 80), .init(emoji: "🐑", price: 80), .init(emoji: "🐐", price: 80), .init(emoji: "🦌", price: 80),
        .init(emoji: "🐕", price: 90), .init(emoji: "🐈", price: 90), .init(emoji: "🐓", price: 90), .init(emoji: "🦃", price: 90), .init(emoji: "🦚", price: 90), .init(emoji: "🦜", price: 90), .init(emoji: "🦢", price: 90), .init(emoji: "🦩", price: 90), .init(emoji: "🐇", price: 90),
        .init(emoji: "🦝", price: 100), .init(emoji: "🦨", price: 100), .init(emoji: "🦡", price: 100), .init(emoji: "🦦", price: 100), .init(emoji: "🦥", price: 100), .init(emoji: "🐀", price: 100), .init(emoji: "🐿", price: 100), .init(emoji: "🦔", price: 100),
        .init(emoji: "🌵", price: 40), .init(emoji: "🌲", price: 40), .init(emoji: "🌳", price: 40), .init(emoji: "🌴", price: 40), .init(emoji: "🌱", price: 40), .init(emoji: "🌿", price: 40), .init(emoji: "🍀", price: 40), .init(emoji: "🍃", price: 40), .init(emoji: "🍂", price: 40), .init(emoji: "🍁", price: 40), .init(emoji: "🍄", price: 40),
        .init(emoji: "🌾", price: 60), .init(emoji: "💐", price: 60), .init(emoji: "🌷", price: 60), .init(emoji: "🌹", price: 60), .init(emoji: "🌺", price: 60), .init(emoji: "🌸", price: 60), .init(emoji: "🌼", price: 60), .init(emoji: "🌻", price: 60),
        .init(emoji: "🐉", price: 150),
    ]

    static let backgrounds: [DecorBg] = [
        .init(hex: "#E9FAF3", price: 0), .init(hex: "#FFF4D6", price: 0), .init(hex: "#FDE7EC", price: 0),
        .init(hex: "#E7ECF5", price: 20), .init(hex: "#E6F8EF", price: 20), .init(hex: "#F3E8FF", price: 20),
        .init(hex: "#FCE7F3", price: 20), .init(hex: "#DCFCE7", price: 20), .init(hex: "#FFE4C4", price: 20),
        .init(hex: "#FFFACD", price: 20), .init(hex: "#D7F9E9", price: 20), .init(hex: "#FFE0E0", price: 20),
        .init(hex: "#FBE7C6", price: 20), .init(hex: "#F6EAC2", price: 20), .init(hex: "#FEF3A0", price: 20),
        .init(hex: "#FCD5CE", price: 20), .init(hex: "#D6E5BD", price: 20), .init(hex: "#C7CEEA", price: 20),
        .init(hex: "#C7F0FF", price: 40), .init(hex: "#FFD7E6", price: 40), .init(hex: "#D9D2FF", price: 40),
        .init(hex: "#E0F0FF", price: 40), .init(hex: "#E8E0FF", price: 40), .init(hex: "#D0F4DE", price: 40),
        .init(hex: "#FFCFE0", price: 40), .init(hex: "#C9E4FF", price: 40), .init(hex: "#FFEFC2", price: 40),
        .init(hex: "#E2F0CB", price: 40), .init(hex: "#F1D2FF", price: 40), .init(hex: "#B5EAD7", price: 40),
        .init(hex: "#BFD8B8", price: 40), .init(hex: "#A8D8EA", price: 40), .init(hex: "#FFDAC1", price: 40),
        .init(hex: "#FFC9A9", price: 40), .init(hex: "#FFC2D1", price: 40), .init(hex: "#FFB7C5", price: 40),
        .init(hex: "#FFB3BA", price: 70), .init(hex: "#BAFFC9", price: 70), .init(hex: "#BAE1FF", price: 70),
        .init(hex: "#FFDFBA", price: 70), .init(hex: "#FF9AA2", price: 70), .init(hex: "#D8B4FE", price: 70),
        .init(hex: "#A0F0E0", price: 70),
        .init(hex: "grad:#A1C4FD:#C2E9FB", price: 150), .init(hex: "grad:#FBC2EB:#A6C1EE", price: 150),
        .init(hex: "grad:#84FAB0:#8FD3F4", price: 150), .init(hex: "grad:#E0C3FC:#8EC5FC", price: 150),
        .init(hex: "grad:#FFD3A5:#FD6585", price: 200), .init(hex: "grad:#FCCB90:#D57EEB", price: 200),
        .init(hex: "grad:#F093FB:#F5576C", price: 200), .init(hex: "grad:#43E97B:#38F9D7", price: 200),
    ]

    static let effects: [DecorEffect] = [
        .init(id: "none", price: 0),
        .init(id: "float", price: 150), .init(id: "breathe", price: 150), .init(id: "tilt", price: 150),
        .init(id: "blink", price: 150), .init(id: "drift", price: 150), .init(id: "nod", price: 150),
        .init(id: "pulse", price: 200), .init(id: "bounce", price: 200), .init(id: "swing", price: 200),
        .init(id: "heartbeat", price: 200), .init(id: "shake", price: 200), .init(id: "wiggle", price: 200),
        .init(id: "sparkle", price: 200), .init(id: "squish", price: 200), .init(id: "pendulum", price: 200),
        .init(id: "zoombig", price: 200), .init(id: "vibrate", price: 200), .init(id: "shiver", price: 200),
        .init(id: "wobble", price: 200), .init(id: "tickheart", price: 200),
        .init(id: "rotate", price: 250), .init(id: "tada", price: 250), .init(id: "flip", price: 250),
        .init(id: "pop", price: 250), .init(id: "jump", price: 250), .init(id: "rubber", price: 250),
        .init(id: "glow", price: 250), .init(id: "twist", price: 250), .init(id: "sway3d", price: 250),
        .init(id: "boing", price: 250), .init(id: "hop2", price: 250), .init(id: "orbit", price: 250),
    ]

    static let nameColors: [DecorNameColor] = [
        .init(token: "#111827", price: 0),
        .init(token: "#16A34A", price: 60), .init(token: "#2563EB", price: 60), .init(token: "#DB2777", price: 60), .init(token: "#EA580C", price: 60),
        .init(token: "#0F766E", price: 60), .init(token: "#059669", price: 60), .init(token: "#4D7C0F", price: 60), .init(token: "#0369A1", price: 60),
        .init(token: "#7C3AED", price: 100), .init(token: "#0891B2", price: 100), .init(token: "#CA8A04", price: 100), .init(token: "#DC2626", price: 100),
        .init(token: "#9333EA", price: 100), .init(token: "#E11D48", price: 100), .init(token: "#1E40AF", price: 100), .init(token: "#BE123C", price: 100),
        .init(token: "#7E22CE", price: 100), .init(token: "#B45309", price: 100),
        .init(token: "grad:#F093FB:#F5576C", price: 200), .init(token: "grad:#43E97B:#38F9D7", price: 200), .init(token: "grad:#FA709A:#FEE140", price: 200),
        .init(token: "grad:#FF6E7F:#BFE9FF", price: 200), .init(token: "grad:#11998E:#38EF7D", price: 200),
        .init(token: "grad:#FFD700:#FFA500", price: 280), .init(token: "grad:#C0C0C0:#808080", price: 280), .init(token: "grad:#FF00CC:#333399", price: 280),
    ]

    static let defaultOwnedEmojis = emojis.filter { $0.price == 0 }.map { $0.emoji }
    static let defaultOwnedBgs = backgrounds.filter { $0.price == 0 }.map { $0.hex }
    static let defaultOwnedEffects = effects.filter { $0.price == 0 }.map { $0.id }
    static let defaultOwnedNameColors = nameColors.filter { $0.price == 0 }.map { $0.token }

    static func ownedEmojis(_ user: AppUser?) -> Set<String> { Set(defaultOwnedEmojis + (user?.ownedEmojis ?? [])) }
    static func ownedBgs(_ user: AppUser?) -> Set<String> { Set(defaultOwnedBgs + (user?.ownedBgs ?? [])) }
    static func ownedEffects(_ user: AppUser?) -> Set<String> { Set(defaultOwnedEffects + (user?.ownedEffects ?? [])) }
    static func ownedNameColors(_ user: AppUser?) -> Set<String> { Set(defaultOwnedNameColors + (user?.ownedNameColors ?? [])) }

    static func gradientColors(_ token: String) -> [Color]? {
        guard token.hasPrefix("grad:") else { return nil }
        let parts = token.dropFirst(5).split(separator: ":").map(String.init)
        guard parts.count == 2,
              let a = UIColor(hexString: parts[0]), let b = UIColor(hexString: parts[1]) else { return nil }
        return [Color(uiColor: a), Color(uiColor: b)]
    }
}

struct DecorFill: View {
    let token: String
    var body: some View {
        if let g = ProfileDecor.gradientColors(token) {
            LinearGradient(colors: g, startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color(uiColor: UIColor(hexString: token) ?? .systemGray5)
        }
    }
}

struct DecorNameText: View {
    let text: String
    let token: String
    var font: Font = .body
    var body: some View {
        if let g = ProfileDecor.gradientColors(token) {
            Text(text).font(font)
                .foregroundStyle(LinearGradient(colors: g, startPoint: .leading, endPoint: .trailing))
        } else if token.isEmpty || token == ProfileDecor.defaultNameColor {
            Text(text).font(font).foregroundStyle(.primary)
        } else {
            Text(text).font(font)
                .foregroundStyle(Color(uiColor: UIColor(hexString: token) ?? .label))
        }
    }
}

struct EmojiAvatar: View {
    let emoji: String
    let name: String
    let bg: String
    var size: CGFloat = 150
    var fontSize: CGFloat = 78
    var effect: String = "none"
    var photoUrl: String = ""

    var body: some View {
        if !photoUrl.isEmpty {
            AsyncImage(url: URL(string: photoUrl)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    DecorFill(token: bg)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        } else {
            ZStack {
                DecorFill(token: bg)
                Group {
                    if !emoji.isEmpty {
                        Text(emoji).font(.system(size: fontSize))
                    } else {
                        Text(name.prefix(1).uppercased())
                            .font(.system(size: fontSize, weight: .bold))
                            .foregroundStyle(Color.brand)
                    }
                }
                .modifier(EffectModifier(effect: effect, size: size))
                .id(effect)
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
    }
}

private struct EffectModifier: ViewModifier {
    let effect: String
    var size: CGFloat = 150
    @State private var animate = false
    private var k: CGFloat { size / 150 }

    func body(content: Content) -> some View {
        effectView(content).onAppear { animate = effect != "none" }
    }

    @ViewBuilder private func effectView(_ content: Content) -> some View {
        switch effect {
        case "pulse":
            content.scaleEffect(animate ? 1.12 : 0.9)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animate)
        case "bounce":
            content.offset(y: animate ? -6 * k : 4 * k)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animate)
        case "rotate":
            content.rotationEffect(.degrees(animate ? 360 : 0))
                .animation(.linear(duration: 3).repeatForever(autoreverses: false), value: animate)
        case "wiggle":
            content.rotationEffect(.degrees(animate ? 12 : -12))
                .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: animate)
        case "tada":
            content.scaleEffect(animate ? 1.15 : 1.0).rotationEffect(.degrees(animate ? 6 : -6))
                .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: animate)
        case "float":
            content.offset(y: animate ? -5 * k : 5 * k)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: animate)
        case "swing":
            content.rotationEffect(.degrees(animate ? 13 : -13), anchor: .top)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animate)
        case "heartbeat":
            content.scaleEffect(animate ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: animate)
        case "flip":
            content.rotation3DEffect(.degrees(animate ? 360 : 0), axis: (x: 0, y: 1, z: 0))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: animate)
        case "shake":
            content.offset(x: animate ? 5 * k : -5 * k)
                .animation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true), value: animate)
        case "pop":
            content.scaleEffect(animate ? 1.25 : 1.0)
                .animation(.easeOut(duration: 0.5).repeatForever(autoreverses: true), value: animate)
        case "breathe":
            content.scaleEffect(animate ? 1.06 : 0.94)
                .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: animate)
        case "jump":
            content.offset(y: animate ? -14 * k : 0)
                .animation(.easeOut(duration: 0.4).repeatForever(autoreverses: true), value: animate)
        case "rubber":
            content.scaleEffect(x: animate ? 1.15 : 0.85, y: animate ? 0.85 : 1.15)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animate)
        case "tilt":
            content.rotationEffect(.degrees(animate ? 7 : -7))
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animate)
        case "blink":
            content.opacity(animate ? 0.25 : 1.0)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: animate)
        case "drift":
            content.offset(x: animate ? 7 * k : -7 * k)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animate)
        case "nod":
            content.rotation3DEffect(.degrees(animate ? 48 : 0), axis: (x: 1, y: 0, z: 0))
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: animate)
        case "sparkle":
            content.scaleEffect(animate ? 1.25 : 1.0).opacity(animate ? 0.55 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animate)
        case "squish":
            content.scaleEffect(x: animate ? 1.1 : 1.0, y: animate ? 0.65 : 1.0, anchor: .bottom)
                .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: animate)
        case "pendulum":
            content.rotationEffect(.degrees(animate ? 22 : -22), anchor: .top)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: animate)
        case "zoombig":
            content.scaleEffect(animate ? 1.28 : 0.82)
                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: animate)
        case "glow":
            content.shadow(color: Color(red: 0, green: 0.79, blue: 0.54).opacity(animate ? 0.9 : 0), radius: animate ? 12 * k : 0)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animate)
        case "twist":
            content.rotationEffect(.degrees(animate ? 10 : -10)).scaleEffect(animate ? 1.1 : 0.95)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: animate)
        case "sway3d":
            content.rotation3DEffect(.degrees(animate ? 26 : -26), axis: (x: 0, y: 1, z: 0))
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animate)
        case "boing":
            content.scaleEffect(x: animate ? 1.18 : 0.85, y: animate ? 0.82 : 1.15)
                .animation(.interpolatingSpring(stiffness: 120, damping: 5).repeatForever(autoreverses: true), value: animate)
        case "vibrate":
            content.offset(x: animate ? 1.6 * k : -1.6 * k)
                .animation(.linear(duration: 0.06).repeatForever(autoreverses: true), value: animate)
        case "shiver":
            content.rotationEffect(.degrees(animate ? 3 : -3))
                .animation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true), value: animate)
        case "wobble":
            content.rotationEffect(.degrees(animate ? 10 : -10)).offset(x: animate ? 6 * k : -6 * k)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animate)
        case "orbit":
            content.offset(x: 5 * k).rotationEffect(.degrees(animate ? 360 : 0))
                .animation(.linear(duration: 1.8).repeatForever(autoreverses: false), value: animate)
        case "hop2":
            content.keyframeAnimator(initialValue: CGFloat(0), repeating: true) { view, y in
                view.offset(y: y)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(0, duration: 0.15)
                    CubicKeyframe(-14 * k, duration: 0.18)
                    CubicKeyframe(0, duration: 0.18)
                    CubicKeyframe(-7 * k, duration: 0.14)
                    CubicKeyframe(0, duration: 0.18)
                    CubicKeyframe(0, duration: 0.55)
                }
            }
        case "tickheart":
            content.keyframeAnimator(initialValue: CGFloat(1), repeating: true) { view, s in
                view.scaleEffect(s)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(1.0, duration: 0.1)
                    CubicKeyframe(1.18, duration: 0.12)
                    CubicKeyframe(1.0, duration: 0.12)
                    CubicKeyframe(1.18, duration: 0.12)
                    CubicKeyframe(1.0, duration: 0.14)
                    CubicKeyframe(1.0, duration: 0.5)
                }
            }
        default:
            content
        }
    }
}
