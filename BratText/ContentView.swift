import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

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
    @State private var errorMessage: String?
    @State private var showRecorder = false
    @State private var videoItem: PhotosPickerItem?
    @StateObject private var recorder = AudioRecorder()

    // MARK: - Palette
    private let bratGreen = Color(red: 0.54, green: 0.81, blue: 0.0)              // #8ACE00
    private let bratLime  = Color(red: 0.75, green: 1.0, blue: 0.25)             // #BFFF40
    private let bgDeep    = Color(red: 0.045, green: 0.05, blue: 0.08)
    private let cardGlass = Color(red: 0.13, green: 0.15, blue: 0.22).opacity(0.85)

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGlow
                ScrollView {
                    VStack(spacing: 22) {
                        header
                        uploadArea
                        actionButton
                        transcriptSection
                        lyricSection
                        resultsSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .preferredColorScheme(.dark)
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(bratGreen)
        .photosPicker(isPresented: $photoPickerShown, selection: $videoItem, matching: .videos)
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
        .onChange(of: videoItem) { _, item in
            guard let item else { return }
            loadMovie(from: item)
        }
    }

    @State private var photoPickerShown = false

    private var backgroundGlow: some View {
        ZStack {
            LinearGradient(colors: [bgDeep, Color(red: 0.09, green: 0.13, blue: 0.10)],
                           startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(bratGreen.opacity(0.12))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(y: -380)
            Circle()
                .fill(Color.purple.opacity(0.10))
                .frame(width: 380, height: 380)
                .blur(radius: 90)
                .offset(x: 200, y: 320)
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("🍃")
                .font(.system(size: 42))
            Text("brat text")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [bratLime, bratGreen],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: bratGreen.opacity(0.5), radius: 18, y: 6)
            Text("audio albo film → viralowe lyrics")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 30)
        .padding(.bottom, 6)
    }

    // MARK: - Upload

    private var uploadArea: some View {
        Group {
            if isLoading {
                loadingCard
            } else if selectedURL != nil {
                selectedFileCard
            } else {
                emptyUploadArea
            }
        }
    }

    private var emptyUploadArea: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                pickCard(
                    icon: "film.stack",
                    title: "film",
                    desc: "z galerii",
                    colors: [bratGreen, Color.teal],
                    action: { photoPickerShown = true }
                )
                pickCard(
                    icon: "mic.fill",
                    title: "nagraj",
                    desc: "z mikrofonu",
                    colors: [Color.orange, Color.pink],
                    action: { showRecorder = true }
                )
            }

            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle")
                Text("mp4 • mov • dowolny film z galerii")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.gray)

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("wybierz klip z Twojej biblioteki, a my zrobimy lyrics")
                Spacer()
            }
            .font(.caption2)
            .foregroundStyle(.gray.opacity(0.8))
        }
    }

    private func pickCard(icon: String, title: String, desc: String,
                          colors: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 68, height: 68)
                        .shadow(color: colors[0].opacity(0.45), radius: 16, y: 6)
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text(title)
                    .font(.headline)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(cardGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(colors[0].opacity(0.35), lineWidth: 1.2)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var selectedFileCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(colors: isVideo ? [bratGreen, Color.teal] : [bratGreen, bratLime],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 50, height: 50)
                    Image(systemName: isVideo ? "film" : "waveform")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(fileName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(isVideo ? "film 🎬" : "audio 🎧")
                        .font(.caption)
                        .foregroundStyle(bratGreen)
                }
                Spacer()
                playButton
                clearButton
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(bratGreen.opacity(0.35), lineWidth: 1.2)
                    )
            )
            .shadow(color: bratGreen.opacity(0.15), radius: 16, y: 8)
        }
    }

    private var playButton: some View {
        Button {
            audioPlayer.toggle(url: selectedURL!)
        } label: {
            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(bratGreen)
        }
    }

    private var clearButton: some View {
        Button(action: clearSelection) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.gray)
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(bratGreen)
                .scaleEffect(1.4)
            Text("transkrybuję i robię lyrics...")
                .font(.headline)
            Text("konwertuję audio • rozpoznaję mowę • styluję")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(cardGlass)
        )
        .transition(.opacity)
    }

    // MARK: - Action

    private var actionButton: some View {
        Button {
            generate()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isLoading ? "hourglass" : "sparkles")
                Text("generuj lyrics 🍃")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                Capsule().fill(
                    selectedURL != nil && !isLoading
                        ? AnyShapeStyle(LinearGradient(colors: [bratGreen, bratLime],
                                                        startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color(.systemGray4))
                )
            )
            .foregroundStyle(selectedURL != nil && !isLoading ? Color.black : Color.gray)
            .shadow(color: selectedURL != nil && !isLoading ? bratGreen.opacity(0.45) : .clear,
                    radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(selectedURL == nil || isLoading)
        .animation(.spring(duration: 0.3), value: selectedURL != nil)
    }

    // MARK: - Sections

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
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(cardGlass)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
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
                Text("🎵 lyrics — kwadrat")
                    .font(.headline)
                    .foregroundStyle(bratGreen)
                LyricCardView(card: card, bratGreen: bratGreen, cardDark: cardGlass)
                ShareLink(
                    item: card.lines.joined(separator: "\n"),
                    preview: SharePreview("brat lyrics",
                                          image: Image(systemName: "music.note"))
                ) {
                    Label("udostępnij tekst", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(bratGreen.opacity(0.15)))
                        .foregroundStyle(bratGreen)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if !bratTexts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("🍃 więcej wariantów")
                    .font(.headline)
                    .foregroundStyle(bratGreen)
                ForEach(bratTexts) { item in
                    BratCardView(item: item, bratGreen: bratGreen, cardDark: cardGlass)
                }
            }
        }
    }

    // MARK: - Logic

    private func loadMovie(from item: PhotosPickerItem) {
        Task {
            do {
                let provider = item.itemProvider
                guard provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                    throw TranscriptionError.noResult
                }
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("picked_\(Int(Date().timeIntervalSince1970))")

                let movieURL = try await withCheckedThrowingContinuation { continuation in
                    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                        if let url {
                            continuation.resume(returning: url)
                        } else {
                            continuation.resume(throwing: error ?? TranscriptionError.noResult)
                        }
                    }
                }
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: movieURL, to: tempURL)
                await MainActor.run {
                    selectFile(url: tempURL, name: movieURL.lastPathComponent, isVideo: true)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Nie udało się wczytać filmu: \(error.localizedDescription)"
                }
            }
        }
    }

    private func selectFile(url: URL, name: String, isVideo: Bool) {
        do {
            selectedURL = url
            fileName = name
            self.isVideo = isVideo
            transcription = ""
            lyricCard = nil
            bratTexts = []
        }
    }

    private func clearSelection() {
        selectedURL = nil
        fileName = ""
        isVideo = false
        transcription = ""
        lyricCard = nil
        bratTexts = []
        videoItem = nil
    }

    private func generate() {
        guard let url = selectedURL else { return }
        withAnimation { isLoading = true }
        transcription = ""
        lyricCard = nil
        bratTexts = []

        Task {
            do {
                let text = try await transcriber.transcribe(url: url)
                await MainActor.run {
                    withAnimation {
                        transcription = text
                        let generated = BratGenerator.generate(from: text)
                        lyricCard = LyricCard(title: generated.lyricTitle,
                                              lines: generated.lyricLines,
                                              footer: generated.lyricFooter)
                        bratTexts = generated.alternatives
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        errorMessage = error.localizedDescription
                        isLoading = false
                    }
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
        VStack(spacing: 14) {
            // Square card
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 10)

                ZStack(alignment: .topLeading) {
                    // big faint watermark
                    Text("🍃")
                        .font(.system(size: 230))
                        .opacity(0.08)
                        .offset(x: -18, y: -30)

                    HStack {
                        Text("🍃")
                            .font(.system(size: 26))
                        Spacer()
                        Text("brat text")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(bratGreen)
                    }
                    .padding(.horizontal, 18)
                }

                Spacer()

                VStack(alignment: .center, spacing: 12) {
                    ForEach(Array(card.lines.enumerated()), id: \.offset) { _, line in
                        Text(line == " " ? "\u{00A0}" : line)
                            .font(.system(size: 23, weight: line.hasPrefix("#") ? .heavy : .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.96))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)

                Spacer()

                HStack {
                    Text(card.footer)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(bratGreen)
                    Spacer()
                    Text("♪")
                        .font(.system(size: 24))
                        .foregroundStyle(bratGreen)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                LinearGradient(colors: [Color.black, cardDark.opacity(0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(bratGreen.opacity(0.5), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: bratGreen.opacity(0.25), radius: 20, y: 10)

            // Save button
            Button {
                saveCard()
            } label: {
                Label(saved ? "zapisane do galerii!" : "zapisz jako obraz",
                      systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        Capsule().fill(bratGreen.opacity(saved ? 0.9 : 0.18))
                    )
                    .foregroundStyle(saved ? Color.black : bratGreen)
            }
            .buttonStyle(.plain)
        }
    }

    private func saveCard() {
        let renderer = ImageRenderer(content: lyricContent())
        renderer.scale = UIScreen.main.scale * 2
        if let uiImage = renderer.uiImage {
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            saved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                saved = false
            }
        }
    }

    private func lyricContent() -> some View {
        VStack(spacing: 0) {
            VStack {
                Spacer(minLength: 20)
                HStack {
                    Text("🍃").font(.system(size: 32))
                    Spacer()
                    Text("brat text").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(bratGreen)
                }
                .padding(.horizontal, 28)
                Spacer()
                VStack(spacing: 14) {
                    ForEach(Array(card.lines.enumerated()), id: \.offset) { _, line in
                        Text(line == " " ? "\u{00A0}" : line)
                            .font(.system(size: 30, weight: line.hasPrefix("#") ? .heavy : .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                Spacer()
                HStack {
                    Text(card.footer).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(bratGreen)
                    Spacer()
                    Text("♪").font(.system(size: 28)).foregroundStyle(bratGreen)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(LinearGradient(colors: [Color.black, cardDark.opacity(0.9)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
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
            HStack(spacing: 10) {
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
                ShareLink(item: item.viral) {
                    Label("podziel się", systemImage: "square.and.arrow.up")
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(bratGreen.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [cardDark.opacity(0.8), cardDark.opacity(0.45)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
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