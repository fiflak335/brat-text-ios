import Foundation
import AVFoundation

final class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false

    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?

    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)

        let filename = "brat_\(Date().timeIntervalSince1970).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.max.rawValue,
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.record()
        recordingURL = url
        isRecording = true
    }

    func stopRecording() -> URL? {
        recorder?.stop()
        isRecording = false
        return recordingURL
    }
}

final class AudioPlayer: NSObject, ObservableObject {
    @Published var isPlaying = false

    private var player: AVAudioPlayer?

    func toggle(url: URL) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)

            if player?.url != url {
                player?.stop()
                player = try AVAudioPlayer(contentsOf: url)
                player?.delegate = self
            }

            if player?.isPlaying == true {
                player?.pause()
            } else {
                player?.play()
            }
            isPlaying = player?.isPlaying ?? false
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        isPlaying = false
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}