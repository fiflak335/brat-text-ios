# brat text generator — iOS 🍃

Aplikacja iOS, która transkrybuje audio i generuje viralowe teksty w stylu "brat".

## Funkcje

- Import pliku audio (mp3, wav, m4a) albo nagranie bezpośrednio z mikrofonu
- Transkrypcja na urządzeniu dzięki Speech framework (Apple)
- Generowanie viralowych tekstów w kilku stylach:
  - viral hook
  - brat energy
  - relatable
  - quick post
- Kopiowanie tekstów do schowka jednym dotknięciem
- Odtwarzanie przesłanego audio

## Wymagania

- macOS z Xcode 15+
- iPhone z iOS 17+
- Konto Apple Developer (do podpisu aplikacji na urządzeniu)

## Budowanie

1. Otwórz `BratText.xcodeproj` w Xcode
2. Wybierz swój team w Signing & Capabilities (zakładka projektu)
3. Uruchom na symulatorze lub podłączonym iPhonie

## Struktura

- `BratText/BratGenerator.swift` — logika generowania tekstów w stylu brat
- `BratText/SpeechTranscriber.swift` — transkrypcja audio przez Speech framework
- `BratText/AudioRecorder.swift` — nagrywanie i odtwarzanie audio
- `BratText/ContentView.swift` — interfejs użytkownika (SwiftUI)

## Uwagi

- Transkrypcja działa w języku urządzenia (wspiera polski)
- Rozpoznawanie mowy wymaga Internetu (oprócz trybu only-on-device w iOS 13+)
- Pierwsze użycie poprosi o zgodę na mikrofon i rozpoznawanie mowy

## Licencja

MIT