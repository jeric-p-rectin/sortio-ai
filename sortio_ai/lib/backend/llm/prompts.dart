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
