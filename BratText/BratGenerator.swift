import UIKit

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
    let alternatives: [BratText]
}

enum BratGenerator {
    private static let hooks = [
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
        "touch grass",
        "slay all day",
        "it's giving what it's supposed to give",
        "ate and left no crumbs",
        "understood the assignment",
        "rent free",
        "living my best life",
        "no filter needed",
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

    static func generate(from transcription: String) -> LyricGeneration {
        let sentences = transcription
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let words = transcription
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        // Build the square lyric card.
        let lines: [String]
        if sentences.count >= 3 {
            let chosen = Array(sentences.prefix(3))
            lines = buildLyricLines(from: chosen)
        } else if !sentences.isEmpty {
            lines = chunk(words: words, maxWordsPerLine: 7)
        } else {
            lines = [" ", " ", " "]
        }

        let footer = hooks.randomElement() ?? "it's brat"
        let title = "brat text"
        let emoji = emojis.randomElement()!
        let hook = hooks.randomElement()!

        // Alternatives
        var alternatives: [BratText] = []
        if let first = sentences.first {
            let fs = formats.randomElement()!
            alternatives.append(BratText(
                original: first,
                viral: "\(fs.replacingOccurrences(of: "{text}", with: first.lowercased())) \(emoji) \(hook)",
                style: "viral_hook"
            ))
            if sentences.count > 1 {
                alternatives.append(BratText(
                    original: sentences[1],
                    viral: "brat energy: \(sentences[1].lowercased()) \(emoji)",
                    style: "brat_energy"
                ))
            }
            alternatives.append(BratText(
                original: String(transcription.prefix(100)),
                viral: "me when \(first.lowercased()) \(emoji) \(hooks.randomElement()!)",
                style: "relatable"
            ))
        }

        let linesForAlt = lines.filter { $0 != " " && !$0.hasPrefix("#") }
        if let last = linesForAlt.last {
            alternatives.append(BratText(
                original: last,
                viral: "\(last.lowercased()) \(emojis.randomElement()!) \(hooks.randomElement()!)",
                style: "quick_post"
            ))
        }

        return LyricGeneration(
            lyricTitle: title,
            lyricLines: lines,
            lyricFooter: footer,
            alternatives: alternatives
        )
    }

    private static func buildLyricLines(from sentences: [String]) -> [String] {
        var out: [String] = []
        // Verse number as a hashtag lyric header.
        out.append("#verse")
        for sentence in sentences {
            let lower = sentence.lowercased()
            // Break long sentences into comfortable lyric lines.
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