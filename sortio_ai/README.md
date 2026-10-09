# sortio_ai

**Sortio AI — Chat**, converted 1:1 from the HTML prototype
(`Sortio AI – Sortio AI — Chat prototype.html`) to Flutter.

## Project layout

```
lib/
├── main.dart                  App bootstrap (orientation, system UI chrome)
├── frontend/                  ALL SCREENS — one file per screen/piece
│   ├── app.dart               MaterialApp root, wired to the backend router
│   ├── chat_screen.dart       Main screen: column + scrim + drawer + sheet + toast
│   ├── status_bar.dart        In-canvas status bar (10:24, wifi, 82%)
│   ├── chat_header.dart       Header: menu, logo, model line, Offline Mode pill
│   ├── chat_feed.dart         Conversation: bubbles, date chip, typing dots
│   ├── suggestion_card.dart   Approve/Edit/Ignore cards + applied/ignored rows
│   ├── chat_composer.dart     Message input bar + privacy footer line
│   ├── toast.dart             Toast banner
│   ├── sessions_drawer.dart   Screen: Sessions drawer + Savings Summary
│   ├── privacy_sheet.dart     Screen: Privacy Command Center bottom sheet
│   └── shared_widgets.dart    Icon button, section label, press-scale
└── backend/                   LOGIC, DATA & MOTION — one file per concern
    ├── design_tokens.dart     Colors + font families (from the prototype CSS)
    ├── motion.dart            Durations & curves (the animation "spec")
    ├── models.dart            Data models (Suggestion, ChatMessage, ...)
    ├── data_output.dart       Mock on-device "model" — every agent string/dataset
    ├── controller.dart        SortioController: all app state & behaviour
    ├── animations.dart        PopIn, TypingDots, PulseBox, SortioSwitch,
    │                          CollapseOut, FadeThroughRoute
    └── routes.dart            Named routes + router
```

| Other | What it is |
| --- | --- |
| `assets/fonts/` | Sora + JetBrains Mono (bundled — fully offline, no google_fonts fetch) |
| `test/widget_test.dart` | Smoke tests: screen renders, drawer opens, sheet opens |

## Run on an Android emulator (one command)

```bat
run_android_emulator.bat
```

- Launches the first available Android AVD (or a specific one with
  `run_android_emulator.bat -EmulatorId <id>`), waits for boot, then `flutter run`.
- `run_android_emulator.bat -ListOnly` lists the emulators you have.
- No emulator yet? Create one: `flutter emulators --create --name SortioAI`,
  or in Android Studio → **Device Manager → Create Device**.
- Plain alternative: start any emulator, then `flutter run` from this folder.

The app is 100% on-device: no network calls, no external packages.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
