# brat text generator — iOS 🍃

Aplikacja iOS, która transkrybuje audio/film i generuje viralowe teksty w stylu "brat".

## Funkcje

- Import pliku audio **lub filmu** (mp3, wav, m4a • mp4, mov) albo nagranie z mikrofonu
- Transkrypcja na urządzeniu dzięki Speech framework (Apple) — z filmów automatycznie wyciąga ścieżkę audio
- Generowanie viralowych tekstów w stylu brat:
  - **Lyrics w kwadracie** — gotowy do udostępnienia (zapis jako obraz do galerii)
  - viral hook / brat energy / relatable / quick post
- Kopiowanie tekstów do schowka jednym dotknięciem, zapis kwadratu jako obraz
- Odtwarzanie wybranego audio/filmu

## Wymagania

- macOS z Xcode 15+
- iPhone z iOS 17+
- Konto Apple Developer (do podpisu aplikacji na urządzeniu)

## Budowanie

1. Otwórz `BratText.xcodeproj` w Xcode
2. Wybierz swój team w Signing & Capabilities (zakładka projektu)
3. Uruchom na symulatorze lub podłączonym iPhonie

## Release / sideload

1. Pobierz `BratText.ipa` z zakładki **Releases** (build z GitHub Actions)
2. Podpisz i zainstaluj narzędziem: **Sideloadly**, **AltStore** lub **Apple Configurator 2**
3. Aplikacja bez podpisu dev — po 7 dniach wymaga ponownej instalacji

## Struktura

- `BratText/BratGenerator.swift` — logika generowania tekstów i lyrics w stylu brat
- `BratText/SpeechTranscriber.swift` — transkrypcja audio/wideo przez Speech framework
- `BratText/AudioRecorder.swift` — nagrywanie i odtwarzanie audio
- `BratText/ContentView.swift` — interfejs użytkownika (SwiftUI) z kwadratową kartą lyrics

## Uwagi

- Transkrypcja działa w języku urządzenia (wspiera polski)
- Rozpoznawanie mowy wymaga Internetu
- Pierwsze użycie poprosi o zgodę na mikrofon i rozpoznawanie mowy
- Wideo: wyciągany jest dźwięk (AVAssetExportSession do m4a) i dopiero transkrybowany

## Licencja

MIT