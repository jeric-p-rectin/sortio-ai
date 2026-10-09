# Sortio backend (`lib/backend/`)

The on-device backend for Sortio AI. The engine folders listed below are pure Dart and don't import Flutter. The only network access is an optional call to a **local** Ollama server during development.

## What it does

- **Scan.** Looks at the top level of the allowed folders and proposes moves, each with a reason. Scanning changes nothing.
- **AI rename.** Turns OCR text into a name like `IMG_2043.pdf → 2026-03_Meralco_Bill.pdf`. A regex reads the date, the LLM picks the issuer and the document type from a fixed list, and code cleans up and builds the name.
- **Validate.** Allows only move, rename and create folder. Changes must stay inside the allowed folders, can never overwrite a file, and must use valid names.
- **Apply and undo.** Every action is written to a journal in SQLite. You can undo one action or a whole batch, and undo still works after an app restart.
- **Quarantine.** Moves a file to `Sortio Quarantine/` instead of deleting it. Restore it with undo.
- **Index.** A SQLite file index with FTS5. A refresh is incremental: it only `stat`s files, and writes only the files that are new or changed.
- **Cache.** OCR text and AI names are saved per file version, so OCR and the LLM run at most once per file. The cache follows the file when Sortio moves or renames it.
- **Search.** Understands queries like "invoice from March" or "resibo sa Marso 2026". It matches the file name, the text inside scans, and the modified date.

## Structure

```
lib/backend/
  sortio_core.dart          engine API (import only this from the UI layer)
  core/                     SortioCore interface, LocalSortioCore, MockSortioCore
  models/                   Suggestion, ActionRecord, ApplyResult/UndoResult/FileResult, ids
  db/                       SQLite: file index + FTS5, OCR/AI cache, action journal
  rules/                    extension/name rules (no AI)
  safety/                   Validator: the only gate to the file system
  fs/                       safe move, unique (never-overwrite) names
  search/                   SearchQuery: plain language → filters
  naming/                   DateExtractor, IssuerCleaner, NameBuilder, RenameService
  llm/                      LlmClient interface, OllamaClient, prompts + schemas
  privacy/                  offline status for the privacy panel

  controller.dart, models.dart, data_output.dart, ...   UI state (frontend)
test/backend/               engine tests, plus fakes.dart (FakeLlm)
tool/rename_demo.dart       live check against Ollama
```

The engine's `Suggestion` is a different class from the UI's `Suggestion` in `models.dart`. Import the engine with a prefix in UI-state code:

```dart
import 'sortio_core.dart' as core;
```

## Use in the Flutter app

```dart
import 'package:sortio_ai/backend/sortio_core.dart';
import 'package:path_provider/path_provider.dart';

// While building the UI:
final SortioCore core = MockSortioCore();

// Real implementation:
final dataDir = (await getApplicationSupportDirectory()).path;
final core = LocalSortioCore(dataDir: dataDir);

final suggestions = await core.scan(['/storage/emulated/0/Download']);
final result = await core.apply(approvedSuggestions); // result.batchId, .rejected
await core.undoBatch(result.batchId);                 // "Undo all"
final hits = await core.search('invoice from March');
core.isOffline.listen((offline) => /* privacy panel */);
```

Allow editing a suggestion before approval with `suggestion.copyWith(targetPath: ...)`.

### AI rename (stream updates into the approval list)

```dart
final service = RenameService(llm);   // llm: any LlmClient (llama.cpp on the phone)
core.aiRename(suggestions, service, ocr: runOcr).listen((updated) {
  // Same id as the original suggestion: replace it in the list.
  // updated.targetName == '2026-03_Meralco_Bill.pdf', updated.aiNamed == true
});
```

`runOcr(path)` is provided by the Flutter side (ML Kit). For a PDF, render page 1 with `pdfx` first, then OCR the image. Return `''` when no text is found.

### LLM on the phone

Implement `LlmClient.completeJson` with llama.cpp. Pass the schema to llama.cpp as a JSON grammar, and use `prompts.dart` for the system prompt. On the laptop, use `OllamaClient(model: 'qwen3:0.6b')`, which only accepts loopback addresses.

## Checks

```
flutter test test/backend         # engine tests (FakeLlm, temp folders)
dart run tool/rename_demo.dart     # live: needs `ollama pull qwen3:0.6b`
```

Live result with Qwen3-0.6B on the laptop CPU, after a warm-up call: 4/4 sample documents named correctly, about 4–7 s each.
