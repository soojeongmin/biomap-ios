import SwiftUI

struct ComingSoon: View {
    let symbol: String
    let messageKey: LocalizedStringKey

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 52))
                .foregroundStyle(Color.brand.opacity(0.7))
            Text(messageKey).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FilledBrandButton: ButtonStyle {
    var color: Color = .brand
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

struct OutlineBrandButton: ButtonStyle {
    var color: Color = .brand
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

struct PillBrandButton: ButtonStyle {
    var color: Color = .brand
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

struct AvatarCircle: View {
    let avatarUrl: String?
    let name: String
    var size: CGFloat = 40
    var fontSize: CGFloat = 16

    var body: some View {
        Group {
            if let avatarUrl, let url = URL(string: avatarUrl), !avatarUrl.isEmpty {
                AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { initial }
            } else {
                initial
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initial: some View {
        ZStack {
            Circle().fill(.white)
            Circle().fill(Color.brand).padding(size * 0.07)
            Text(name.prefix(1).uppercased())
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
