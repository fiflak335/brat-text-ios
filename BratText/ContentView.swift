import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var transcriber = SpeechTranscriber()
    @StateObject private var audioPlayer = AudioPlayer()

    @State private var selectedURL: URL?
    @State private var fileName = ""

    @State private var transcription = ""
    @State private var bratTexts: [BratText] = []
    @State private var isLoading = false
    @State private var showImporter = false
    @State private var errorMessage: String?
    @State private var showRecorder = false
    @StateObject private var recorder = AudioRecorder()

    private let bratGreen = Color(red: 0.54, green: 0.81, blue: 0.0)
    private let bgDark = Color(red: 0.10, green: 0.10, blue: 0.18)
    private let cardDark = Color(red: 0.14, green: 0.16, blue: 0.28)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    uploadArea
                    actionButton
                    transcriptSection
                    resultsSection
                }
                .padding()
            }
            .background(bgDark.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(bratGreen)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showRecorder) {
            RecorderView(recorder: recorder) { url in
                selectFile(url: url, name: "nagranie.m4a")
            }
        }
        .alert("Błąd", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Nieznany błąd")
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("🍃")
                .font(.system(size: 48))
            Text("brat text generator")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(bratGreen)
            Text("wgraj audio i dostaj viralowe teksty")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
        .padding(.top, 24)
    }

    private var uploadArea: some View {
        VStack(spacing: 12) {
            if isLoading {
                ProgressView("transkrybuję...")
                    .tint(bratGreen)
                    .padding(.vertical, 30)
            } else if let _ = selectedURL {
                selectedFileCard
            } else {
                emptyUploadArea
            }
        }
    }

    private var emptyUploadArea: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button {
                    showImporter = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 34))
                        Text("importuj")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(cardDark)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button {
                    showRecorder = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 34))
                        Text("nagraj")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(cardDark)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }

            Text("mp3, wav, m4a — albo nagraj od razu")
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }

    private var selectedFileCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "waveform")
                    .font(.title2)
                VStack(alignment: .leading) {
                    Text(fileName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(URL(fileURLWithPath: fileName).pathExtension.isEmpty
                         ? "" : "gotowe do generowania")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                Button {
                    audioPlayer.toggle(url: selectedURL!)
                } label: {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                }
                Button {
                    selectedURL = nil
                    fileName = ""
                    transcription = ""
                    bratTexts = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.gray)
                }
            }
            .padding()
            .background(cardDark)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var actionButton: some View {
        Button {
            generate()
        } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("generuj brat text 🍃")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(selectedURL != nil && !isLoading ? bratGreen : Color(.systemGray4))
            .foregroundStyle(selectedURL != nil && !isLoading ? Color(red: 0.1, green: 0.1, blue: 0.18) : .gray)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(selectedURL == nil || isLoading)
    }

    @ViewBuilder
    private var transcriptSection: some View {
        if !transcription.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("📝 transkrypcja")
                    .font(.headline)
                    .foregroundStyle(bratGreen)
                Text(transcription)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(cardDark)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if !bratTexts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("🍃 viralowe teksty")
                    .font(.headline)
                    .foregroundStyle(bratGreen)

                ForEach(bratTexts) { item in
                    BratCardView(item: item)
                }
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
            }
            selectFile(url: url, name: url.lastPathComponent)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func selectFile(url: URL, name: String) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)
            selectedURL = tempURL
            fileName = name
            transcription = ""
            bratTexts = []
        } catch {
            errorMessage = "Nie udało się odczytać pliku: \(error.localizedDescription)"
        }
    }

    private func generate() {
        guard let url = selectedURL else { return }
        isLoading = true
        transcription = ""
        bratTexts = []

        Task {
            do {
                let text = try await transcriber.transcribe(url: url)
                await MainActor.run {
                    transcription = text
                    bratTexts = BratGenerator.generate(from: text)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

struct BratCardView: View {
    let item: BratText
    @State private var copied = false

    private let bratGreen = Color(red: 0.54, green: 0.81, blue: 0.0)
    private let cardDark = Color(red: 0.14, green: 0.16, blue: 0.28)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.style.replacingOccurrences(of: "_", with: " "))
                .font(.caption2.bold().uppercaseSmallCaps())
                .foregroundStyle(bratGreen)
            Text(item.viral)
                .font(.body)
            Text("oryginal: \(item.original)")
                .font(.caption)
                .foregroundStyle(.gray)
            Button {
                UIPasteboard.general.string = item.viral
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copied = false
                }
            } label: {
                Label(copied ? "skopiowano!" : "kopiuj", systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(bratGreen.opacity(copied ? 0.9 : 0.15))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [cardDark, cardDark.opacity(0.6)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(bratGreen.opacity(0.4), lineWidth: 1)
        )
    }
}

struct RecorderView: View {
    @ObservedObject var recorder: AudioRecorder
    var onFinish: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    private let bratGreen = Color(red: 0.54, green: 0.81, blue: 0.0)

    var body: some View {
        VStack(spacing: 30) {
            Text(recorder.isRecording ? "nagrywam... 🎙️" : "gotowy do nagrania")
                .font(.title2.bold())

            Button {
                if recorder.isRecording {
                    if let url = recorder.stopRecording() {
                        onFinish(url)
                        dismiss()
                    }
                } else {
                    try? recorder.startRecording()
                }
            } label: {
                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(recorder.isRecording ? Color.red : bratGreen)
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .presentationDetents([.height(320)])
    }
}

#Preview {
    ContentView()
}