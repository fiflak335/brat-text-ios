import SwiftUI

struct BratText: Identifiable {
    let id = UUID()
    let original: String
    let viral: String
    let style: String
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

    static func generate(from transcription: String) -> [BratText] {
        var sentences = transcription
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var results: [BratText] = []
        guard let first = sentences.first else { return results }

        let hook = hooks.randomElement()!
        let emoji = emojis.randomElement()!
        let format = formats.randomElement()!

        results.append(BratText(
            original: first,
            viral: "\(format.replacingOccurrences(of: "{text}", with: first.lowercased())) \(emoji) \(hook)",
            style: "viral_hook"
        ))

        if sentences.count > 1 {
            results.append(BratText(
                original: sentences[1],
                viral: "brat energy: \(sentences[1].lowercased()) \(emoji)",
                style: "brat_energy"
            ))
        }

        results.append(BratText(
            original: String(transcription.prefix(100)),
            viral: "me when \(first.lowercased()) \(emoji) \(hooks.randomElement()!)",
            style: "relatable"
        ))

        for (i, sentence) in sentences.prefix(3).enumerated() {
            results.append(BratText(
                original: sentence,
                viral: "\(sentence.lowercased()) \(emojis.randomElement()!) \(hooks.randomElement()!)",
                style: "quick_post_\(i + 1)"
            ))
        }

        return results
    }
}