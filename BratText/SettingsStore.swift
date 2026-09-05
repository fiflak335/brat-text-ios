import SwiftUI

enum AppAccent: String, CaseIterable, Identifiable {
    case brat
    case purple
    case fire

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .brat:   return Color(red: 0.54, green: 0.81, blue: 0.0)   // #8ACE00
        case .purple: return Color(red: 0.66, green: 0.33, blue: 0.97)
        case .fire:   return Color(red: 1.0, green: 0.42, blue: 0.18)
        }
    }
}

enum LyricStyle: String, CaseIterable, Identifiable {
    case brat
    case neon
    case clean

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brat:  return "Brat"
        case .neon:  return "Neon"
        case .clean: return "Clean"
        }
    }
}

final class SettingsStore: ObservableObject {
    let defaults = UserDefaults.standard

    @Published var accentRaw: String {
        didSet { defaults.set(accentRaw, forKey: "accent") }
    }
    @Published var styleRaw: String {
        didSet { defaults.set(styleRaw, forKey: "lyricStyle") }
    }
    @Published var lowercase: Bool {
        didSet { defaults.set(lowercase, forKey: "lowercase") }
    }
    @Published var emojis: Bool {
        didSet { defaults.set(emojis, forKey: "emojis") }
    }
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: "haptics") }
    }
    @Published var variantCount: Int {
        didSet { defaults.set(variantCount, forKey: "variantCount") }
    }

    var accent: AppAccent {
        get { AppAccent(rawValue: accentRaw) ?? .brat }
        set { accentRaw = newValue.rawValue }
    }

    var style: LyricStyle {
        get { LyricStyle(rawValue: styleRaw) ?? .brat }
        set { styleRaw = newValue.rawValue }
    }

    init() {
        accentRaw = defaults.string(forKey: "accent") ?? AppAccent.brat.rawValue
        styleRaw = defaults.string(forKey: "lyricStyle") ?? LyricStyle.brat.rawValue
        lowercase = defaults.bool(forKey: "lowercase")
        emojis = defaults.object(forKey: "emojis") as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: "haptics") as? Bool ?? true
        variantCount = defaults.object(forKey: "variantCount") as? Int ?? 4
    }
}