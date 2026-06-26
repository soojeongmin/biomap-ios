import SwiftUI

private func metricKey(_ m: String) -> LocalizedStringKey { m == "newspecies" ? "duel_metric_new" : "duel_metric_obs" }

struct DuelView: View {
    let me: AppUser
    let onBack: () -> Void

    @StateObject private var store = DuelStore()
    @State private var selectedDuel: Duel?

    private var duels: [Duel] { store.duels }
    private var incoming: [Duel] { duels.filter { $0.status == "pending" && $0.bUid == me.uid } }
    private var outgoing: [Duel] { duels.filter { $0.status == "pending" && $0.aUid == me.uid } }
    private var active: [Duel] { duels.filter { $0.status == "active" } }
    private var past: [Duel] { duels.filter { $0.status == "done" } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onBack) { Image(systemName: "chevron.left").font(.body.weight(.semibold)) }
                Text("duel_title").font(.headline)
                Spacer()
                Label("\(me.coins)", systemImage: "leaf.fill")
                    .font(.subheadline.weight(.bold)).foregroundStyle(Color.brand)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            Divider()

            if duels.isEmpty {
                Spacer()
                Text("duel_empty").foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        sectionView("duel_incoming", incoming) { d in
                            HStack(spacing: 8) {
                                Button("duel_accept") { Task { await DuelRepository.respond(duelId: d.id, accept: true) } }
                                    .buttonStyle(PillBrandButton())
                                Button("duel_decline") { Task { await DuelRepository.respond(duelId: d.id, accept: false) } }
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        sectionView("duel_outgoing", outgoing) { d in
                            Button("duel_cancel") { Task { await DuelRepository.cancel(duelId: d.id) } }
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        sectionView("duel_active", active) { d in
                            Text("\(d.myScore(me.uid)) : \(d.theirScore(me.uid))")
                                .font(.headline).foregroundStyle(Color.brand)
                        }
                        sectionView("duel_past", past, onTap: { selectedDuel = $0 }) { d in
                            HStack(spacing: 4) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(d.winner.isEmpty ? "duel_draw" : (d.winner == me.uid ? "duel_won" : "duel_lost"))
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(d.winner == me.uid ? Color.brand : Color.secondary)
                                    Text("\(d.myScore(me.uid)) : \(d.theirScore(me.uid))").font(.caption).foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .onAppear { store.start(uid: me.uid) }
        .onDisappear { store.stop() }
        .sheet(item: $selectedDuel) { d in
            DuelResultView(duel: d, myUid: me.uid)
        }
    }

    @ViewBuilder private func sectionView(_ title: LocalizedStringKey, _ items: [Duel], onTap: ((Duel) -> Void)? = nil, @ViewBuilder trailing: @escaping (Duel) -> some View) -> some View {
        if !items.isEmpty {
            Text(title).font(.subheadline).foregroundStyle(.secondary).padding(.top, 4)
            ForEach(items) { d in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.opponentName(me.uid).isEmpty ? "—" : d.opponentName(me.uid)).font(.body.weight(.semibold))
                        Text("\(Text(metricKey(d.metric))) · \(localizedFormat("duel_days", d.durationDays)) · \(d.stake)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    trailing(d)
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
                .onTapGesture { onTap?(d) }
            }
        }
    }
}

struct DuelResultView: View {
    let duel: Duel
    let myUid: String
    @Environment(\.dismiss) private var dismiss

    private var won: Bool { duel.winner == myUid }
    private var draw: Bool { duel.winner.isEmpty }
    private var received: Int { draw ? duel.myEscrow(myUid) : (won ? duel.pot : 0) }

    var body: some View {
        VStack(spacing: 20) {
            Text(draw ? "duel_draw" : (won ? "duel_won" : "duel_lost"))
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(won ? Color.brand : (draw ? Color.secondary : Color.red))
                .padding(.top, 28)

            HStack(alignment: .center, spacing: 16) {
                scoreColumn(NSLocalizedString("duel_me", comment: ""), duel.myScore(myUid), mine: true)
                Text(":").font(.system(size: 32, weight: .bold)).foregroundStyle(.secondary)
                scoreColumn(duel.opponentName(myUid).isEmpty ? "—" : duel.opponentName(myUid), duel.theirScore(myUid), mine: false)
            }

            Text("\(Text(metricKey(duel.metric))) · \(localizedFormat("duel_days", duel.durationDays))")
                .font(.subheadline).foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                Text(won ? "+\(received)" : (draw ? "+\(received)" : "-\(duel.myEscrow(myUid))"))
                    .fontWeight(.bold)
            }
            .font(.title3)
            .foregroundStyle(won ? Color.brand : (draw ? Color.secondary : Color.red))

            Spacer()
            Button("close") { dismiss() }.buttonStyle(.borderedProminent).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .presentationDetents([.medium])
    }

    private func scoreColumn(_ name: String, _ score: Int, mine: Bool) -> some View {
        VStack(spacing: 6) {
            Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(mine ? Color.brand : Color.primary).lineLimit(1)
            Text("\(score)").font(.system(size: 44, weight: .heavy))
        }
        .frame(minWidth: 90)
    }
}

struct CreateDuelView: View {
    let target: AppUser
    let myCoins: Int
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var metricNew = false
    @State private var days = 1
    @State private var stake = 10
    @State private var error: String?
    @State private var sending = false

    private var maxStake: Int { (min(200, myCoins) / 10) * 10 }
    private var valid: Bool { stake >= 10 && stake <= maxStake }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Label("\(myCoins)", systemImage: "leaf.fill")
                            .font(.title2.weight(.bold)).foregroundStyle(Color.brand)
                        Spacer()
                    }
                }
                Section("duel_metric") {
                    Picker("duel_metric", selection: $metricNew) {
                        Text("duel_metric_obs").tag(false)
                        Text("duel_metric_new").tag(true)
                    }.pickerStyle(.segmented)
                }
                Section("duel_duration") {
                    Picker("duel_duration", selection: $days) {
                        ForEach([1, 3, 7], id: \.self) { d in Text(localizedFormat("duel_days", d)).tag(d) }
                    }.pickerStyle(.segmented)
                }
                Section("duel_stake_label") {
                    HStack(spacing: 16) {
                        Spacer()
                        Button("−") { if stake > 10 { stake -= 10 } }
                            .buttonStyle(.bordered).disabled(stake <= 10)
                        Text("\(stake)").font(.title2.weight(.bold)).frame(minWidth: 56)
                        Button("+") { if stake < maxStake { stake += 10 } }
                            .buttonStyle(.bordered).disabled(stake >= maxStake)
                        Spacer()
                    }
                    if let error { Text(error).font(.caption).foregroundStyle(.red) }
                }
            }
            .navigationTitle(Text(verbatim: target.name.isEmpty ? "—" : target.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("duel_send") {
                        sending = true
                        Task {
                            let err = await DuelRepository.create(opponentUid: target.uid, stake: stake,
                                                                  metric: metricNew ? "newspecies" : "obs", durationDays: days)
                            sending = false
                            if err == nil { onDone(); dismiss() } else { error = err }
                        }
                    }
                    .disabled(!valid || sending)
                }
            }
        }
    }
}
