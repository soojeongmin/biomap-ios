import SwiftUI
import UIKit

extension Color {
    static let brand = Color(red: 0x00 / 255, green: 0xC9 / 255, blue: 0x8A / 255)
    static let brandDark = Color(red: 0x2A / 255, green: 0x2A / 255, blue: 0x2A / 255)
    static let brandInk = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .white : UIColor(red: 0x2A / 255, green: 0x2A / 255, blue: 0x2A / 255, alpha: 1) })
    static let appBg = Color(uiColor: UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(red: 0x12 / 255, green: 0x12 / 255, blue: 0x13 / 255, alpha: 1)
            : UIColor(red: 0xF1 / 255, green: 0xF2 / 255, blue: 0xF4 / 255, alpha: 1)
    })
}

private struct GlassCardModifier: ViewModifier {
    var radius: CGFloat = 16
    var material: Material = .regularMaterial
    var shadowRadius: CGFloat = 10
    var shadowY: CGFloat = 4
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: shadowRadius, y: shadowY)
        } else {
            content
                .background(material, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.07), radius: shadowRadius, y: shadowY)
        }
    }
}

extension View {
    func glassCard(radius: CGFloat = 16, material: Material = .regularMaterial,
                   shadowRadius: CGFloat = 10, shadowY: CGFloat = 4) -> some View {
        modifier(GlassCardModifier(radius: radius, material: material, shadowRadius: shadowRadius, shadowY: shadowY))
    }

    func appBackground() -> some View {
        background(Color.appBg.ignoresSafeArea())
    }
}

struct GlassPill: ViewModifier {
    var active: Bool
    func body(content: Content) -> some View {
        let label = content
            .font(.system(size: 14, weight: active ? .semibold : .regular))
            .foregroundStyle(active ? .white : Color.primary)
            .frame(height: 34)
            .padding(.horizontal, 16)
        if active {
            label.background(Capsule().fill(Color.brand))
        } else if #available(iOS 26.0, *) {
            label.glassEffect(.regular, in: Capsule())
        } else {
            label.background(
                Capsule().fill(.regularMaterial)
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
            )
        }
    }
}

extension View {
    func glassPill(active: Bool) -> some View { modifier(GlassPill(active: active)) }
}

struct GlassCircle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
        }
    }
}

extension View {
    func glassCircle() -> some View { modifier(GlassCircle()) }
}

struct GlassCapsule: ViewModifier {
    var interactive: Bool = false
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5))
        }
    }
}

struct GlassCardClipped: ViewModifier {
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        } else {
            content
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
        }
    }
}

extension View {
    func glassCapsule(interactive: Bool = false) -> some View { modifier(GlassCapsule(interactive: interactive)) }
    func glassCardClipped(radius: CGFloat = 16) -> some View { modifier(GlassCardClipped(radius: radius)) }
}

struct TabBarGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        }
    }
}
