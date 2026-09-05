import Foundation
import Speech
import AVFoundation

enum TranscriptionError: LocalizedError {
    case notAuthorized
    case unavailable
    case noAudioTrack
    case conversionFailed
    case noResult
    case timedOut

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Brak dostępu do rozpoznawania mowy. Włącz je w Ustawieniach → Prywatność."
        case .unavailable:
            return "Rozpoznawanie mowy jest niedostępne na tym urządzeniu."
        case .noAudioTrack:
            return "Ten film nie ma ścieżki dźwiękowej."
        case .conversionFailed:
            return "Nie udało się przetworzyć audio. Spróbuj innego pliku."
        case .noResult:
            return "Nie wykryto mowy w nagraniu. Sprawdź, czy jest wyraźna."
        case .timedOut:
            return "Przekroczono czas transkrypcji. Spróbuj krótszego klipu."
        }
    }
}

final class SpeechTranscriber: ObservableObject {
    @Published var isTranscribing = false

    // MARK: - Public

    func transcribe(url: URL) async throws -> String {
        isTranscribing = true
        defer { isTranscribing = false }

        let authorized = await requestPermission()
        guard authorized else { throw TranscriptionError.notAuthorized }

        // 1. If video, extract audio track.
        let audioURL: URL
        let videoExts = ["mp4", "mov", "m4v", "avi", "mkv", "3gp", "webm"]
        if videoExts.contains(url.pathExtension.lowercased()) {
            audioURL = try await extractAudio(from: url)
        } else {
            audioURL = url
        }

        // 2. Convert to WAV PCM 16kHz mono — most reliable for SFSpeechRecognizer.
        let wavURL = try convertToWav(source: audioURL)

        defer {
            if audioURL != url { try? FileManager.default.removeItem(at: audioURL) }
            try? FileManager.default.removeItem(at: wavURL)
        }

        // 3. Recognize from WAV.
        return try await recognize(from: wavURL)
    }

    // MARK: - Video audio extraction

    private func extractAudio(from url: URL) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { throw TranscriptionError.noAudioTrack }

        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("extracted_\(Int(Date().timeIntervalSince1970)).m4a")

        try? FileManager.default.removeItem(at: exportURL)

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionError.conversionFailed
        }
        exporter.outputURL = exportURL
        exporter.outputFileType = .m4a
        exporter.shouldOptimizeForNetworkUse = false

        return try await withCheckedThrowingContinuation { continuation in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed:
                    continuation.resume(returning: exportURL)
                case .cancelled:
                    continuation.resume(throwing: TranscriptionError.timedOut)
                default:
                    continuation.resume(throwing: exporter.error ?? TranscriptionError.conversionFailed)
                }
            }
        }
    }

    // MARK: - WAV conversion (16 kHz, mono, PCM)

    private func convertToWav(source: URL) throws -> URL {
        let targetRate = 16000.0
        let targetChannels: AVAudioChannelCount = 1

        let srcFile = try AVAudioFile(forReading: source)
        let srcFormat = srcFile.processingFormat

        guard let destFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetRate,
            channels: targetChannels,
            interleaved: true
        ) else {
            throw TranscriptionError.conversionFailed
        }

        let destURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("brat_speech_\(Int(Date().timeIntervalSince1970)).wav")
        try? FileManager.default.removeItem(at: destURL)
        FileManager.default.createFile(atPath: destURL.path, contents: nil)

        let destFile = try AVAudioFile(forWriting: destURL, settings: destFormat.settings)

        guard let converter = AVAudioConverter(from: srcFormat, to: destFormat) else {
            throw TranscriptionError.conversionFailed
        }

        guard let srcBuffer = AVAudioPCMBuffer(
            pcmFormat: srcFormat, frameCapacity: 16384
        ) else {
            throw TranscriptionError.conversionFailed
        }
        guard let destBuffer = AVAudioPCMBuffer(
            pcmFormat: destFormat, frameCapacity: 16384
        ) else {
            throw TranscriptionError.conversionFailed
        }

        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            do {
                try srcFile.read(into: srcBuffer)
                if srcBuffer.frameLength == 0 {
                    outStatus.pointee = .endOfStream
                    return nil
                }
                outStatus.pointee = .haveData
                return srcBuffer
            } catch {
                outStatus.pointee = .error
                return nil
            }
        }

        var outError: NSError?
        var status = converter.convert(to: destBuffer, error: &outError, withInputFrom: inputBlock)

        while status != .endOfStream {
            if status == .haveData, destBuffer.frameLength > 0 {
                try destFile.write(from: destBuffer)
            }
            destBuffer.frameLength = 0
            status = converter.convert(to: destBuffer, error: &outError, withInputFrom: inputBlock)
        }

        return destURL
    }

    // MARK: - Recognition

    private func recognize(from url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            let task = recognizer.recognitionTask(with: request) { result, error in
                guard !didResume else { return }
                didResume = true

                if let result = result, result.isFinal {
                    let text = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if text.isEmpty {
                        continuation.resume(throwing: TranscriptionError.noResult)
                    } else {
                        continuation.resume(returning: text)
                    }
                } else if let error = error {
                    // Speech framework returns "no speech heard" as an unavailable/recognition error.
                    let nsErr = error as NSError
                    if nsErr.code == 216 // "no speech heard"
                        || nsErr.domain == "kAFAssistantErrorDomain" && nsErr.code == 203
                        || nsErr.code == 1110 // recognizedTextAlignment or timeout-ish
                        || nsErr.code == 1111 {
                        continuation.resume(throwing: TranscriptionError.noResult)
                    } else if nsErr.code == 301 {
                        continuation.resume(throwing: TranscriptionError.noResult)
                    } else {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(throwing: TranscriptionError.noResult)
                }
            }

            // Safety timeout - some files hang.
            DispatchQueue.main.asyncAfter(deadline: .now() + 90) {
                if !didResume {
                    didResume = true
                    task.cancel()
                    continuation.resume(throwing: TranscriptionError.timedOut)
                }
            }
        }
    }

    // MARK: - Permission

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}