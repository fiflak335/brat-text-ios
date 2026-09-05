import Foundation
import Speech

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

    func transcribe(url: URL) async throws -> String {
        isTranscribing = true
        defer { isTranscribing = false }

        let authorized = await requestPermission()
        guard authorized else { throw TranscriptionError.notAuthorized }

        let recognizer = SFSpeechRecognizer()
        guard let recognizer = recognizer, recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
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