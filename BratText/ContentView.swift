import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @StateObject private var transcriber = SpeechTranscriber()
    @StateObject private var audioPlayer = AudioPlayer()

    @State private var selectedURL: URL?
    @State private var fileName = ""
    @State private var isVideo = false

    @State private var transcription = ""
    @State private var lyricCard: LyricCard?
    @State private var bratTexts: [BratText] = []
    @State private var isLoading = false
    @State private var showImporter = false
    @State private var errorMessage: String?
    @State private var showRecorder = false
    @StateObject private var recorder = AudioRecorder()

    private let bratGreen = Color(red: 0.54, green: 0.81, blue: 0.0)
    private let bgDeep = Color(red: 0.06, green: 0.06, blue: 0.10)
    private let bgDark = Color(red: 0.10, green: 0.10, blue: 0.18)
    private let cardDark = Color(red: 0.14, green: 0.16, blue: 0.28)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    uploadArea
                    actionButton
                    transcriptSection
                    lyricSection
                    resultsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(
                LinearGradient(
                    colors: [bgDeep, bgDark.opacity(0.9)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()
            )
            .preferredColorScheme(.dark)
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(bratGreen)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audiovisualContent],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(isPresented: $showRecorder) {
            RecorderView(recorder: recorder) { url in
                selectFile(url: url, name: "nagranie.m4a", isVideo: false)
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
        VStack(spacing: 8) {
            Text("🍃")
                .font(.system(size: 44))
            Text("brat text")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(bratGreen)
            Text("wgraj audio albo film — dostajesz viralowe lyrics")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    private var uploadArea: some View {
        VStack(spacing: 14) {
            if isLoading {
                ProgressView("transkrybuję...")
                    .tint(bratGreen)
                    .padding(.vertical, 40)
            } else if selectedURL != nil {
                selectedFileCard
            } else {
                emptyUploadArea
            }
        }
    }

    private var emptyUploadArea: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                uploadButton(title: "importuj", icon: "folder.badge.plus", desc: "audio lub film") {
                    showImporter = true
                }
                uploadButton(title: "nagraj", icon: "mic.fill", desc: "z mikrofonu") {
                    showRecorder = true
                }
            }
            Text("mp3, wav, m4a • mp4, mov")
                .font(.caption)
                .foregroundStyle(.gray)
        }
    }

    private func uploadButton(title: String, icon: String, desc: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(bratGreen.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(bratGreen)
                }
                Text(title)
                    .font(.headline)
                Text(desc)
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardDark.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(bratGreen.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedFileCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(bratGreen.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: isVideo ? "film.fill" : "waveform")
                        .font(.system(size: 20))
                        .foregroundStyle(bratGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(fileName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(isVideo ? "film • wideo" : "audio")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                Spacer()
                Button {
                    audioPlayer.toggle(url: selectedURL!)
                } label: {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(bratGreen)
                }
                Button {
                    clearSelection()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.gray)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardDark.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(bratGreen.opacity(0.25), lineWidth: 1)
                    )
            )
        }
    }

    private var actionButton: some View {
        Button {
            generate()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("generuj lyrics 🍃")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Capsule().fill(
                    selectedURL != nil && !isLoading
                        ? AnyShapeStyle(LinearGradient(colors: [bratGreen, bratGreen.opacity(0.8)],
                                                        startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color(.systemGray4))
                )
            )
            .foregroundStyle(selectedURL != nil && !isLoading ? Color.black : .gray)
            .shadow(color: selectedURL != nil && !isLoading ? bratGreen.opacity(0.4) : .clear,
                    radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(selectedURL == nil || isLoading)
    }

    @ViewBuilder
    private var transcriptSection: some View {
        if !transcription.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("📝 transkrypcja")
                Text(transcription)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(cardDark.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(bratGreen.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .font(.body)
            }
        }
    }

    @ViewBuilder
    private var lyricSection: some View {
        if let card = lyricCard {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("🎵 lyrics do udostępnienia")
                LyricCardView(card: card, bratGreen: bratGreen, cardDark: cardDark)
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if !bratTexts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("🍃 więcej wariantów")
                ForEach(bratTexts) { item in
                    BratCardView(item: item, bratGreen: bratGreen, cardDark: cardDark)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(bratGreen)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessing = url.startAccessingSecurityScopedResource()
            selectFile(url: url, name: url.lastPathComponent,
                       isVideo: url.pathExtension.lowercased() == "video"
                           || ["mp4", "mov", "m4v", "avi", "mkv", "3gp"].contains(url.pathExtension.lowercased()))
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func selectFile(url: URL, name: String, isVideo: Bool) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(Int(Date().timeIntervalSince1970))_\(name)")
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)
            selectedURL = tempURL
            fileName = name
            self.isVideo = isVideo
            transcription = ""
            lyricCard = nil
            bratTexts = []
        } catch {
            errorMessage = "Nie udało się odczytać pliku: \(error.localizedDescription)"
        }
    }

    private func clearSelection() {
        selectedURL = nil
        fileName = ""
        isVideo = false
        transcription = ""
        lyricCard = nil
        bratTexts = []
    }

    private func generate() {
        guard let url = selectedURL else { return }
        isLoading = true
        transcription = ""
        lyricCard = nil
        bratTexts = []

        Task {
            do {
                let text = try await transcriber.transcribe(url: url)
                await MainActor.run {
                    transcription = text
                    let generated = BratGenerator.generate(from: text)
                    lyricCard = LyricCard(title: generated.lyricTitle,
                                          lines: generated.lyricLines,
                                          footer: generated.lyricFooter)
                    bratTexts = generated.alternatives
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

// MARK: - Models

struct LyricCard: Identifiable {
    let id = UUID()
    let title: String
    let lines: [String]
    let footer: String
}

// MARK: - Lyric Card View

struct LyricCardView: View {
    let card: LyricCard
    let bratGreen: Color
    let cardDark: Color

    @State private var saved = false

    var body: some View {
        VStack(spacing: 0) {
            // Gradient header strip
            Rectangle()
                .fill(
                    LinearGradient(colors: [bratGreen, bratGreen.opacity(0.6), Color.purple.opacity(0.8)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(height: 10)

            // Square card
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                // Top watermark
                HStack {
                    Text("🍃")
                        .font(.system(size: 28))
                    Spacer()
                    Text("brat text")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(bratGreen)
                }
                .padding(.horizontal, 18)

                Spacer()

                // Lyrics lines (last portion, centered)
                VStack(alignment: .center, spacing: 10) {
                    ForEach(Array(card.lines.enumerated()), id: \.offset) { _, line in
                        Text(line == " " ? "\u{00A0}" : line)
                            .font(.system(size: 22, weight: line.hasPrefix("#") ? .heavy : .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)

                Spacer()

                // Footer
                HStack {
                    Text(card.footer)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(bratGreen)
                    Spacer()
                    Text("♪")
                        .font(.system(size: 22))
                        .foregroundStyle(bratGreen)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                Color.black
                    .overlay(
                        LinearGradient(colors: [cardDark.opacity(0.9), .black],
                                       startPoint: .top, endPoint: .bottom)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))

            // Save button
            Button {
                saveCard()
            } label: {
                Label(saved ? "zapisane!" : "zapisz jako obraz", systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(bratGreen.opacity(saved ? 0.9 : 0.15))
                    )
                    .foregroundStyle(saved ? .black : bratGreen)
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(cardDark.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(bratGreen.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func saveCard() {
        let renderer = ImageRenderer(content: lyricContent())
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            saved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                saved = false
            }
        }
    }

    private func lyricContent() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(LinearGradient(colors: [bratGreen, bratGreen.opacity(0.6), Color.purple.opacity(0.8)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 12)
            VStack {
                Spacer()
                HStack {
                    Text("🍃").font(.system(size: 32))
                    Spacer()
                    Text("brat text").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(bratGreen)
                }
                .padding(.horizontal, 22)
                Spacer()
                VStack(spacing: 12) {
                    ForEach(Array(card.lines.enumerated()), id: \.offset) { _, line in
                        Text(line == " " ? "\u{00A0}" : line)
                            .font(.system(size: 26, weight: line.hasPrefix("#") ? .heavy : .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.97))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22)
                Spacer()
                HStack {
                    Text(card.footer).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(bratGreen)
                    Spacer()
                    Text("♪").font(.system(size: 24)).foregroundStyle(bratGreen)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(Color.black)
        }
    }
}

// MARK: - Brat Variant Card

struct BratCardView: View {
    let item: BratText
    let bratGreen: Color
    let cardDark: Color
    @State private var copied = false

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
            LinearGradient(colors: [cardDark.opacity(0.7), cardDark.opacity(0.4)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(bratGreen.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Recorder

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