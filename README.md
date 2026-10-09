# Sortio AI

**A private, on-device file assistant for Android.**  
Sortio AI scans your folders, proposes tidy-ups, and waits for your approval before changing a single file. All processing runs locally — no cloud, no uploads, no account required.

---

## The Problem

Downloads folders accumulate files faster than anyone cleans them. Scanned documents arrive with names like `IMG_2043.pdf`. Finding one old invoice means opening files one by one. Cleaning up by hand is tedious, so it rarely gets done.

Cloud-based tools can help, but they require uploading private documents — bills, payslips, IDs — to an external server. For anyone handling sensitive files, that is not an acceptable trade-off.

Sortio AI addresses both problems: it automates the organisation and keeps every file on the device.

---

## What is Sortio AI?

Sortio AI is a Flutter application that acts as an on-device file agent. It reads the folders you permit, analyses their contents, and generates a list of suggested changes — each with a short reason. You review every suggestion before anything happens. Approved changes are applied and logged; every action can be undone, even after restarting the app.

The AI components (document classification, OCR, and plain-language search) run entirely on the device using a quantised small language model (Qwen3-0.6B via llama.cpp) and Google ML Kit's bundled text-recognition model.

---

## Tech Stack and Tools

| Tool / Library | Role |
|---|---|
| **Flutter / Dart** | Cross-platform UI and application framework. The app targets Android as the primary platform. |
| **llamadart** (`llamadart ^0.11.1`) | Dart binding for llama.cpp. Runs Qwen3-0.6B (GGUF) fully on the device. Output is constrained to valid JSON using a GBNF grammar derived from a JSON Schema, which eliminates post-processing failures. |
| **Google ML Kit Text Recognition** (`google_mlkit_text_recognition ^0.17.1`) | On-device OCR using a bundled Latin-script model. No network call is made. Used to read the text content of scanned images and PDFs. |
| **pdfx** (`pdfx ^2.11.0`) | Renders the first page of a PDF to a PNG image at 2x scale, which is then passed to ML Kit. |
| **SQLite via sqlite3** (`sqlite3 3.5.2`, `sqlite3_flutter_libs ^0.5.32`) | Persistent storage for the file index (with FTS5 full-text search), the OCR and AI-name cache, and the action journal that powers undo. |
| **permission_handler** (`12.0.3`) | Requests and checks Android storage permissions at runtime. Version pinned to maintain compatibility with AGP 8. |
| **path_provider** (`^2.1.6`) | Resolves the application support directory for the SQLite database files. |
| **path** (`^1.9.1`) | Path manipulation (join, normalize, canonicalize, basename) used throughout the engine. |
| **Sora** | Primary UI typeface, bundled in `assets/fonts/` — no network request at runtime. |
| **JetBrains Mono** | Monospace typeface for file paths and IDs, bundled in `assets/fonts/`. |

---

## Architecture

The codebase is split into two layers that communicate through a single interface (`SortioCore`).

```
lib/
  main.dart                   App entry point
  backend/                    Engine + UI state (no Flutter widgets, except controller)
  frontend/                   All widgets and screens
```

The engine modules inside `lib/backend/` are pure Dart and do not import Flutter. The `SortioController` (UI state) sits in `lib/backend/` because it is shared across screens, but it is the only file in that layer that imports Flutter.

```
SortioApp (MaterialApp)
  └── HomeShell (bottom nav + screen switcher)
        ├── HomeScreen
        ├── ChatScreen
        ├── FileManagerScreen
        ├── HistoryScreen
        └── SettingsScreen
              │  (all read/write)
              ▼
        SortioController (ChangeNotifier)
              │
              ▼
        SortioCore (interface)
          ├── LocalSortioCore  (production)
          │     ├── SortioDB        (SQLite: index, cache, journal)
          │     ├── Validator       (safety gate)
          │     ├── FileOps         (move / rename / create folder)
          │     ├── RenameService   (OCR → structured name)
          │     │     ├── LlamaDartClient  (llama.cpp on-device)
          │     │     ├── DateExtractor
          │     │     ├── IssuerCleaner
          │     │     └── NameBuilder
          │     ├── SearchQuery     (plain-language → filters)
          │     └── NetworkStatus   (offline stream)
          └── MockSortioCore   (demo / tests)
```

---

## Codebase Walkthrough

### `lib/backend/` — Engine and UI State

#### Core interface and implementations

| File | Purpose |
|---|---|
| `sortio_core.dart` | Re-exports the `SortioCore` abstract class. The only file the UI state layer imports from the engine. |
| `core/sortio_core.dart` | The `SortioCore` abstract class: declares `scan`, `apply`, `undo`, `undoBatch`, `quarantine`, `history`, `search`, and the `isOffline` stream. The UI develops against this contract. |
| `core/local_sortio_core.dart` | Production implementation. Opens the SQLite database, owns the `Validator`, drives the `RenameService`, and wires up the `NetworkStatus` stream. All file operations go through `FileOps` after passing the `Validator`. |
| `core/mock_sortio_core.dart` | Scripted demo implementation used during widget tests and when the llama.cpp plugin is unavailable (web, CI). Returns hard-coded suggestions and search results. |

#### UI state

| File | Purpose |
|---|---|
| `controller.dart` | `SortioController` — a `ChangeNotifier` that holds all app state: the suggestion list, active chat session, folder permissions, dark mode flag, strictness slider, house rules text, savings summary, and toast messages. Every screen reads from and writes to this class. Initialises the real engine on startup, falls back to the mock on failure. |
| `models.dart` | UI-layer data classes: `Suggestion` (a card in the chat feed), `ChatMessage`, `ChatSession`, `FolderAccess`, `SavingsSummary`, and `FileItem`. Distinct from the engine's `Suggestion` in `backend/models/suggestion.dart`. |
| `data_output.dart` | Static factory methods that produce the scripted demo data: the opening chat exchange, seed chat sessions, and the folder list. |
| `navigation.dart` | `SortioNavigationController` — wraps the bottom tab index and exposes helpers that screens call to switch tabs or open the chat. |
| `routes.dart` | `SortioRoutes` — maps named routes to widget builders. One route (`/`) is used; the bottom navigation handles all tab switching. |
| `motion.dart` | Shared animation durations and curves used across screens. |
| `design_tokens.dart` | `SortioColors` — static getters backed by a swappable `SortioPalette` (dark or light). `SortioFonts` — font-family constants. `SortioThemeBus` — a `ChangeNotifier` singleton that triggers a full-tree rebuild when the theme changes. |
| `animations.dart` | Reusable animated widgets: slide-in, fade-in, staggered list, and animated suggestion card state transitions. |

#### Engine modules (pure Dart)

| File | Purpose |
|---|---|
| `models/suggestion.dart` | Engine `Suggestion`: `sourcePath`, `targetPath`, `type` (`ActionType.move`, `.rename`, `.createFolder`), `reason`, `aiNamed`, `confidence`. Supports `copyWith` for editing before approval. |
| `models/action_record.dart` | `ActionRecord` — one row of the action journal: action ID, batch ID, type, paths, and timestamp. |
| `models/results.dart` | `ApplyResult` (batch ID + list of rejected suggestions), `UndoResult`, and `FileResult` (a search hit). |
| `models/ids.dart` | Short UUID generator used for batch IDs and action IDs. |
| `db/sortio_db.dart` | `SortioDB` — SQLite layer. Four tables: `files` (path, size, mtime, OCR text, AI name — with FTS5 virtual table for keyword search), `chat_sessions`, `chat_messages`, and `action_journal`. Provides incremental index refresh (only stat-checks and writes new or changed files), OCR/AI-name cache read/write, and journal append/lookup for undo. |
| `safety/validator.dart` | `Validator` — the single gate between the engine and the file system. Rejects any change that would leave the allowed folder set, overwrite an existing file, use an invalid file name, or apply a rename that changes the directory. |
| `fs/file_ops.dart` | `FileOps` — thin wrapper around `dart:io` that performs the actual move/rename/create-folder. Calls are only made after `Validator.check` returns `ok`. |
| `naming/rename_service.dart` | `RenameService` — orchestrates the OCR-to-name pipeline. Extracts a date by regex (`DateExtractor`), sends the first 1,200 characters of OCR text to the LLM to classify the issuer and document type, then builds the final name (`NameBuilder`). Falls back to heading keywords (`OFFICIAL RECEIPT`, `PAYSLIP`) to override a weak model guess. |
| `naming/date_extractor.dart` | `DateExtractor` — regex-based date parser. Handles ISO (`2026-03-15`), long-form (`March 15, 2026`), and short Filipino formats. Returns the most-confident match with a confidence score. |
| `naming/issuer_cleaner.dart` | `IssuerCleaner` — normalises the issuer string returned by the LLM: strips legal suffixes, collapses whitespace, and prefers an acronym when the document prints one in parentheses after the legal name (e.g. `MANILA ELECTRIC COMPANY (MERALCO)` → `MERALCO`). |
| `naming/name_builder.dart` | `NameBuilder` — assembles the final file name from parts: `{YYYY-MM}_{Issuer}_{DocType}.{ext}`. Handles missing parts gracefully. |
| `naming/content_insights.dart` | Extracts structured values from OCR text (e.g. totals, account numbers) for display in the suggestion card extract row. |
| `llm/llm_client.dart` | `LlmClient` abstract interface: one method, `completeJson`, that accepts a system prompt, a user prompt, and a JSON Schema and returns a typed map. |
| `llm/llamadart_client.dart` | `LlamaDartClient` — production `LlmClient`. Loads the GGUF model once via `LlamaEngine.load`, caches the GBNF grammar per schema, and runs inference with temperature 0 and top-k 1 for deterministic output. Appends `/no_think` to the user turn to suppress Qwen3's chain-of-thought block. |
| `llm/ollama_client.dart` | `OllamaClient` — development `LlmClient`. Sends requests to a local Ollama server (loopback only). Used with `qwen3:0.6b` during laptop development and the rename demo. |
| `llm/prompts.dart` | System prompt and JSON Schema (`classifySystemPrompt`, `classifySchema`) for the document-classification call. The schema constrains the model to return exactly `{"issuer": string\|null, "doc_type": string}`. |
| `llm/json_grammar.dart` | `jsonSchemaToGbnf` — converts a JSON Schema object to a GBNF grammar string, which llama.cpp uses to constrain token sampling so the output is always valid JSON with the expected keys. |
| `search/search_query.dart` | `SearchQuery` — represents a parsed search: keyword list, optional month, optional year. `SearchQuery.parse` is a rule-based parser with English and Tagalog stopword and month lists. `match` and `matchDate` apply the filters against a file name and its modified date without needing the database. |
| `privacy/network_status.dart` | `NetworkStatus` — wraps `dart:io`'s connectivity check in a `Stream<bool>` that emits `true` when the device has no network interface. Drives the privacy panel indicator. |
| `platform/ocr_service.dart` | `OcrService` — on-device OCR entry point. For images, delegates to `TextRecognizer` (ML Kit). For PDFs, uses `pdfx` to render page 1 at 2x scale to a temporary PNG, then passes that to `TextRecognizer`. Cleans up temporary files in a `finally` block. |
| `platform/model_store.dart` | `ModelStore` — resolves the path to the GGUF model file inside the application support directory and exposes the download/ready state to the controller. |

---

### `lib/frontend/` — Widgets and Screens

| File | Purpose |
|---|---|
| `app.dart` | `SortioApp` — the `MaterialApp` root. Listens to `SortioThemeBus` and rebuilds the `ThemeData` (brightness, colour scheme, font, splash) on every dark/light mode switch. |
| `home_shell.dart` | `HomeShell` — persistent shell that owns the `SortioController` and `SortioNavigationController` and wraps the four tab screens with the custom bottom navigation bar. |
| `nav_bar.dart` | Custom animated bottom navigation bar with a sliding indicator and per-tab active/inactive styles. |
| `home_screen.dart` | Dashboard: savings summary stats, quick-action buttons (Organise, Rename, Search), and a preview of the three most recent chat sessions. |
| `chat_screen.dart` | Main interaction screen: a scrollable feed of chat bubbles and suggestion cards, with the composer at the bottom. |
| `chat_feed.dart` | Renders the list of `ChatMessage` and `Suggestion` items in the chat feed. Handles the scripted opening exchange and the live AI reply stream. |
| `chat_header.dart` | The top bar of the chat screen: app logo, session title, and the offline indicator dot. |
| `chat_composer.dart` | Text input bar at the bottom of the chat: send button, voice placeholder, and dismiss-keyboard behaviour. |
| `suggestion_card.dart` | The approval card shown for each suggested change. Displays the source path, destination path (directory and file name split), a reason, an optional badge (sensitive content warning), and an optional extract row. Contains the Approve and Ignore buttons with animated exit transitions. |
| `file_manager_screen.dart` | Tabbed view of the allowed folders (Downloads, Documents, Screenshots, Quarantine). Lists `FileItem` rows with kind icon, size, modified date, sensitive badge, and a suggested highlight. |
| `history_screen.dart` | Two-tab screen: Chat history (list of `ChatSession` with preview and timestamp) and Action history (list of `ActionRecord` from the journal, with individual and batch undo). |
| `settings_screen.dart` | App settings: Dark mode toggle, allowed folders checklist, AI strictness slider, house rules text field, privacy panel (offline status, data location), and the two-tap memory wipe. |
| `shared_widgets.dart` | Small reusable widgets used by more than one screen: section headers, dividers, status chips, and the offline badge. |
| `toast.dart` | Lightweight in-app toast overlay driven by `SortioController.toastText`. Appears at the bottom of the screen with a fade-and-slide transition. |

---

## User Flow

```
1. Scan      The agent inspects the top level of each folder you have permitted.
             Nothing is changed. A list of suggestions is produced, each with a
             reason (e.g. "Meralco bill from March 2026").

2. Review    Each suggestion appears as a card in the chat feed. You can read
             the proposed source and destination paths, edit the destination
             before approving, or ignore the card entirely.

3. Approve   Tapping Approve marks the suggestion as accepted. Nothing on disk
             has changed yet.

4. Apply     When you confirm the batch, every approved suggestion passes through
             the Validator. Any that fail validation are returned as rejected with
             a reason; the rest are applied by FileOps and written to the action
             journal.

5. Undo      Any action or entire batch can be reversed from the History screen.
             Undo reads the journal, moves the file back, and removes the entry.
             This works across app restarts.
```

---

## Privacy and Safety Model

**Folder sandbox.** The engine only reads and writes inside the folders you explicitly permit. The `Validator` checks every source and destination path against the canonical allowed-root list before any file operation.

**Three operations only.** The only actions the engine can perform are move, rename, and create folder. Delete is not implemented.

**No overwrite.** The `Validator` rejects any change whose target path already exists on disk or is already claimed by another suggestion in the same batch.

**Quarantine instead of delete.** When a file is sent to quarantine, it is moved to `Sortio Quarantine/` inside the allowed folder set. It can be restored with undo.

**Full action journal.** Every applied change is written to SQLite before the file is moved. Undo reads the journal and reverses the move. The journal survives app restarts.

**Offline by design.** The LLM, OCR model, and FTS5 index all run on the device. The app works with Wi-Fi and mobile data turned off. The privacy panel reads the network status in real time and shows a live indicator.

**Constrained LLM output.** The llamadart client passes a GBNF grammar to llama.cpp so the model can only emit JSON that matches the expected schema. Malformed output is a runtime error, not a silent wrong action.

---

## Getting Started

### Prerequisites

- Flutter SDK 3.x (Dart `^3.12.0`)
- Android SDK with a connected device or emulator (API 24+)
- A GGUF model file — `Qwen3-0.6B-Q4_K_M.gguf` or equivalent — placed in the application support directory or built into the app bundle via `ModelStore`

### Run

```bash
git clone <repo-url>
cd sortio-ai/sortio_ai

flutter pub get
flutter run
```

For the Android emulator helper:

```powershell
.\run_android_emulator.ps1
```

### Development mode (Ollama instead of on-device LLM)

```bash
ollama pull qwen3:0.6b
dart run tool/rename_demo.dart
```

This sends four sample OCR texts through the full `RenameService` pipeline against the local Ollama server and prints the proposed names and confidence scores.

Benchmark: Qwen3-0.6B on a laptop CPU, after warm-up — 4/4 sample documents named correctly, roughly 4–7 seconds each.

---

## Tests

```bash
# Engine unit tests (FakeLlm, temporary folders, no device needed)
flutter test test/backend

# Live rename pipeline against a local Ollama server
dart run tool/rename_demo.dart
```

---

## Roadmap

### Required for the demo

- Organise Downloads with an approval screen
- Rename scans from their OCR content (`2026-03_Meralco_Invoice.pdf`)
- Plain-language file search (`invoice from March`, `resibo sa Marso 2026`)
- One-tap undo for any action or batch
- Privacy panel showing real-time offline status

### Planned

- Duplicate file finder
- Notification when a new file arrives in Downloads
- Confidence score shown on each suggestion card
- Editable naming templates
- Sensitive-file warning badge (IDs, payslips)
- Photograph a document and have it filed automatically

### Stretch

- Voice search
- Storage cleanup report with space-freed summary
- Exportable action log
- Plain-language rules (`always file Zoom receipts under Finance`)
- Multi-language search beyond English and Tagalog

---

## Project Context

Sortio AI was built as a hackathon project. The goal was to demonstrate that a useful, privacy-preserving file assistant is achievable on an ordinary Android phone without any cloud dependency.
