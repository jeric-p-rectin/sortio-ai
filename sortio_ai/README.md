# sortio_ai

**Sortio AI — Chat**, converted 1:1 from the HTML prototype
(`Sortio AI – Sortio AI — Chat prototype.html`) to Flutter.

## Project layout

```
lib/
├── main.dart                  App bootstrap (orientation, system UI chrome)
├── frontend/                  ALL SCREENS — one file per screen/piece
│   ├── app.dart               MaterialApp root, wired to the backend router
│   ├── home_shell.dart        Navigation shell: tabs + nav bar (owns shared state)
│   ├── nav_bar.dart           Full-bleed bottom bar: 4 tabs + floating "+" (chat)
│   ├── home_screen.dart       Screen: Home — greeting, stats, quick actions
│   ├── history_screen.dart    Screen: History — the on-device action log
│   ├── file_manager_screen.dart  Screen: Files — sandboxed folders + file list
│   ├── settings_screen.dart   Screen: Settings — Privacy Command Center
│   ├── chat_screen.dart       Screen: Chat (opened by the "+" button)
│   ├── status_bar.dart        In-canvas status bar (10:24, wifi, 82%)
│   ├── chat_header.dart       Header: menu, logo, model line, Offline Mode pill
│   ├── chat_feed.dart         Conversation: bubbles, date chip, typing dots
│   ├── suggestion_card.dart   Approve/Edit/Ignore cards + applied/ignored rows
│   ├── chat_composer.dart     Message input bar + privacy footer line
│   ├── toast.dart             Toast banner
│   ├── sessions_drawer.dart   Overlay: Sessions drawer + Savings Summary
│   └── shared_widgets.dart    Icon button, section label, press-scale, stat cell
└── backend/                   LOGIC, DATA & MOTION — one file per concern
    ├── design_tokens.dart     Colors + font families (from the prototype CSS)
    ├── motion.dart            Durations & curves (the animation "spec")
    ├── models.dart            Data models (Suggestion, ChatMessage, FileItem, ...)
    ├── data_output.dart       Mock on-device "model" — every agent string/dataset
    ├── controller.dart        SortioController: all app state & behaviour
    ├── navigation.dart        Tab model: Home/History/(+)Chat/Files/Settings
    ├── animations.dart        PopIn, TypingDots, PulseBox, SortioSwitch,
    │                          CollapseOut, FadeThroughRoute
    └── routes.dart            Named routes + router
```

### Navigation

The bottom navigation bar is **full-bleed** — no margins left/right/bottom;
it is glued to the screen edge and extends behind the system gesture area.

| Bar item | Screen |
| --- | --- |
| Home (1st) | Home — greeting, savings stats, quick actions, recent activity |
| History (2nd) | History — every logged action, on-device only |
| **+** (centre, floating) | **Chat** — the Sortio assistant (prototype screen) |
| Files (3rd) | File Manager — sandboxed folders, suggested/sensitive badges |
| Settings (4th) | Settings — the Privacy Command Center as a full page |

The chat header's gear button also jumps to the Settings tab. All tabs share
one `SortioController`, so folder permissions and rules stay in sync between
Chat, Files and Settings.

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
