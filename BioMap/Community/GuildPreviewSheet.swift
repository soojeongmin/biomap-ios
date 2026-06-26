import SwiftUI
import FirebaseAuth

struct GuildPreviewSheet: View {
    let teamId: String

    @Environment(\.dismiss) private var dismiss

    @State private var team: Team?
    @State private var members: [AppUser] = []
    @State private var myUid = Auth.auth().currentUser?.uid
    @State private var myTeamId: String?
    @State private var pending: String?
    @State private var meName = ""
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(team?.name ?? "")
                    .font(.title2.bold())
                if let d = team?.description, !d.isEmpty {
                    Text(d).font(.subheadline).foregroundStyle(.secondary)
                }
                Text(localizedFormat("guild_members_count", members.count))
                    .font(.subheadline).foregroundStyle(.secondary)

                ForEach(members) { member in
                    HStack(spacing: 12) {
                        EmojiAvatar(emoji: member.avatarEmoji, name: member.name,
                                    bg: member.avatarBg.isEmpty ? ProfileDecor.defaultBg : member.avatarBg,
                                    size: 40, fontSize: 22,
                                    effect: member.avatarEffect.isEmpty ? "none" : member.avatarEffect,
                                    photoUrl: member.avatarPhoto)
                        HStack(spacing: 4) {
                            DecorNameText(text: member.name.isEmpty ? "—" : member.name,
                                          token: member.avatarNameColor.isEmpty ? ProfileDecor.defaultNameColor : member.avatarNameColor,
                                          font: .body)
                            if member.uid == team?.ownerId {
                                Image(systemName: "star.fill").font(.caption).foregroundStyle(Color.brand)
                            }
                        }
                        Spacer()
                    }
                }

                if myUid != nil {
                    joinButton.padding(.top, 8)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            team = await TeamRepository.getTeam(teamId)
            members = await TeamRepository.getMembers(teamId)
            if let myUid {
                let me = await UserRepository.getUser(myUid)
                myTeamId = me?.teamId
                meName = me?.name ?? Auth.auth().currentUser?.displayName ?? ""
                pending = (me?.pendingTeamId).flatMap { $0.isEmpty ? nil : $0 }
            }
            loaded = true
        }
    }

    @ViewBuilder private var joinButton: some View {
        if myTeamId == teamId {
            Button("guild_already_member") {}
                .buttonStyle(FilledBrandButton()).disabled(true)
        } else if let mt = myTeamId, !mt.isEmpty {
            Button("guild_in_other") {}
                .buttonStyle(FilledBrandButton()).disabled(true)
        } else if pending == teamId {
            Button("team_request_pending") {}
                .buttonStyle(FilledBrandButton()).disabled(true)
        } else {
            Button(team?.autoAccept == true ? "guild_join" : "team_request") {
                guard let myUid else { return }
                Task {
                    let r = await TeamRepository.requestJoin(teamId: teamId, uid: myUid, name: meName)
                    switch r {
                    case .joined: dismiss()
                    case .requested: pending = teamId
                    case .failed: break
                    }
                }
            }
            .buttonStyle(FilledBrandButton())
        }
    }
}
