import SwiftUI
import UIKit
import FirebaseAuth

struct SettingsSheet: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showDelete = false
    @State private var working = false
    @State private var showFeedback = false
    @State private var guildChatNotify = true
    @State private var dmNotify = true
    @State private var loadedMuted = false
    @State private var latestVersion: String?
    @State private var showCacheCleared = false

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private func isOutdated(_ current: String, _ latest: String) -> Bool {
        let c = current.split(separator: ".").map { Int($0) ?? 0 }
        let l = latest.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(c.count, l.count) {
            let cv = i < c.count ? c[i] : 0
            let lv = i < l.count ? l[i] : 0
            if lv != cv { return lv > cv }
        }
        return false
    }

    private func fetchLatestVersion() async {
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=com.soojeongmin.biomap") else { return }
        if let (data, _) = try? await URLSession.shared.data(from: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let results = json["results"] as? [[String: Any]],
           let v = results.first?["version"] as? String {
            latestVersion = v
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $guildChatNotify) {
                        Text("setting_guild_chat_notify")
                    }
                    .onChange(of: guildChatNotify) { enabled in
                        guard loadedMuted, let uid = Auth.auth().currentUser?.uid else { return }
                        Task { await UserRepository.setGuildChatMuted(uid: uid, muted: !enabled) }
                    }
                    Toggle(isOn: $dmNotify) {
                        Text("setting_dm_notify")
                    }
                    .onChange(of: dmNotify) { enabled in
                        guard loadedMuted, let uid = Auth.auth().currentUser?.uid else { return }
                        Task { await UserRepository.setDmMuted(uid: uid, muted: !enabled) }
                    }
                }
                Section {
                    Button { openSystemSettings() } label: { settingsRow("settings_language", "globe") }
                    Button { openSystemSettings() } label: { settingsRow("settings_notifications", "bell.fill") }
                } footer: {
                    Text("settings_open_system")
                }
                Section {
                    Button { showFeedback = true } label: {
                        Text("feedback_title")
                    }
                    Button { clearCache() } label: {
                        Text("settings_clear_cache")
                    }
                }
                Section {
                    HStack {
                        Text("settings_version")
                        Spacer()
                        Text(currentVersion).foregroundStyle(.secondary)
                    }
                    if let latest = latestVersion {
                        HStack {
                            Text("settings_latest_version")
                            Spacer()
                            if isOutdated(currentVersion, latest) {
                                Text("\(latest) · \(NSLocalizedString("settings_update_available", comment: ""))")
                                    .foregroundStyle(Color.brand).fontWeight(.semibold)
                            } else {
                                Text(latest).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Button {
                        auth.signOut()
                        dismiss()
                    } label: {
                        Label("sign_out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
                Section {
                    Button(role: .destructive) { showDelete = true } label: {
                        Label("account_delete", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(Text("settings"))
            .labelStyle(CompactSettingsLabelStyle())
            .task {
                if let uid = Auth.auth().currentUser?.uid {
                    let user = await UserRepository.getUser(uid)
                    guildChatNotify = user?.guildChatMuted != true
                    dmNotify = user?.dmMuted != true
                }
                loadedMuted = true
            }
            .task { await fetchLatestVersion() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("close") { dismiss() }
                }
            }
            .alert(Text("account_delete"), isPresented: $showDelete) {
                Button("cancel", role: .cancel) {}
                Button("account_delete", role: .destructive) {
                    Task {
                        working = true
                        if let uid = auth.user?.uid {
                            await UserRepository.deleteAccount(uid)
                        }
                        auth.signOut()
                        working = false
                        dismiss()
                    }
                }
            } message: {
                Text("account_delete_message")
            }
            .sheet(isPresented: $showFeedback) { FeedbackSheet() }
            .alert("settings_cache_cleared", isPresented: $showCacheCleared) {
                Button("confirm", role: .cancel) {}
            }
            .disabled(working)
        }
    }

    private func settingsRow(_ titleKey: LocalizedStringKey, _ symbol: String) -> some View {
        HStack {
            Label(titleKey, systemImage: symbol)
            Spacer()
            Image(systemName: "arrow.up.forward.app").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        let fm = FileManager.default
        let dirs: [URL?] = [fm.urls(for: .cachesDirectory, in: .userDomainMask).first, fm.temporaryDirectory]
        for case let dir? in dirs {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for item in items { try? fm.removeItem(at: item) }
        }
        UserDefaults.standard.set(true, forKey: "clearFirestoreOnLaunch")
        showCacheCleared = true
    }
}

private struct CompactSettingsLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
                .font(.system(size: 14))
                .frame(width: 20)
            configuration.title
        }
    }
}

private struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var type = "bug"
    @State private var text = ""
    @State private var sending = false

    var body: some View {
        NavigationStack {
            Form {
                Picker("feedback_title", selection: $type) {
                    Text("feedback_bug").tag("bug")
                    Text("feedback_idea").tag("idea")
                }
                .pickerStyle(.segmented)
                Section {
                    TextField("feedback_hint", text: $text, axis: .vertical).lineLimit(4...8)
                }
            }
            .navigationTitle(Text("feedback_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("feedback_send") {
                        Task {
                            sending = true
                            _ = await FeedbackRepository.submit(type: type, text: text)
                            sending = false
                            dismiss()
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sending)
                }
            }
        }
    }
}
