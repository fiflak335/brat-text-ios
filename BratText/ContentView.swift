import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var transcriber = SpeechTranscriber()
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var settings = SettingsStore()

    @State private var selectedURL: URL?
    @State private var fileName = ""
    @State private var isVideo = false

    @State private var transcription = ""
    @State private var lyricCard: LyricCardItem?
    @State private var bratTexts: [BratText] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showRecorder = false
    @State private var videoItem: PhotosPickerItem?
    @State private var photoPickerShown = false
    @State private var showSettings = false
    @State private var showHistory = false
    @StateObject private var recorder = AudioRecorder()

    private var accent: Color { settings.accent.color }
    private var style: LyricStyle { settings.style }

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
                        tipsPanel
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
        .tint(accent)
        .photosPicker(isPresented: $photoPickerShown, selection: $videoItem, matching: .videos)
        .sheet(isPresented: $showRecorder) {
            RecorderView(recorder: recorder) { url in
                selectFile(url: url, name: "recording.m4a", isVideo: false)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(settings: settings) { item in
                showHistory = false
                loadHistoryItem(item)
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .onChange(of: videoItem) { _, item in
            guard let item else { return }
            loadMovie(from: item)
        }
    }

    // MARK: - Background

    private var backgroundGlow: some View {
        ZStack {
            LinearGradient(colors: [bgDeep, Color(red: 0.09, green: 0.13, blue: 0.10)],
                           startPoint: .top, endPoint: .bottom)
            Circle()
                .fill(accent.opacity(0.14))
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
            HStack {
                Spacer()
                headerIconButton(icon: "clock.arrow.circlepath", label: "History") {
                    showHistory = true
                }
                headerIconButton(icon: "gearshape.fill", label: "Settings") {
                    showSettings = true
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 4)

            Text("🍃")
                .font(.system(size: 46))
            Text("brat text")
                .font(.system(size: 46, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [Color(red: 0.75, green: 1.0, blue: 0.25), accent],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: accent.opacity(0.5), radius: 18, y: 6)
            Text("turn your voice into viral lyrics")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            Text(style == .brat ? "brat mode: on" : "\(style.title) mode: on")
                .font(.caption2.bold().uppercaseSmallCaps())
                .foregroundStyle(accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(accent.opacity(0.12)))
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func headerIconButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardGlass)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.25), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
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
                    title: "video",
                    desc: "from your gallery",
                    colors: [accent, Color.teal],
                    action: { photoPickerShown = true }
                )
                pickCard(
                    icon: "mic.fill",
                    title: "record",
                    desc: "from your mic",
                    colors: [Color.orange, Color.pink],
                    action: { showRecorder = true }
                )
            }

            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle")
                Text("mp4 • mov — any video from your gallery")
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.gray)

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                Text("speak into the mic or pick a clip and get your lyric card")
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
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
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
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(colors[0].opacity(0.35), lineWidth: 1.2))
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
                        .fill(LinearGradient(colors: isVideo ? [accent, Color.teal] : [accent, Color(red: 0.75, green: 1.0, blue: 0.25)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                    Image(systemName: isVideo ? "film" : "waveform")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(fileName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(isVideo ? "video 🎬" : "audio 🎧")
                        .font(.caption)
                        .foregroundStyle(accent)
                }
                Spacer()
                playButton
                clearButton
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardGlass)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(accent.opacity(0.35), lineWidth: 1.2))
            )
            .shadow(color: accent.opacity(0.15), radius: 16, y: 8)
        }
    }

    private var playButton: some View {
        Button {
            audioPlayer.toggle(url: selectedURL!)
        } label: {
            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(accent)
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
                .tint(accent)
                .scaleEffect(1.4)
            Text("making your lyrics...")
                .font(.headline)
            HStack(spacing: 16) {
                Label("extracting audio", systemImage: "wrench")
                Label("listening", systemImage: "ear")
                Label("styling", systemImage: "sparkles")
            }
            .font(.caption2)
            .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(RoundedRectangle(cornerRadius: 22).fill(cardGlass))
        .transition(.opacity)
    }

    // MARK: - Action

    private var actionButton: some View {
        Button {
            generate()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isLoading ? "hourglass" : "sparkles")
                Text(isLoading ? "working on it..." : "generate lyrics 🍃")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                Capsule().fill(
                    selectedURL != nil && !isLoading
                        ? AnyShapeStyle(LinearGradient(colors: [accent, Color(red: 0.2, green: 0.95, blue: 0.4)],
                                                        startPoint: .leading, endPoint: .trailing))
                        : AnyShapeStyle(Color(.systemGray4))
                )
            )
            .foregroundStyle(selectedURL != nil && !isLoading ? Color.black : Color.gray)
            .shadow(color: selectedURL != nil && !isLoading ? accent.opacity(0.45) : .clear,
                    radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(selectedURL == nil || isLoading)
        .animation(.spring(duration: 0.3), value: selectedURL != nil)
    }

    private var tipsPanel: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.yellow)
                .font(.subheadline)
            Text("Tip: clear speech works best. If you get “no speech detected”, try talking a bit louder or closer to the mic.")
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(cardGlass.opacity(0.6)))
    }

    // MARK: - Sections

    @ViewBuilder
    private var transcriptSection: some View {
        if !transcription.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("📝 transcript")
                    .font(.headline)
                    .foregroundStyle(accent)
                Text(transcription)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(cardGlass)
                            .overlay(RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(0.2), lineWidth: 1))
                    )
                    .font(.body)
                Button {
                    UIPasteboard.general.string = transcription
                } label: {
                    Label("copy transcript", systemImage: "doc.on.doc")
                        .font(.caption.bold())
                        .foregroundStyle(accent)
                }
            }
        }
    }

    @ViewBuilder
    private var lyricSection: some View {
        if let card = lyricCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("🎵 your lyric card")
                        .font(.headline)
                        .foregroundStyle(accent)
                    Spacer()
                    Button {
                        reshuffle()
                    } label: {
                        Label("reshuffle", systemImage: "shuffle")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(accent.opacity(0.15)))
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
                LyricCardView(card: card, accent: accent, cardDark: cardGlass)
                HStack(spacing: 10) {
                    ShareLink(
                        item: card.lines.joined(separator: "\n"),
                        preview: SharePreview("brat lyrics", image: Image(systemName: "music.note"))
                    ) {
                        Label("share text", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(accent.opacity(0.15)))
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                    Button {
                        UIPasteboard.general.string = card.lines.joined(separator: "\n")
                    } label: {
                        Label("copy all", systemImage: "doc.on.doc")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(cardGlass))
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if !bratTexts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("🍃 more variants")
                        .font(.headline)
                        .foregroundStyle(accent)
                    Spacer()
                    Text("\(bratTexts.count) fresh drops")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                ForEach(bratTexts) { item in
                    BratCardView(item: item, accent: accent, cardDark: cardGlass)
                }
            }
        }
    }

    // MARK: - Logic

    private func loadMovie(from item: PhotosPickerItem) {
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw TranscriptionError.noResult
                }
                let contentTypes = item.supportedContentTypes
                let ext = contentTypes.first(where: { $0.conforms(to: .mpeg4Movie) })?.preferredFilenameExtension
                    ?? contentTypes.first?.preferredFilenameExtension
                    ?? "mov"
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("picked_\(Int(Date().timeIntervalSince1970)).\(ext)")
                try data.write(to: url)
                await MainActor.run {
                    selectFile(url: url, name: "video.\(ext)", isVideo: true)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Couldn't load the video: \(error.localizedDescription)"
                }
            }
        }
    }

    private func selectFile(url: URL, name: String, isVideo: Bool) {
        selectedURL = url
        fileName = name
        self.isVideo = isVideo
        transcription = ""
        lyricCard = nil
        bratTexts = []
    }

    private func clearSelection() {
        audioPlayer.stop()
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

        if settings.hapticsEnabled {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        Task {
            do {
                let text = try await transcriber.transcribe(url: url)
                await MainActor.run {
                    withAnimation {
                        applyGeneration(from: text)
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

    private func reshuffle() {
        guard !transcription.isEmpty else { return }
        withAnimation(.spring(duration: 0.4)) {
            applyGeneration(from: transcription)
        }
    }

    private func applyGeneration(from text: String) {
        transcription = text
        let options = GenerationOptions(
            lowercase: settings.lowercase,
            useEmojis: settings.emojis,
            language: "en",
            variantCount: settings.variantCount
        )
        let generated = BratGenerator.generate(from: text, options: options)
        let card = LyricCardItem(
            title: generated.lyricTitle,
            lines: generated.lyricLines,
            footer: generated.lyricFooter,
            vibe: generated.vibe,
            transcriptionPreview: text
        )
        lyricCard = card
        bratTexts = generated.alternatives
        SettingsStore.saveHistory(card: card, alternatives: generated.alternatives)
    }

    private func loadHistoryItem(_ item: LyricCardItem) {
        transcription = item.transcriptionPreview ?? transcription
        withAnimation(.spring(duration: 0.4)) {
            lyricCard = item
            bratTexts = item.altTexts
        }
    }
}

// MARK: - Models

struct LyricCardItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let lines: [String]
    let footer: String
    let vibe: String
    var transcriptionPreview: String?
    var altTexts: [BratText] = []
    var createdAt: Date

    init(id: UUID = UUID(), title: String, lines: [String], footer: String, vibe: String,
         transcriptionPreview: String? = nil, altTexts: [BratText] = [], createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.lines = lines
        self.footer = footer
        self.vibe = vibe
        self.transcriptionPreview = transcriptionPreview
        self.altTexts = altTexts
        self.createdAt = createdAt
    }
}

extension BratText: Codable {}

// MARK: - History Store

extension SettingsStore {
    private static var historyKey = "bratHistory"

    static func saveHistory(card: LyricCardItem, alternatives: [BratText]) {
        var items = loadHistory()
        var entry = card
        entry.altTexts = alternatives
        items.removeAll { $0.id == entry.id }
        items.insert(entry, at: 0)
        let itemsToSave = Array(items.prefix(50))
        if let data = try? JSONEncoder().encode(itemsToSave) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    static func loadHistory() -> [LyricCardItem] {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return [] }
        return (try? JSONDecoder().decode([LyricCardItem].self, from: data)) ?? []
    }

    static func clearHistory() {
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
}

// MARK: - Lyric Card View

struct LyricCardView: View {
    let card: LyricCardItem
    let accent: Color
    let cardDark: Color

    @State private var saved = false

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 10)

                ZStack(alignment: .topLeading) {
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
                            .foregroundStyle(accent)
                    }
                    .padding(.horizontal, 18)
                }

                Spacer()

                VStack(alignment: .center, spacing: 12) {
                    Text("#\(card.vibe.lowercased().replacingOccurrences(of: " ", with: ""))")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(accent.opacity(0.15)))
                    ForEach(Array(card.lines.enumerated()), id: \.offset) { _, line in
                        Text(line == " " ? "\u{00A0}" : line)
                            .font(.system(size: 22, weight: line.hasPrefix("#") ? .heavy : .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.96))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)

                Spacer()

                HStack {
                    Text(card.footer)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                    Spacer()
                    Text("♪")
                        .font(.system(size: 24))
                        .foregroundStyle(accent)
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
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(accent.opacity(0.5), lineWidth: 1.5))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: accent.opacity(0.25), radius: 20, y: 10)

            Button {
                saveCard()
            } label: {
                Label(saved ? "saved to your gallery!" : "save as image",
                      systemImage: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(accent.opacity(saved ? 0.9 : 0.18)))
                    .foregroundStyle(saved ? Color.black : accent)
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
                    Text("brat text").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(accent)
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
                    Text(card.footer).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(accent)
                    Spacer()
                    Text("♪").font(.system(size: 28)).foregroundStyle(accent)
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
    let accent: Color
    let cardDark: Color
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.style.replacingOccurrences(of: "_", with: " "))
                .font(.caption2.bold().uppercaseSmallCaps())
                .foregroundStyle(accent)
            Text(item.viral)
                .font(.body)
            Text("original: \(item.original)")
                .font(.caption)
                .foregroundStyle(.gray)
                .lineLimit(2)
            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = item.viral
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copied = false
                    }
                } label: {
                    Label(copied ? "copied!" : "copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(accent.opacity(copied ? 0.9 : 0.15)))
                        .foregroundStyle(copied ? Color.black : accent)
                }
                .buttonStyle(.plain)
                ShareLink(item: item.viral) {
                    Label("share", systemImage: "square.and.arrow.up")
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(accent.opacity(0.15)))
                        .foregroundStyle(accent)
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
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(accent.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Theme") {
                    Picker("Accent color", selection: $settings.accentRaw) {
                        ForEach(AppAccent.allCases) { a in
                            HStack {
                                Circle().fill(a.color).frame(width: 18, height: 18)
                                Text(a.rawValue.capitalized)
                            }
                            .tag(a.rawValue)
                        }
                    }
                    Picker("Card style", selection: $settings.styleRaw) {
                        ForEach(LyricStyle.allCases) { s in
                            Text(s.title).tag(s.rawValue)
                        }
                    }
                }

                Section("Your lyrics") {
                    Toggle("Lowercase everything", isOn: $settings.lowercase)
                    Toggle("Emojis on the side", isOn: $settings.emojis)
                    Toggle("Haptic feedback", isOn: $settings.hapticsEnabled)
                    Stepper(value: $settings.variantCount, in: 2...10) {
                        HStack {
                            Text("Variants per run")
                            Spacer()
                            Text("\(settings.variantCount)")
                                .foregroundStyle(.gray)
                                .bold()
                        }
                    }
                }

                Section {
                    Button("Clear history", role: .destructive) {
                        SettingsStore.clearHistory()
                    }
                }

                Section {
                    HStack {
                        Text("brat text generator")
                        Spacer()
                        Text("v\(UIApplication.version)")
                            .foregroundStyle(.gray)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - History

struct HistoryView: View {
    @ObservedObject var settings: SettingsStore
    var onSelect: (LyricCardItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var items: [LyricCardItem] = SettingsStore.loadHistory()

    var body: some View {
        NavigationView {
            Group {
                if items.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 46))
                            .foregroundStyle(.gray)
                        Text("No lyrics yet")
                            .font(.headline)
                        Text("Generate your first lyric card and it'll show up here.")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        ForEach(items) { item in
                            Button {
                                onSelect(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(item.vibe)
                                            .font(.caption2.bold().uppercaseSmallCaps())
                                            .foregroundStyle(.gray)
                                        Spacer()
                                        Text(item.createdAt, style: .relative)
                                            .font(.caption2)
                                            .foregroundStyle(.gray)
                                    }
                                    Text(item.lines.filter { $0 != " " && !$0.hasPrefix("#") }.prefix(2).joined(separator: "\n"))
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text(item.footer)
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { indexSet in
                            items.remove(atOffsets: indexSet)
                            if let data = try? JSONEncoder().encode(items) {
                                UserDefaults.standard.set(data, forKey: "bratHistory")
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Recorder

struct RecorderView: View {
    @ObservedObject var recorder: AudioRecorder
    var onFinish: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    private let accent = Color(red: 0.54, green: 0.81, blue: 0.0)

    var body: some View {
        VStack(spacing: 30) {
            Text(recorder.isRecording ? "recording... 🎙️" : "ready to record")
                .font(.title2.bold())
            Text("tap the mic, say something brat, tap stop")
                .font(.caption)
                .foregroundStyle(.gray)
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
                    .foregroundStyle(recorder.isRecording ? Color.red : accent)
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .presentationDetents([.height(320)])
    }
}

// MARK: - Helpers

extension UIApplication {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

#Preview {
    ContentView()
}