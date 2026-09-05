# brat text generator — iOS 🍃

Turn your voice into viral lyrics. `brat text` transcribes audio/video on-device and generates brat-style lyric cards ready to share.

## Features

- **Import from gallery** — pick any video (mp4, mov, m4v…) or record straight from the mic
- **On-device transcription** (Apple Speech framework) — video audio is extracted automatically, then converted to the cleanest WAV format for reliable results
- **Viral lyric card** — square shareable card with a vibe hashtag, footer hook and emoji; save it as an image to your gallery
- **Variants** — each run drops a stack of fresh captions: viral hook, brat energy, relatable, POV, story time and more (2–10 per run)
- **Reshuffle** — re-roll the card and variants from the same transcript
- **History** — your past lyric cards are saved locally, browse, reuse and delete them
- **Settings** — accent theme (brat / purple / fire), card style, lowercase everything, emojis, haptics, variants per run
- **Share & copy** — copy transcripts, cards or single variants; share text anywhere
- **Playback** — preview the selected audio/video before generating

## Requirements

- macOS with Xcode 15+
- iPhone with iOS 17+
- Apple Developer account (to sign the app for a device)

## Building

1. Open `BratText.xcodeproj` in Xcode
2. Pick your team under Signing & Capabilities
3. Run on a simulator or a connected iPhone

## Release / sideload

1. Grab `BratText.ipa` from the **Releases** tab (built by GitHub Actions)
2. Sign & install with **Sideloadly**, **AltStore** or **Apple Configurator 2**
3. The unsigned build needs re-installation after 7 days

## Structure

- `BratText/BratGenerator.swift` — lyric + caption generation logic (EN/PL hooks)
- `BratText/SpeechTranscriber.swift` — audio/video transcription via Speech framework
- `BratText/SettingsStore.swift` — user settings & history persistence
- `BratText/AudioRecorder.swift` — recording and playback
- `BratText/ContentView.swift` — SwiftUI interface, lyric card, settings & history screens

## Notes

- Transcription matches your device language (polish supported)
- Speech recognition requires an internet connection
- First run asks for mic + speech recognition permission
- Videos: audio is exported (AVAssetExportSession → m4a), then normalized to WAV PCM 16 kHz mono before transcription

## License

MIT