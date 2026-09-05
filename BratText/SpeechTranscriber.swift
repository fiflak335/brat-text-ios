import Foundation
import Speech
import AVFoundation

enum TranscriptionError: LocalizedError {
    case notAuthorized
    case unavailable
    case noResult

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Brak dostępu do rozpoznawania mowy. Włącz je w Ustawieniach."
        case .unavailable:
            return "Rozpoznawanie mowy jest niedostępne na tym urządzeniu."
        case .noResult:
            return "Nie udało się rozpoznać mowy w tym pliku."
        }
    }
}

final class SpeechTranscriber: ObservableObject {
    @Published var isTranscribing = false

    /// Extract audio track from any media (audio/video) into a temp .m4a file.
    func extractAudio(from url: URL) async throws -> URL {
        let asset = AVURLAsset(url: url)
        guard let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first else {
            throw TranscriptionError.noResult
        }
        _ = audioTrack

        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("extracted_\(Date().timeIntervalSince1970).m4a")

        if FileManager.default.fileExists(atPath: exportURL.path) {
            try? FileManager.default.removeItem(at: exportURL)
        }

        guard let exporter = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw TranscriptionError.noResult
        }

        exporter.outputURL = exportURL
        exporter.outputFileType = .m4a

        return try await withCheckedThrowingContinuation { continuation in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    continuation.resume(returning: exportURL)
                default:
                    continuation.resume(throwing: exporter.error ?? TranscriptionError.noResult)
                }
            }
        }
    }

    func transcribe(url: URL) async throws -> String {
        isTranscribing = true
        defer { isTranscribing = false }

        let authorized = await requestPermission()
        guard authorized else { throw TranscriptionError.notAuthorized }

        let audioURL: URL
        let fileType = url.pathExtension.lowercased()
        let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "3gp"]
        if videoExtensions.contains(fileType) {
            audioURL = try await extractAudio(from: url)
        } else {
            audioURL = url
        }
        defer {
            if audioURL != url {
                try? FileManager.default.removeItem(at: audioURL)
            }
        }

        let recognizer = SFSpeechRecognizer()
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            let task = recognizer.recognitionTask(with: request) { result, error in
                guard !didResume else { return }
                didResume = true

                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: TranscriptionError.noResult)
                }
            }

            if Task.isCancelled {
                task.cancel()
            }
        }
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}