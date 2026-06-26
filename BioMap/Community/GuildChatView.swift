import SwiftUI
import FirebaseFirestore

@MainActor
final class GuildChatStore: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var pinnedText = ""
    @Published var pinnedBy = ""
    private var msgListener: ListenerRegistration?
    private var teamListener: ListenerRegistration?

    func start(teamId: String, since: Int64) {
        guard msgListener == nil, !teamId.isEmpty else { return }
        let ref = Firestore.firestore().collection("teams").document(teamId)
        msgListener = ref.collection("messages")
            .order(by: "at", descending: false)
            .limit(toLast: 300)
            .addSnapshotListener { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                self?.messages = docs
                    .map { ChatMessage(firestore: $0.data(), id: $0.documentID) }
                    .filter { $0.at >= since }
            }
        teamListener = ref.addSnapshotListener { [weak self] snap, _ in
            let d = snap?.data()
            self?.pinnedText = d?["pinnedText"] as? String ?? ""
            self?.pinnedBy = d?["pinnedBy"] as? String ?? ""
        }
    }

    func stop() {
        msgListener?.remove(); msgListener = nil
        teamListener?.remove(); teamListener = nil
    }
}

private enum ChatRow: Identifiable {
    case date(String)
    case message(ChatMessage)
    var id: String {
        switch self {
        case .date(let d): return "date-\(d)"
        case .message(let m): return m.id
        }
    }
}

struct GuildChatView: View {
    let teamId: String
    let teamName: String
    let me: AppUser
    let isOwner: Bool
    var photoByUid: [String: String] = [:]
    let onBack: () -> Void

    @StateObject private var store = GuildChatStore()
    @State private var input = ""
    @State private var blocked: Set<String> = []
    @State private var didInitialScroll = false
    @State private var showRules = false
    @State private var didCheckRules = false

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = .current; f.dateFormat = "yyyy. M. d. EEEE"; return f
    }()
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = .current; f.dateFormat = "HH:mm"; return f
    }()

    private var visibleMessages: [ChatMessage] {
        store.messages.filter { !blocked.contains($0.uid) }
    }

    private var rows: [ChatRow] {
        var out: [ChatRow] = []
        var lastDay = ""
        for m in visibleMessages {
            let date = Date(timeIntervalSince1970: Double(m.at) / 1000)
            let dayKey = Self.dayFmt.string(from: date)
            if dayKey != lastDay { out.append(.date(dayKey)); lastDay = dayKey }
            out.append(.message(m))
        }
        return out
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left").font(.body.weight(.semibold))
                }
                Text(teamName).font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            Divider()

            if !store.pinnedText.isEmpty {
                pinnedBanner
                Divider()
            }

            if visibleMessages.isEmpty {
                Spacer()
                Text("guild_chat_empty")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding()
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(rows) { row in
                                switch row {
                                case .date(let d):
                                    Text(d)
                                        .font(.caption2).foregroundStyle(.secondary)
                                        .padding(.vertical, 8)
                                case .message(let m):
                                    bubble(m).id(m.id)
                                }
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                    }
                    .onChange(of: visibleMessages.count) { _ in
                        guard let last = visibleMessages.last else { return }
                        if didInitialScroll {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        } else {
                            proxy.scrollTo(last.id, anchor: .bottom)
                            didInitialScroll = true
                        }
                    }
                    .onAppear {
                        if let last = visibleMessages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                            didInitialScroll = true
                        }
                    }
                }
            }

            Divider()
            HStack(spacing: 8) {
                TextField("guild_chat_hint", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(Color(.secondarySystemBackground)))
                    .overlay(Capsule().stroke(Color(.separator), lineWidth: 0.5))
                    .onChange(of: input) { v in if v.count > 500 { input = String(v.prefix(500)) } }
                let canSend = !input.trimmingCharacters(in: .whitespaces).isEmpty
                Button {
                    let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    input = ""
                    Task { await TeamRepository.sendChat(teamId: teamId, me: me, text: text) }
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
        .onAppear {
            store.start(teamId: teamId, since: me.teamJoinedAt)
            blocked = Set(me.blockedUids)
            if !didCheckRules {
                didCheckRules = true
                if !UserDefaults.standard.bool(forKey: "guildChatAgreed") { showRules = true }
            }
        }
        .onDisappear { store.stop() }
        .alert("guild_chat_rules_title", isPresented: $showRules) {
            Button("guild_chat_agree") { UserDefaults.standard.set(true, forKey: "guildChatAgreed") }
            Button("cancel", role: .cancel) { onBack() }
        } message: {
            Text("guild_chat_rules_msg")
        }
    }

    private var pinnedBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "pin.fill").font(.caption).foregroundStyle(Color.brand)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.pinnedText).font(.subheadline).lineLimit(3)
                if !store.pinnedBy.isEmpty {
                    Text(store.pinnedBy).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isOwner {
                Button {
                    Task { await TeamRepository.clearPinned(teamId: teamId) }
                } label: {
                    Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.brand.opacity(0.08))
    }

    @ViewBuilder private func bubble(_ msg: ChatMessage) -> some View {
        let mine = msg.uid == me.uid
        let time = Self.timeFmt.string(from: Date(timeIntervalSince1970: Double(msg.at) / 1000))
        HStack(alignment: .bottom, spacing: 6) {
            if mine {
                Spacer(minLength: 40)
                Text(time).font(.caption2).foregroundStyle(.secondary)
            }
            if !mine {
                EmojiAvatar(emoji: msg.emoji, name: msg.name,
                            bg: msg.bg.isEmpty ? ProfileDecor.defaultBg : msg.bg,
                            size: 36, fontSize: 20, effect: "none",
                            photoUrl: photoByUid[msg.uid] ?? "")
            }
            VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
                if !mine {
                    DecorNameText(text: msg.name.isEmpty ? "—" : msg.name,
                                  token: msg.nameColor.isEmpty ? ProfileDecor.defaultNameColor : msg.nameColor,
                                  font: .caption)
                }
                Text(msg.text)
                    .font(.body)
                    .foregroundStyle(mine ? Color.white : Color.primary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(mine ? Color.brand : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contextMenu {
                        if isOwner {
                            Button {
                                Task { await TeamRepository.setPinned(teamId: teamId, message: msg) }
                            } label: {
                                Label(NSLocalizedString("guild_pin", comment: ""), systemImage: "pin")
                            }
                        }
                        if !mine {
                            Button {
                                Task { await TeamRepository.reportMessage(reporter: me, teamId: teamId, message: msg) }
                            } label: {
                                Label(NSLocalizedString("guild_report", comment: ""), systemImage: "flag")
                            }
                            Button(role: .destructive) {
                                blocked.insert(msg.uid)
                                Task { await TeamRepository.blockUser(myUid: me.uid, targetUid: msg.uid) }
                            } label: {
                                Label(NSLocalizedString("guild_block", comment: ""), systemImage: "nosign")
                            }
                        }
                    }
            }
            if !mine {
                Text(time).font(.caption2).foregroundStyle(.secondary)
                Spacer(minLength: 40)
            }
        }
    }
}
