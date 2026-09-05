import Foundation

struct BratText: Identifiable {
    let id = UUID()
    let original: String
    let viral: String
    let style: String
}

struct LyricGeneration {
    let lyricTitle: String
    let lyricLines: [String]
    let lyricFooter: String
    let vibe: String
    let alternatives: [BratText]
}

struct GenerationOptions {
    var lowercase = false
    var useEmojis = true
    var language = "en"   // "en" | "pl"
    var variantCount = 4
}

enum BratGenerator {
    private static let hooksEN = [
        "green like my aura",
        "brat summer never ends",
        "they're gonna talk anyway so",
        "i'm so brat",
        "club beat goes hard",
        "literally me",
        "it's brat",
        "so valid for this",
        "no thoughts just vibes",
        "main character energy",
        "rent free in their heads",
        "chronically online",
        "slay all day",
        "it's giving what it's supposed to give",
        "ate and left no crumbs",
        "understood the assignment",
        "living my best life",
        "no filter needed",
    ]

    private static let hooksPL = [
        "zielony jak moja aura",
        "brat lato nie kończy się",
        "i tak będą gadać więc",
        "jestem taka brat",
        "bit gra mocno w klubie",
        "dosłownie ja",
        "to jest brat",
        "takie valid",
        "zero myśli same vibes",
        "główna energia postaci",
        "rent free w ich głowach",
        "online non stop",
        "zjadłam i nie zostawiłam okruszków",
        "zrozumiałam zadanie",
        "żyję swoim najlepszym życiem",
    ]

    private static let vibes = [
        "main character energy",
        "viral in 2 hours",
        "certified banger",
        "so brat summer",
        "the whole club's gonna play this",
        "eating and leaving no crumbs",
        "10/10 would post",
        "rent free material",
    ]

    private static let emojis = ["🍃", "💚", "✨", "⚡", "🔥", "💚🍃", "✨🍃", "💚✨"]

    private static let formats = [
        "POV: {text}",
        "{text} and that's on what? period.",
        "when you realize {text}",
        "not {text} being the whole mood",
        "the fact that {text} is sending me",
        "{text} >>> everything else",
        "nobody: \nabsolutely nobody: \nme: {text}",
        "{text} and i'll never shut up about it",
    ]

    static func generate(from transcription: String, options: GenerationOptions = GenerationOptions()) -> LyricGeneration {
        let sentences = transcription
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let words = transcription
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        let hooks = options.language == "pl" ? hooksPL : hooksEN

        let lines: [String]
        if sentences.count >= 3 {
            let chosen = Array(sentences.prefix(3))
            lines = buildLyricLines(from: chosen, options: options)
        } else if !sentences.isEmpty {
            lines = chunk(words: words, maxWordsPerLine: 7)
        } else {
            lines = [" ", " ", " "]
        }
        let cardLines = options.lowercase
            ? lines.map { $0 == " " ? " " : $0.lowercased() }
            : lines

        let footer = hooks.randomElement() ?? "it's brat"
        let vibe = vibes.randomElement() ?? "viral"
        let emoji = options.useEmojis ? (emojis.randomElement() ?? "🍃") : ""
        let hook = hooks.randomElement() ?? "it's brat"

        var alternatives: [BratText] = []
        func viral(_ original: String, _ template: String, _ style: String) {
            alternatives.append(BratText(
                original: original,
                viral: template.replacingOccurrences(of: "{text}", with: original),
                style: style
            ))
        }

        if let first = sentences.first {
            let fs = formats.randomElement()!
            viral(
                options.lowercase ? first.lowercased() : first,
                "\(fs.replacingOccurrences(of: "{text}", with: options.lowercase ? first.lowercased() : first)) \(emoji) \(hook)",
                "viral_hook"
            )
            if sentences.count > 1 {
                let second = sentences[1]
                viral(
                    second,
                    "brat energy: \(options.lowercase ? second.lowercased() : second) \(emoji)",
                    "brat_energy"
                )
            }
            viral(
                String(transcription.prefix(100)),
                "me when \(options.lowercase ? first.lowercased() : first) \(emoji) \(hook)",
                "relatable"
            )
        }

        let baseSentences = sentences.isEmpty ? ["your vibe"] : sentences
        var resultCount = options.variantCount
        while alternatives.count < resultCount {
            let source = baseSentences[alternatives.count % baseSentences.count]
            let template = formats[alternatives.count % formats.count]
            let processed = options.lowercase ? source.lowercased() : source
            viral(
                processed,
                "\(template.replacingOccurrences(of: "{text}", with: processed)) \(emoji) \(hook)",
                ["viral_hook", "pov_clip", "caption", "story_time", "status"][alternatives.count % 5]
            )
        }
        return LyricGeneration(
            lyricTitle: "brat text",
            lyricLines: cardLines,
            lyricFooter: footer,
            vibe: vibe,
            alternatives: alternatives
        )
    }

    private static func buildLyricLines(from sentences: [String], options: GenerationOptions) -> [String] {
        var out: [String] = []
        out.append("#verse")
        for sentence in sentences {
            let lower = options.lowercase ? sentence.lowercased() : sentence
            let chunks = chunkWords(in: lower, maxWordsPerLine: 6)
            for c in chunks {
                out.append(c)
            }
            out.append(" ")
        }
        return out
    }

    private static func chunk(words: [String], maxWordsPerLine: Int) -> [String] {
        var lines: [String] = []
        var current: [String] = []
        for word in words {
            current.append(word)
            if current.count >= maxWordsPerLine {
                lines.append(current.joined(separator: " "))
                current = []
            }
        }
        if !current.isEmpty {
            lines.append(current.joined(separator: " "))
        }
        return lines.isEmpty ? [" "] : lines
    }

    private static func chunkWords(in text: String, maxWordsPerLine: Int) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return chunk(words: words, maxWordsPerLine: maxWordsPerLine)
    }
}