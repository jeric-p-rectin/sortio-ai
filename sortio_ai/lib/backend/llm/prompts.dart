/// Prompts and JSON schemas. Kept tiny on purpose: the small on-device model
/// only answers *who issued it* and *what kind of document*; dates and
/// naming are done in code.
library;

/// Allowed document types. A fixed list (enum in the schema) is what made
/// Qwen3-0.6B reliable in testing.
const docTypes = [
  'Invoice',
  'Bill',
  'Receipt',
  'Payslip',
  'Statement',
  'ID',
  'Contract',
  'Letter',
  'Certificate',
  'Form',
  'Other',
];

/// Chat intents the on-device model may pick when no keyword matched.
const chatIntents = [
  'tidy',
  'search',
  'duplicates',
  'approve_all',
  'ignore_all',
  'undo',
  'learned',
  'explain',
  'help',
  'thanks',
];

const routerSystemPrompt =
    'You route messages for Sortio, an on-device file organizer app. Pick the '
    "user's intent: tidy = organize or clean files; search = find a file (put "
    'the words to search for in query); duplicates = find copies; approve_all = '
    'accept the waiting suggestions; ignore_all = reject them; undo = reverse the '
    'last change; learned = what Sortio learned; explain = what a file '
    'says or is about (put the file name or topic in query); help = greetings or questions '
    'about what Sortio can do; thanks = gratitude. folder = the folder the user '
    'mentions, or any. Messages may be English, Tagalog or Taglish. JSON only.';

const routerSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'intent': {'type': 'string', 'enum': chatIntents},
    'folder': {
      'type': 'string',
      'enum': ['downloads', 'photos', 'documents', 'any'],
    },
    'query': {'type': 'string'},
  },
  'required': ['intent', 'folder', 'query'],
};

const summarizeSystemPrompt =
    "You read the OCR text of a document on the user's phone. Give its "
    'doc_type, the issuer (short brand or sender name, or empty), and a summary: '
    'one or two short plain-English sentences on what the document is and its '
    'key details (amounts, dates, purpose). Use only facts in the text. '
    'JSON only.';

const summarizeSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'doc_type': {'type': 'string', 'enum': docTypes},
    'issuer': {'type': 'string'},
    'summary': {'type': 'string'},
  },
  'required': ['doc_type', 'issuer', 'summary'],
};

const classifySystemPrompt =
    'From the OCR text of a scanned document, give the issuer as a short '
    'brand name (e.g. Meralco, 7-Eleven, BDO) and the document type. '
    'JSON only.';

const classifySchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'issuer': {'type': 'string'},
    'doc_type': {'type': 'string', 'enum': docTypes},
  },
  'required': ['issuer', 'doc_type'],
};
