import SwiftUI
import FirebaseAuth

struct DecorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var user: AppUser?
    @State private var reload = 0
    @State private var tab = 0
    @State private var pendingBuy: PendingBuy?
    @State private var preview: PreviewItem?

    struct PendingBuy: Identifiable {
        let kind: String
        let value: String
        let price: Int
        var id: String { "\(kind):\(value)" }
    }

    struct PreviewItem: Equatable {
        let kind: String
        let value: String
    }

    private var uid: String? { Auth.auth().currentUser?.uid }
    private var coins: Int { user?.coins ?? 0 }
    private var emoji: String { user?.avatarEmoji ?? "" }
    private var bg: String { (user?.avatarBg).flatMap { $0.isEmpty ? nil : $0 } ?? ProfileDecor.defaultBg }
    private var effect: String { (user?.avatarEffect).flatMap { $0.isEmpty ? nil : $0 } ?? "none" }
    private var nameColor: String { (user?.avatarNameColor).flatMap { $0.isEmpty ? nil : $0 } ?? ProfileDecor.defaultNameColor }
    private var dispEmoji: String { preview?.kind == "emoji" ? preview!.value : emoji }
    private var dispBg: String { preview?.kind == "bg" ? preview!.value : bg }
    private var dispEffect: String { preview?.kind == "effect" ? preview!.value : effect }
    private var dispNameColor: String { preview?.kind == "namecolor" ? preview!.value : nameColor }
    private var name: String { user?.name ?? Auth.auth().currentUser?.displayName ?? "" }
    private var ownedEmojis: Set<String> { ProfileDecor.ownedEmojis(user) }
    private var ownedBgs: Set<String> { ProfileDecor.ownedBgs(user) }
    private var ownedEffects: Set<String> { ProfileDecor.ownedEffects(user) }
    private var ownedNameColors: Set<String> { ProfileDecor.ownedNameColors(user) }

    var body: some View {
        VStack(spacing: 0) {
            header
            emojiPanel
        }
        .background(Color(.systemGroupedBackground))
        .task(id: reload) { if let uid { user = await UserRepository.getUser(uid) } }
        .alert("decor_buy_title", isPresented: Binding(get: { pendingBuy != nil }, set: { if !$0 { pendingBuy = nil } }), presenting: pendingBuy) { buy in
            Button("cancel", role: .cancel) {}
            Button("decor_buy_confirm") { performBuy(buy) }
        } message: { buy in
            Text(String(format: NSLocalizedString("decor_buy_message", comment: ""), buy.price))
        }
    }

    private func performBuy(_ buy: PendingBuy) {
        guard let uid else { return }
        Task {
            if await UserRepository.buyDecor(kind: buy.kind, value: buy.value) {
                switch buy.kind {
                case "emoji": await UserRepository.setAvatarEmoji(uid: uid, emoji: buy.value)
                case "bg": await UserRepository.setAvatarBg(uid: uid, hex: buy.value)
                case "effect": await UserRepository.setAvatarEffect(uid: uid, effect: buy.value)
                case "namecolor": await UserRepository.setAvatarNameColor(uid: uid, token: buy.value)
                default: break
                }
                preview = nil
                reload += 1
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.title3.weight(.semibold))
            }
            Text("customize_title").font(.title2.bold())
            Spacer()
            Image(systemName: "leaf.fill").foregroundStyle(Color.brand)
            Text("\(coins)").font(.headline).foregroundStyle(Color.brand)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var emojiPanel: some View {
        VStack(spacing: 0) {
            EmojiAvatar(emoji: dispEmoji, name: name, bg: dispBg, size: 120, fontSize: 64, effect: dispEffect,
                        photoUrl: preview == nil ? (user?.avatarPhoto ?? "") : "")
                .padding(.top, 8)
            DecorNameText(text: name.isEmpty ? "—" : name, token: dispNameColor, font: .headline)
            if preview != nil {
                Text("customize_previewing").font(.caption2).foregroundStyle(Color.brand)
            }
            Color.clear.frame(height: 8)
            Picker("", selection: $tab) {
                Text("decor_tab_emoji").tag(0)
                Text("decor_tab_bg").tag(1)
                Text("decor_tab_effect").tag(2)
                Text("decor_tab_name").tag(3)
                Text("decor_tab_photo").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.bottom, 6)

            ScrollView {
                switch tab {
                case 0:
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(ProfileDecor.emojis) { emojiCell($0) }
                    }.padding(16)
                case 1:
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(ProfileDecor.backgrounds) { bgCell($0) }
                    }.padding(16)
                case 2:
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(ProfileDecor.effects) { effectCell($0) }
                    }.padding(16)
                case 3:
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                        ForEach(ProfileDecor.nameColors) { nameColorCell($0) }
                    }.padding(16)
                default:
                    VStack(spacing: 8) {
                        PhotoAvatarPanel(uid: uid, user: user) {
                            preview = nil
                            reload += 1
                        }
                        Divider().padding(.horizontal, 20).padding(.vertical, 4)
                        HeaderPhotoPanel(uid: uid, user: user) {
                            preview = nil
                            reload += 1
                        }
                    }
                }
            }
        }
    }

    private func isPreviewing(_ kind: String, _ value: String) -> Bool {
        preview == PreviewItem(kind: kind, value: value)
    }

    @ViewBuilder
    private func priceTag(_ price: Int, previewing: Bool) -> some View {
        if previewing {
            HStack(spacing: 3) {
                Text("decor_buy_confirm")
                Text("\(price)")
            }
            .font(.caption2.weight(.bold)).foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(coins >= price ? Color.brand : Color.secondary))
        } else {
            HStack(spacing: 2) {
                Image(systemName: "leaf.fill").font(.system(size: 10))
                Text("\(price)").font(.caption2.weight(.bold))
            }.foregroundStyle(coins >= price ? Color.brand : .secondary)
        }
    }

    private func effectCell(_ item: DecorEffect) -> some View {
        let isOwned = ownedEffects.contains(item.id)
        let selected = effect == item.id
        let previewing = isPreviewing("effect", item.id)
        return Button {
            guard let uid else { return }
            if isOwned {
                preview = nil
                Task { await UserRepository.setAvatarEffect(uid: uid, effect: item.id); reload += 1 }
            } else if previewing {
                pendingBuy = PendingBuy(kind: "effect", value: item.id, price: item.price)
            } else {
                preview = PreviewItem(kind: "effect", value: item.id)
            }
        } label: {
            VStack(spacing: 6) {
                EmojiAvatar(emoji: emoji.isEmpty ? "🦊" : emoji, name: name, bg: bg, size: 52, fontSize: 30, effect: item.id)
                Text(NSLocalizedString("effect_\(item.id)", comment: "")).font(.caption2)
                if selected {
                    Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Color.brand)
                } else if !isOwned {
                    priceTag(item.price, previewing: previewing)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected || previewing ? Color.brand : Color(.separator), lineWidth: selected || previewing ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func nameColorCell(_ item: DecorNameColor) -> some View {
        let isOwned = ownedNameColors.contains(item.token)
        let selected = nameColor.caseInsensitiveCompare(item.token) == .orderedSame
        let previewing = isPreviewing("namecolor", item.token)
        return Button {
            guard let uid else { return }
            if isOwned {
                preview = nil
                Task { await UserRepository.setAvatarNameColor(uid: uid, token: item.token); reload += 1 }
            } else if previewing {
                pendingBuy = PendingBuy(kind: "namecolor", value: item.token, price: item.price)
            } else {
                preview = PreviewItem(kind: "namecolor", value: item.token)
            }
        } label: {
            VStack(spacing: 6) {
                DecorNameText(text: "Aa", token: item.token, font: .title3.weight(.bold))
                if selected {
                    Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Color.brand)
                } else if !isOwned {
                    priceTag(item.price, previewing: previewing)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected || previewing ? Color.brand : Color(.separator), lineWidth: selected || previewing ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func emojiCell(_ item: DecorEmoji) -> some View {
        let isOwned = ownedEmojis.contains(item.emoji)
        let selected = emoji == item.emoji
        let previewing = isPreviewing("emoji", item.emoji)
        return Button {
            guard let uid else { return }
            if isOwned {
                preview = nil
                Task { await UserRepository.setAvatarEmoji(uid: uid, emoji: item.emoji); reload += 1 }
            } else if previewing {
                pendingBuy = PendingBuy(kind: "emoji", value: item.emoji, price: item.price)
            } else {
                preview = PreviewItem(kind: "emoji", value: item.emoji)
            }
        } label: {
            VStack(spacing: 6) {
                Text(item.emoji).font(.system(size: 32))
                if selected {
                    Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Color.brand)
                } else if !isOwned {
                    priceTag(item.price, previewing: previewing)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected || previewing ? Color.brand : Color(.separator), lineWidth: selected || previewing ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func bgCell(_ item: DecorBg) -> some View {
        let isOwned = ownedBgs.contains(item.hex)
        let selected = bg.caseInsensitiveCompare(item.hex) == .orderedSame
        let previewing = isPreviewing("bg", item.hex)
        return Button {
            guard let uid else { return }
            if isOwned {
                preview = nil
                Task { await UserRepository.setAvatarBg(uid: uid, hex: item.hex); reload += 1 }
            } else if previewing {
                pendingBuy = PendingBuy(kind: "bg", value: item.hex, price: item.price)
            } else {
                preview = PreviewItem(kind: "bg", value: item.hex)
            }
        } label: {
            DecorFill(token: item.hex)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    RoundedRectangle(cornerRadius: 16).stroke(selected || previewing ? Color.brand : Color(.separator), lineWidth: selected || previewing ? 3 : 1)
                    if selected { Image(systemName: "checkmark").foregroundStyle(Color.brand).font(.headline) }
                    else if !isOwned { priceTag(item.price, previewing: previewing) }
                }
        }
        .buttonStyle(.plain)
    }
}
