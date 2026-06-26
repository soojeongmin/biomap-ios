import SwiftUI
import FirebaseAuth

struct NicknameSetupView: View {
    let onDone: () -> Void

    @State private var name = ""
    @State private var error: String?
    @State private var working = false

    private var uid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("SplashLogo").resizable().scaledToFit().frame(width: 88, height: 88)
            Text("nickname_setup_title").font(.title2.bold())
            Text("nickname_setup_desc").font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            TextField("nickname_hint", text: $name)
                .textFieldStyle(.roundedBorder)
                .onChange(of: name) { _, _ in error = nil }
                .padding(.horizontal, 40)
            if let error {
                Text(LocalizedStringKey(error)).font(.caption).foregroundStyle(.red)
            }
            Button {
                Task { await save() }
            } label: {
                if working { ProgressView().tint(.white) } else { Text("save") }
            }
            .buttonStyle(FilledBrandButton())
            .padding(.horizontal, 40)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || working)
            Spacer()
        }
    }

    private func save() async {
        guard let uid else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        working = true
        defer { working = false }
        if await UserRepository.nicknameTaken(trimmed, uid: uid) {
            error = "nickname_taken"
            return
        }
        await UserRepository.setNickname(uid: uid, name: trimmed)
        onDone()
    }
}
