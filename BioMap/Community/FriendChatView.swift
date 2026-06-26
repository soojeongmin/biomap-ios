import SwiftUI
import FirebaseFirestore

final class DmChatStore: ObservableObject {
    @Published var messages: [ChatMessage] = []
    private var listener: ListenerRegistration?

    func start(convId: String) {
        guard listener == nil, !convId.isEmpty else { return }
        listener = Firestore.firestore().collection("dms").document(convId).collection("messages")
            .order(by: "at", descending: false)
            .limit(toLast: 300)
            .addSnapshotListener { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                self?.messages = docs.map { ChatMessage(firestore: $0.data(), id: $0.documentID) }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }
}

enum FriendChat {
    static func convId(_ a: String, _ b: String) -> String { [a, b].sorted().joined(separator: "_") }

    static func send(convId: String, me: AppUser, text: String) async {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        guard !convId.isEmpty, !trimmed.isEmpty else { return }
        let ref = Firestore.firestore().collection("dms").document(convId).collection("messages").document()
        try? await ref.setData([
            "id": ref.documentID, "uid": me.uid, "name": me.name, "emoji": me.avatarEmoji,
            "bg": me.avatarBg, "nameColor": me.avatarNameColor, "text": trimmed,
            "at": Int64(Date().timeIntervalSince1970 * 1000),
        ])
    }
}

struct FriendChatView: View {
    let peer: AppUser
    let me: AppUser
    let onBack: () -> Void

    @StateObject private var store = DmChatStore()
    @State private var input = ""

    private var convId: String { FriendChat.convId(me.uid, peer.uid) }
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = .current; f.dateFormat = "a h:mm"; return f
    }()
    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = .current; f.dateFormat = "yyyy. M. d. EEEE"; return f
    }()
    private func time(_ at: Int64) -> String {
        Self.timeFmt.string(from: Date(timeIntervalSince1970: Double(at) / 1000))
    }

    private enum DmRow: Identifiable {
        case date(String)
        case message(ChatMessage)
        var id: String { switch self { case .date(let d): return "d:\(d)"; case .message(let m): return m.id } }
    }
    private var rows: [DmRow] {
        var out: [DmRow] = []
        var lastDay = ""
        for m in store.messages {
            let day = Self.dayFmt.string(from: Date(timeIntervalSince1970: Double(m.at) / 1000))
            if day != lastDay { out.append(.date(day)); lastDay = day }
            out.append(.message(m))
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onBack) { Image(systemName: "chevron.left").font(.body.weight(.semibold)) }
                EmojiAvatar(emoji: peer.avatarEmoji, name: peer.name, bg: peer.avatarBg, size: 30, fontSize: 16, photoUrl: peer.avatarPhoto)
                Text(peer.name.isEmpty ? "—" : peer.name).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            Divider()

            if store.messages.isEmpty {
                Spacer()
                Text("dm_empty").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(rows) { row in
                                switch row {
                                case .date(let d):
                                    Text(d).font(.caption2).foregroundStyle(.secondary).padding(.vertical, 8)
                                case .message(let m):
                                    bubble(m).id(m.id)
                                }
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: store.messages.count) { _, _ in
                        if let last = store.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                    .onAppear {
                        if let last = store.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()
            HStack(spacing: 8) {
                TextField("dm_hint", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(Color(.secondarySystemBackground)))
                    .overlay(Capsule().stroke(Color(.separator), lineWidth: 0.5))
                    .onChange(of: input) { _, v in if v.count > 500 { input = String(v.prefix(500)) } }
                let canSend = !input.trimmingCharacters(in: .whitespaces).isEmpty
                Button {
                    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    input = ""
                    Task { await FriendChat.send(convId: convId, me: me, text: text) }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(canSend ? Color.brand : Color.secondary))
                }
                .disabled(!canSend)
            }
            .padding(8)
        }
        .onAppear { store.start(convId: convId) }
        .onDisappear { store.stop() }
    }

    @ViewBuilder private func bubble(_ m: ChatMessage) -> some View {
        let mine = m.uid == me.uid
        HStack(alignment: .bottom, spacing: 6) {
            if mine {
                Spacer(minLength: 40)
                Text(time(m.at)).font(.caption2).foregroundStyle(.secondary)
            } else {
                EmojiAvatar(emoji: peer.avatarEmoji, name: peer.name, bg: peer.avatarBg, size: 28, fontSize: 16, photoUrl: peer.avatarPhoto)
            }
            Text(m.text)
                .font(.body)
                .foregroundStyle(mine ? Color.white : Color.primary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(mine ? Color.brand : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !mine {
                Text(time(m.at)).font(.caption2).foregroundStyle(.secondary)
                Spacer(minLength: 40)
            }
        }
    }
}
