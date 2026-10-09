/// On-device backend for Sortio AI.
library;

// Core API
export 'core/sortio_core.dart';
export 'core/local_sortio_core.dart';
export 'core/mock_sortio_core.dart';

// Models
export 'models/action_record.dart';
export 'models/ids.dart';
export 'models/results.dart';
export 'models/suggestion.dart';

// Storage
export 'db/sortio_db.dart' show SortioDb, IndexedFile;

// Rules, safety, search
export 'rules/rules_engine.dart';
export 'safety/validator.dart';
export 'search/search_query.dart';

// AI naming
export 'llm/llm_client.dart';
export 'llm/ollama_client.dart';
export 'llm/prompts.dart';
export 'naming/date_extractor.dart';
export 'naming/issuer_cleaner.dart';
export 'naming/name_builder.dart';
export 'naming/rename_service.dart';

// Privacy
export 'privacy/network_status.dart';
