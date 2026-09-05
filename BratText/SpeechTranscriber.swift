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
            return NSLocalizedString("Speech recognition permission is off. Enable it in Settings → Privacy.", comment: "")
        case .unavailable:
            return NSLocalizedString("Speech recognition is not available on this device.", comment: "")
        case .noAudioTrack:
            return NSLocalizedString("This video has no audio track.", comment: "")
        case .conversionFailed:
            return NSLocalizedString("Couldn't process the audio. Try a different file.", comment: "")
        case .noResult:
            return NSLocalizedString("No speech detected. Make sure the clip is clear.", comment: "")
        case .timedOut:
            return NSLocalizedString("Transcription timed out. Try a shorter clip.", comment: "")
        }
    }
}

/// All published state and resumes happen on the main actor —
/// mutating SwiftUI state from the Speech callback thread is what crashed "generate".
@MainActor
final class SpeechTranscriber: ObservableObject {
    @Published var isTranscribing = false

    func transcribe(url: URL) async throws -> String {
        isTranscribing = true
        defer { isTranscribing = false }

        guard await requestPermission() else { throw TranscriptionError.notAuthorized }

        // 1. Videos first get their audio track extracted to m4a.
        let sourceURL: URL
        let videoExts = ["mp4", "mov", "m4v", "avi", "mkv", "3gp", "webm"]
        if videoExts.contains(url.pathExtension.lowercased()) {
            sourceURL = try await extractAudio(from: url)
        } else {
            sourceURL = url
        }
        defer {
            if sourceURL != url {
                try? FileManager.default.removeItem(at: sourceURL)
            }
        }

        // 2. Convert to WAV PCM 16 kHz mono off the main thread.
        let wavURL = try await Task.detached(priority: .userInitiated) {
            try AudioConverterHelper.convertToWav(source: sourceURL)
        }.value
        defer { try? FileManager.default.removeItem(at: wavURL) }

        // 3. Recognize from the WAV file.
        return try await recognize(from: wavURL)
    }

    // MARK: - Video → audio extraction

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

    // MARK: - Recognition (main-actor-safe)

    private func recognize(from url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false

            let recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                // Hop to main so the double-resume guard is race-free.
                Task { @MainActor in
                    guard !didResume else { return }
                    didResume = true

                    if let result, result.isFinal {
                        let text = result.bestTranscription.formattedString
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if text.isEmpty {
                            continuation.resume(throwing: TranscriptionError.noResult)
                        } else {
                            continuation.resume(returning: text)
                        }
                    } else if let error {
                        let nse = error as NSError
                        let speechErrorCodes: [Int] = [203, 216, 301, 1110, 1111, 1115]
                        if nse.domain == "kAFAssistantErrorDomain" || speechErrorCodes.contains(nse.code) {
                            continuation.resume(throwing: TranscriptionError.noResult)
                        } else {
                            continuation.resume(throwing: error)
                        }
                    } else {
                        continuation.resume(throwing: TranscriptionError.noResult)
                    }
                }
            }

            // Timeout safety net.
            DispatchQueue.main.asyncAfter(deadline: .now() + 120) {
                Task { @MainActor in
                    guard !didResume else { return }
                    didResume = true
                    recognitionTask.cancel()
                    continuation.resume(throwing: TranscriptionError.timedOut)
                }
            }
        }
    }

    // MARK: - Permission

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
}

// MARK: - Pure conversion helpers (no UI state, safe off main)

enum AudioConverterHelper {
    static func convertToWav(source: URL) throws -> URL {
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

        guard let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: 16384) else {
            throw TranscriptionError.conversionFailed
        }
        guard let destBuffer = AVAudioPCMBuffer(pcmFormat: destFormat, frameCapacity: 16384) else {
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
                outStatus.pointee = .endOfStream
                return nil
            }
        }

        var status = converter.convert(to: destBuffer, error: nil, withInputFrom: inputBlock)
        while status == .haveData || status == .inputRanDry {
            if status == .haveData, destBuffer.frameLength > 0 {
                try destFile.write(from: destBuffer)
            }
            destBuffer.frameLength = 0
            status = converter.convert(to: destBuffer, error: nil, withInputFrom: inputBlock)
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: destURL.path)
        if let size = attributes[.size] as? Int, size < 100 {
            throw TranscriptionError.conversionFailed
        }
        return destURL
    }
}