# Sortio AI — Backend Overview

> **Your files, tidy — and private.**
> Sortio AI is an Android app that organizes the files on your phone with your approval. All the AI runs **on the device**: no cloud, no account, and no file ever leaves the phone.

This document covers the backend: what it does, how it is built, and the tools and libraries it uses. The backend lives in `sortio_ai/lib/backend/`, and its tests live in `sortio_ai/test/backend/`.

---

## Table of contents

1. [What the backend does](#1-what-the-backend-does)
2. [Tech stack](#2-tech-stack)
3. [Architecture](#3-architecture)
4. [Folder structure](#4-folder-structure)
5. [The on-device AI](#5-the-on-device-ai)
6. [Feature walkthrough](#6-feature-walkthrough)
7. [Safety model](#7-safety-model)
8. [Data storage (SQLite)](#8-data-storage-sqlite)
9. [Privacy](#9-privacy)
10. [Performance and efficiency](#10-performance-and-efficiency)
11. [Android integration](#11-android-integration)
12. [Testing](#12-testing)
13. [Development tools](#13-development-tools)
14. [Build and run](#14-build-and-run)
15. [Known limitations](#15-known-limitations)

---

## 1. What the backend does

| Feature | What the user sees | How it works |
|---|---|---|
| **Organize Downloads** | Cards that say *"Move `invoice.pdf` → Documents"* with a reason. Nothing moves until the user approves. | A rules engine classifies files by extension and name pattern. Every change is checked by a safety validator. |
| **AI rename for scans** | `IMG_2043.pdf` → `2026-03_Meralco_Statement.pdf` | OCR reads the document. Regex finds the date. The on-device LLM names the issuer and document type. Code builds the final name. |
| **Plain-language search** | *"invoice from March"*, *"resibo sa Marso 2026"*, *"my payslip please"* | A SQLite FTS5 index over file names **and the text inside scans**, plus month and year filters. |
| **Undo** | *"Undo"* for one action or a whole batch, even after a restart. | Every action is written to a journal in SQLite before and after it runs. |
| **Quarantine** | Risky files (`.exe`, `.bat`, …) and duplicates are held, never deleted. | Files move to `Quarantine/holding_bin/`. Undo puts them back. |
| **Smart chat** | *"pa ayos ng files sa photos"*, *"approve"*, *"undo"*, *"salamat"* | Keyword intents first (English and Tagalog). The on-device LLM routes anything else. Search is the fallback. |
| **Duplicate finder** | *"Found 2 exact duplicates"* | Same size, then a 64-bit content hash. The extra copies go to Quarantine. |
| **Learns your habits** | *"Learned from your approvals: Meralco → Bills"* | Each approval is counted. After 2 approvals for the same issuer or extension, Sortio suggests that folder on its own. |
| **House rules** | *"Always file Zoom receipts under Finance"* | Plain-English and Tagalog rules are parsed **without AI**, so they are predictable. |
| **Editable naming template** | *"naming template {issuer}_{type}_{date}"* | A template engine with `{date}`, `{issuer}` and `{type}` placeholders, validated before it is saved. |
| **Scan a document with the camera** | Take a photo → *"Got it, that is a document. Here is where I would file it:"* | Camera → OCR → document check → suggestion card → AI name. |
| **Magic extract** | *"Total: ₱3,482.15"* and *"Contains Account Number"* badges | Regex over the OCR text finds amounts and sensitive data. |
| **Strictness** | *"Only 62% sure"* in amber | A confidence threshold (50–90%) that the user controls. "Approve all" skips cards below it. |
| **Privacy panel** | Offline status, plus "Wipe AI memory & logs" | A connectivity stream, and a wipe of the OCR/AI cache, chats and history. |

---

## 2. Tech stack

### Language and framework

| Tool | Version | Why |
|---|---|---|
| **Flutter** | 3.47.x | One codebase for the UI and the backend; the frontend team's stack. |
| **Dart** | 3.13.x (`sdk: ^3.12.0`) | The backend engine is pure Dart, so it is fast to test without a device. |
| **Kotlin** | (Android host) | A small `MethodChannel` that installs the bundled AI model on first launch. |

### On-device AI

| Tool | Version | Role |
|---|---|---|
| **Qwen3-0.6B** (Q4_K_M GGUF) | ~523 MB | The language model: document issuer and type, and chat intent routing. |
| **llama.cpp** via [`llamadart`](https://pub.dev/packages/llamadart) | 0.11.1 | Runs the GGUF model on the phone's CPU (arm64). |
| **GBNF grammar** | — | Generated from a JSON schema, so the model can only output valid JSON with the expected keys. |
| **Google ML Kit Text Recognition** ([`google_mlkit_text_recognition`](https://pub.dev/packages/google_mlkit_text_recognition)) | 0.17.1 | On-device OCR (bundled Latin model, works offline). |
| [`pdfx`](https://pub.dev/packages/pdfx) | 2.11.0 | Renders page 1 of a PDF to an image for OCR. |

### Storage and platform

| Package | Version | Role |
|---|---|---|
| [`sqlite3`](https://pub.dev/packages/sqlite3) + `sqlite3_flutter_libs` | 3.5.2 / ^0.5.32 | Local database: file index, FTS5 search, action journal, chats, settings, habits. |
| [`permission_handler`](https://pub.dev/packages/permission_handler) | 12.0.3 | "All files access" (`MANAGE_EXTERNAL_STORAGE`). Pinned for AGP 8 compatibility. |
| [`path_provider`](https://pub.dev/packages/path_provider) | ^2.1.6 | App-private folders for the database and the model. |
| [`path`](https://pub.dev/packages/path) | ^1.9.1 | Cross-platform path handling. |
| [`image_picker`](https://pub.dev/packages/image_picker) | ^1.2.4 | Camera capture for "Scan a document". |

### Development only

| Tool | Role |
|---|---|
| **Ollama** (`qwen3:0.6b`) | Test the prompts on the laptop before running them on the phone (`OllamaClient`, loopback addresses only). |
| `flutter_test` | Unit tests for the engine. |
| `flutter_lints` | Static analysis. |
| Android Emulator (Pixel 4, API 3x, x86_64) | End-to-end testing. |

---

## 3. Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Frontend (lib/frontend/)  — screens, widgets                    │
└───────────────▲──────────────────────────────────────────────────┘
                │  listens / calls (ChangeNotifier)
┌───────────────┴──────────────────────────────────────────────────┐
│  SortioController (lib/backend/controller.dart)                  │
│  UI state: cards, chats, settings, savings, chat router          │
└───┬──────────────┬──────────────────┬──────────────────┬─────────┘
    │              │                  │                  │
┌───▼────────┐ ┌───▼─────────┐ ┌──────▼───────┐ ┌────────▼────────┐
│ Engine     │ │ OcrService  │ │ LlamaDart-   │ │ ModelStore      │
│ LocalSortio│ │ ML Kit +    │ │ Client       │ │ install model   │
│ Core       │ │ pdfx        │ │ llama.cpp    │ │ from APK assets │
└───┬────────┘ └─────────────┘ └──────────────┘ └─────────────────┘
    │
    ├── RulesEngine     (no-AI classification)
    ├── HouseRules      (user rules, no AI)
    ├── Validator       (the only gate to the file system)
    ├── FileOps         (safe move, never overwrite)
    ├── RenameService   (OCR text → name; LLM for issuer + type only)
    ├── SearchQuery     (plain language → filters)
    └── SortioDb        (SQLite: index, FTS5, journal, chats, habits)
```

**Design principles**

1. **Rules first, AI second.** Deterministic code does most of the work: categories, dates, amounts, sensitive data and house rules. The small model only answers what code cannot, which is *who issued this document* and *what kind of document it is*.
2. **Approval before action.** `scan()` never changes anything. Only `apply()` touches the disk, and only after the user approves.
3. **One safety gate.** Every move, rename and folder creation goes through `Validator`, whether it came from rules, house rules, habits or the LLM.
4. **Everything is reversible.** Every action is journaled, and there is no delete operation in the engine.
5. **The engine is pure Dart.** `core/`, `rules/`, `naming/`, `search/`, `safety/` and `db/` do not import Flutter, so they run in plain unit tests.

---

## 4. Folder structure

```
sortio_ai/lib/backend/
├── sortio_core.dart          Engine barrel (the UI imports this as `core`)
├── controller.dart           SortioController: UI state + chat router
├── data_output.dart          Live data + all user-facing reply strings
├── models.dart               UI models (cards, chats, savings, folders)
│
├── core/
│   ├── sortio_core.dart          SortioCore interface
│   ├── local_sortio_core.dart    Real engine: scan, apply, undo, quarantine,
│   │                             duplicates, habits, search, AI rename
│   └── mock_sortio_core.dart     Mock engine for UI development
├── models/                   Suggestion, ActionRecord, results, ids
├── db/sortio_db.dart         SQLite schema v3 + queries
├── rules/
│   ├── rules_engine.dart         Extension/name rules, quarantine list
│   └── house_rules.dart          Plain-language user rules (EN + TL)
├── safety/validator.dart     The safety gate
├── fs/file_ops.dart          Safe move, unique names
├── search/search_query.dart  Plain language → keywords + month/year
├── naming/
│   ├── rename_service.dart       OCR text → AI name
│   ├── date_extractor.dart       Document date from OCR text (regex)
│   ├── issuer_cleaner.dart       "MANILA ELECTRIC CO. (MERALCO)" → "Meralco"
│   ├── name_builder.dart         Template → file name
│   └── content_insights.dart     Amount + sensitive-data badges
├── llm/
│   ├── llm_client.dart           LlmClient interface
│   ├── llamadart_client.dart     llama.cpp on the phone (request queue)
│   ├── ollama_client.dart        Local Ollama for development
│   ├── json_grammar.dart         JSON schema → GBNF grammar
│   └── prompts.dart              System prompts, schemas, enums
├── platform/
│   ├── ocr_service.dart          ML Kit OCR (+ pdfx for PDFs)
│   └── model_store.dart          Install the bundled model on first launch
└── privacy/network_status.dart   Offline indicator stream

sortio_ai/test/backend/       Engine tests (+ fakes.dart with FakeLlm)
sortio_ai/tool/               rename_demo.dart (Ollama), llamadart_check.dart
```

The design files (`design_tokens.dart`, `animations.dart`, `motion.dart`, `navigation.dart`, `routes.dart`) are in the same folder but belong to the frontend.

---

## 5. The on-device AI

### The model

- **Qwen3-0.6B, Q4_K_M quantization** (~523 MB GGUF). It is the smallest model that named documents reliably in our tests, and it is small enough to bundle in the APK.
- It runs through **llama.cpp** (`llamadart`) on the phone's CPU. It needs no GPU and no internet.
- The model is stored **uncompressed** in the APK (`noCompress += "gguf"`). On first launch, `ModelStore.ensureInstalled()` streams it into app-private storage through a Kotlin `MethodChannel`. It is removed when the app is uninstalled.

### How the AI is kept reliable

A 0.6B model is small, so the backend narrows each job down until the model can do it reliably:

| Technique | Effect |
|---|---|
| **Fixed answer lists (enums)** | `doc_type` must be one of 11 types (Invoice, Bill, Receipt, Payslip, Statement, ID, Contract, Letter, Certificate, Form, Other). The chat intent must be one of 9. |
| **GBNF grammar from the JSON schema** | The model *cannot* output anything except valid JSON with the required keys. |
| **Greedy decoding** (`temp: 0`, `topK: 1`) | The same input always gives the same answer. |
| **`/no_think`** | Turns off Qwen3's reasoning mode for short, fast answers. |
| **Small output budget** (96 tokens) | Answers are short and quick. |
| **Request queue** | llama.cpp serves one request at a time, so AI naming and chat routing take turns instead of overlapping. |
| **Timeouts** | Chat routing gives up after 8 seconds and falls back to search. |

### What the AI does vs. what code does

For a scan like `IMG_2043.pdf`:

| Step | Done by |
|---|---|
| Read the text | **ML Kit OCR** (page 1, rendered with `pdfx`) |
| Find the document date ("Bill Date: March 14, 2026" → `2026-03`) | **Regex** (`DateExtractor`), which prefers labeled dates |
| Detect the document type from headings ("OFFICIAL RECEIPT" → Receipt) | **Regex** (overrides the model when a clear heading exists) |
| Who issued it? What kind of document? | **Qwen3-0.6B** → `{"issuer": "MANILA ELECTRIC COMPANY", "doc_type": "Statement"}` |
| Clean the issuer ("MANILA ELECTRIC COMPANY (MERALCO)" → "Meralco") | **Code** (`IssuerCleaner`, which prefers known acronyms) |
| Build the name | **Code** (`NameBuilder`) → `2026-03_Meralco_Statement.pdf` |
| Amount + sensitive data badges | **Regex** (`ContentInsights`) |

### Prompts

The classify prompt is kept tiny on purpose:

> *From the OCR text of a scanned document, give the issuer as a short brand name (e.g. Meralco, 7-Eleven, BDO) and the document type. JSON only.*

The chat router prompt lists the intents (`tidy`, `search`, `duplicates`, `approve_all`, `ignore_all`, `undo`, `learned`, `help`, `thanks`), the folders (`downloads`, `photos`, `documents`, `any`) and a `query` for search. It accepts English, Tagalog and Taglish.

---

## 6. Feature walkthrough

### 6.1 Scan and suggest

`LocalSortioCore.scan(roots)`:

1. **Refresh the index.** An incremental `stat` of the allowed folders; only new or changed files are written.
2. **Find duplicates** (see 6.6).
3. For each top-level file, pick a destination in this priority order:
   1. **Duplicate** → Quarantine (*"Exact duplicate of …"*)
   2. **Photo folder** (DCIM/Camera, Pictures): only *documents* found in photos from the last 30 days are suggested (→ `Scans`). Normal photos are left alone.
   3. **House rule** (*"Your rule: Always file Zoom receipts under Finance"*)
   4. **Learned habit** (*"Learned from your approvals"*)
   5. **Rules engine** category: Documents, Images, Videos, Audio, Archives, Installers, Scans, or Quarantine for `.exe/.msi/.bat/.js/.jar/...`
4. Return suggestions with a reason and a confidence score. **Nothing is changed.**

### 6.2 Apply and undo

- `apply(suggestions)` validates each change, creates missing folders (each level is logged), moves or renames safely, and writes every step to the journal with a shared **batch id**.
- `undo(actionId)` and `undoBatch(batchId)` reverse the actions in reverse order, including removing folders that Sortio created and that are now empty.
- The journal is in SQLite, so **undo survives an app restart**.

### 6.3 AI rename

`aiRename()` streams updated suggestions back to the UI as each document is named, so cards update live. OCR text and AI names are **cached per file version**, so OCR and the LLM run at most once per file. When a habit exists for the issuer (e.g. Meralco → Bills), the AI rename also redirects the destination folder.

### 6.4 Search

`SearchQuery.parse()` turns plain language into filters without AI:

- **Keywords** with English and Tagalog stopwords removed (*please, can, you, paki, po, naman, nasaan, …*)
- **Month/year** in English and Tagalog (*March / Marso*, *2026*)

Then `searchWith()` runs a **SQLite FTS5** query over file names *and* OCR text. The date filter matches, in order, the date in the file name, the date printed inside the document, and the file's modified date. Every result explains why it matched, e.g. *"document text mentions 'payslip'"*.

### 6.5 Smart chat router

```
message
  │
  ├─► 1. Keyword intents (instant, EN + TL)
  │      tidy / ayusin · find / hanapin · approve / sige · skip / huwag
  │      undo / ibalik · duplicates / doble · naming template
  │      what did you learn · salamat · hi / help
  │      + folder scope: "sa photos", "my downloads", "documents"
  │
  ├─► 2. On-device AI router (Qwen3, enum intents, 8 s timeout)
  │
  └─► 3. Search fallback
```

There are also safety checks: if the AI says *help* or *thanks* but the message matches real files, Sortio shows the files instead. *"Approve all"* only applies cards above the strictness threshold, except Quarantine cards, which are always safe to apply.

### 6.6 Duplicate finder

1. Group files by size (≥ 1 KB, to skip trivial files).
2. Hash each candidate with **FNV-1a 64-bit**. Hashes are cached in SQLite.
3. Keep one copy per group, chosen in this order: a file already filed in a subfolder, then a file in a photo folder, then the oldest, then the shortest name.
4. Suggest moving the extras to **Quarantine** (never deleted).

### 6.7 Learns your habits

Every approved move records two keys in the `habits` table:

- `issuer:<Meralco>` → folder
- `ext:<pdf>` → folder

Once a key has been approved **2 or more times** for the same folder, `learnedFolder()` suggests it on its own. *"What did you learn?"* in the chat lists the habits. *Wipe AI memory* forgets them.

### 6.8 House rules

Typed in Settings and parsed **without AI**:

- *"Always file Zoom receipts under Finance"*
- *"Put payslips in Work/Payslips"*
- *"Ilagay ang mga resibo sa Finance"*

Keywords are stemmed (*receipts → receipt*) and matched against the file name **and** the OCR text. Rules are saved on the device (with a 1.2 s debounce) and kept when the AI memory is wiped.

### 6.9 Naming templates

The default is `{date}_{issuer}_{type}` → `2026-03_Meralco_Bill.pdf`. The user can change it in chat, e.g. *"naming template {issuer}_{type}_{date}"*. Templates are validated strictly: only the three placeholders, and every brace must be closed. When a part is missing, it is dropped along with its separator. Changing the template rebuilds all AI names. If a broken template was ever saved, it resets to the default on the next launch.

### 6.10 Scan a document with the camera

The **+** button opens the camera. The photo is saved as `SORTIO_yyyyMMdd_HHmmss.jpg` in DCIM/Camera (or Download). Sortio runs OCR on it. If it is a document (≥ 8 words), Sortio proposes where to file it and the AI names it. Otherwise it says it left the photo alone.

### 6.11 Strictness

A slider from 0 to 1 maps to a confidence threshold of **50%–90%**. Cards below the threshold show *"Only X% sure"* in amber and are skipped by *"approve all"*.

---

## 7. Safety model

`Validator` is the **only** gate to the file system. It enforces:

| Rule | Why |
|---|---|
| Only `move`, `rename` and `createFolder` | No delete, no edit of file contents. |
| Source and target must be inside the **allowed folders** the user enabled | Sortio cannot touch app data, system files or folders the user did not allow. |
| **Never overwrite**: suggestions get unique names (`file (1).pdf`), and any change whose target already exists is rejected | No data loss from name clashes. |
| A rename cannot change the folder, and the source must still exist | Stale or tampered suggestions are rejected. |
| Valid file names only (no `/ \ : * ? " < > |`, no empty names) | The LLM cannot produce a broken path. |
| No two suggestions in one batch can land on the same name | Batch-level conflict check. |
| Quarantine instead of delete | Everything can be restored with undo. |

The LLM never produces a path. It only returns an issuer string and a document type from a fixed list. Code builds the name, and the validator checks it.

---

## 8. Data storage (SQLite)

The database is `sortio.db` in app-private storage, in WAL mode. **Schema version 3**, with migrations:

| Version | Tables |
|---|---|
| v1 | `files` (path, name, size, mtime, ocr_text, ai_name) + `files_fts` (FTS5 over name + OCR text, kept in sync by triggers) + `actions` (the undo journal, with batch_id and an undone flag) |
| v2 | `chats`, `chat_messages` (persistent chat history), `settings` (house rules, naming template, welcome flag) |
| v3 | `files.hash` (duplicate finder) + `habits` (key, folder, count) |

**Wipe AI memory & logs** deletes the actions, habits, chats and messages, and clears the OCR text and AI names. Files on disk and settings (such as house rules) are kept.

---

## 9. Privacy

- **No network code in the app's AI path.** The OCR, the LLM and the database all run on the device. `OllamaClient` is for laptop development only and accepts loopback addresses only.
- The **model ships inside the APK**, so there is no download on first launch.
- `android:allowBackup="false"`, so the database is not copied to cloud backups.
- The **privacy panel** shows the live offline status and offers *Wipe AI memory & logs*.
- The app works in **airplane mode**.

---

## 10. Performance and efficiency

| Technique | Benefit |
|---|---|
| **Incremental index**: only `stat`, and only changed files are written | Rescans take milliseconds after the first one. |
| **OCR and AI cache per file version** | OCR and the LLM run at most once per file, and the cache follows the file when Sortio moves it. |
| **Model loaded once, lazily** | The first AI request loads it; later requests reuse it. |
| **Request queue** | No overlapping llama.cpp calls, which would crash or stall. |
| **Size-first duplicate check, cached hashes** | Only files with the same size are hashed, and only once. |
| **Rules before AI** | Most files never need the model. |
| **8 s chat routing timeout** | The chat never hangs on a slow phone. |
| **Scan generations** | An older scan's results are dropped if a newer scan started. |

Measured with Qwen3-0.6B on a laptop CPU: **4/4 sample documents named correctly**, about 4–7 s each after warm-up. Phones are slower, but naming runs in the background while the cards are already shown.

---

## 11. Android integration

- **Permissions** (`AndroidManifest.xml`): `MANAGE_EXTERNAL_STORAGE` ("All files access"), plus `READ/WRITE_EXTERNAL_STORAGE` for older Android versions, and `requestLegacyExternalStorage`.
- **Allowed folders**: Downloads (`Download/`), Photos (`DCIM/Camera`, `Pictures`, `Pictures/Screenshots`), Documents (`Documents/`). The user turns each one on or off.
- **Model install**: `MainActivity.kt` exposes `sortio/model` → `installBundledModel`, which streams the asset to `filesDir/models/`.
- **Build settings**: `androidResources { noCompress += "gguf" }` in `android/app/build.gradle.kts`. The release APK targets **arm64-v8a** (almost all modern Android phones).
- **Per-platform AI runtime** (`pubspec.yaml` hooks): `llama_cpp` on Android arm64/x64. On Windows, a lighter runtime avoids bundling the ~2 GB CUDA libraries.

---

## 12. Testing

```bash
cd sortio_ai
flutter test test/backend
```

There are **58 backend tests**, all passing. They use temporary folders and a `FakeLlm`, so they run in seconds without a device.

| File | Covers |
|---|---|
| `core_test.dart` | scan, apply, undo and nested undo, quarantine, duplicates, habits, issuer habits, camera documents, photos policy, house rules, chat persistence |
| `naming_test.dart` | date extraction, issuer cleaning, name templates, heading overrides, AI rename |
| `rules_engine_test.dart` | categories, quarantine extensions, scan detection |
| `search_query_test.dart` | keywords, stopwords, English/Tagalog months |
| `house_rules_test.dart` | English and Tagalog rule parsing |

These were also verified end to end on the Android emulator (Pixel 4): scan, approve, undo, quarantine, AI rename (Meralco statement, 7-Eleven receipt, payslip, Mercury Drug receipt from a photo), document-date search, persistent chats, house rules, strictness, the Photos policy, duplicates, and the smart chat in English and Tagalog.

---

## 13. Development tools

| Tool | Use |
|---|---|
| **VS Code** + Flutter extension | Development |
| **Android Studio SDK / Emulator** (Pixel 4) | Device testing |
| **Ollama** | Test prompts on the laptop (`dart run tool/rename_demo.dart`) |
| `tool/llamadart_check.dart` | Smoke test of the llama.cpp runtime |
| `flutter analyze` | Static analysis |
| **Git + GitHub** | Source control. The frontend and backend developers work in separate folders and merge on `main`. |

---

## 14. Build and run

```bash
cd sortio_ai
flutter pub get

# Development (emulator or phone)
flutter run

# Release APK with the bundled AI model
# 1. Put the model at android/app/src/main/assets/models/qwen3-0.6b-q4_k_m.gguf
#    (it is git-ignored because of its size)
# 2. Build for arm64 phones:
flutter build apk --release --target-platform android-arm64
# → build/app/outputs/flutter-apk/app-release.apk
```

**APK size:** about **530–560 MB**, almost all of which is the AI model. Without the model, the app is about 30–40 MB. On first launch, the model is copied into app storage, so the phone needs about **1.2 GB free**.

**Requirements:** Android 7.0+ (API 24), arm64 phone, about 3 GB RAM or more recommended for the model.

---

## 15. Known limitations

- **A small model has limits.** Qwen3-0.6B is good at picking from fixed lists, but it is not a general chatbot. The chat is keyword-first, and the AI is a fallback router.
- **OCR reads page 1 only** of a PDF, which is enough for the issuer, date and totals.
- **First AI request is slower** while the model loads into memory (a few seconds).
- **Release APK is arm64 only.** It does not run on x86 emulators; use a debug build there.
- **Camera capture** was verified up to the camera launch on the emulator; full capture needs a real phone.
- **"MB freed"** counts the size of files in Quarantine (space that *can* be freed). Sortio never deletes files itself.
