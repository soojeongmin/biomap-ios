import AVFoundation
import SwiftUI

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var elapsed: Double = 0
    @Published var level: CGFloat = 0
    @Published var captured: Data? = nil

    let maxDuration: Double = 15
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private(set) var fileURL: URL?

    func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in cont.resume(returning: granted) }
        }
    }

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rec-\(Int(Date().timeIntervalSince1970)).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.isMeteringEnabled = true
            r.record()
            recorder = r
            fileURL = url
            isRecording = true
            elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        } catch {
            isRecording = false
        }
    }

    private func tick() {
        guard let r = recorder, r.isRecording else { return }
        r.updateMeters()
        elapsed = r.currentTime
        let power = r.averagePower(forChannel: 0)
        level = CGFloat(min(1, max(0, (power + 50) / 50)))
        if elapsed >= maxDuration { captured = stop() }
    }

    @discardableResult
    func stop() -> Data? {
        timer?.invalidate(); timer = nil
        recorder?.stop()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        guard let url = fileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    func cancel() {
        timer?.invalidate(); timer = nil
        recorder?.stop(); recorder = nil
        isRecording = false
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        fileURL = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

@MainActor
final class SoundPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    private var player: AVAudioPlayer?

    func toggleData(_ data: Data) {
        if isPlaying { stop(); return }
        playData(data)
    }

    func toggleURL(_ url: URL) {
        if isPlaying { stop(); return }
        Task { await playURL(url) }
    }

    private func playData(_ data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(data: data)
            p.delegate = self
            p.play()
            player = p
            isPlaying = true
        } catch { isPlaying = false }
    }

    private func playURL(_ url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            playData(data)
        } catch { isPlaying = false }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.isPlaying = false }
    }
}

struct SoundRecorderSheet: View {
    let onFinish: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var rec = AudioRecorder()

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("record_sound_title")
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.15))
                    .frame(width: 160, height: 160)
                    .scaleEffect(rec.isRecording ? 1 + rec.level * 0.4 : 1)
                    .animation(.easeOut(duration: 0.1), value: rec.level)
                Button {
                    if rec.isRecording {
                        if let data = rec.stop() { onFinish(data); dismiss() }
                    } else {
                        rec.start()
                    }
                } label: {
                    Image(systemName: rec.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                        .frame(width: 110, height: 110)
                        .background(Color.brand, in: Circle())
                }
            }

            Text(timeText).font(.system(.title2, design: .monospaced)).foregroundStyle(.secondary)
            Spacer()
            Button("cancel") { rec.cancel(); dismiss() }
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(rec.isRecording)
        .onChange(of: rec.captured) { _, data in
            if let data { onFinish(data); dismiss() }
        }
    }

    private var timeText: String {
        let s = Int(rec.elapsed)
        return String(format: "0:%02d / 0:%02d", s, Int(rec.maxDuration))
    }
}
