"""Validate exports with jsonschema 4.25.1 and openapi-schema-validator 0.6.3.

Generate with EXPORT_CORPUS_PATH set when running schema_export_contract_test.dart,
then run: python tool/verify_schema_export.py path/to/corpus.json
Or run both corpora with: dart run tool/audit_schema_export.dart
"""
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator
from openapi_schema_validator import OAS31Validator

cases = json.loads(Path(sys.argv[1]).read_text())
for index, case in enumerate(cases):
    for key in ('inputSchema', 'outputSchema'):
        Draft202012Validator.check_schema(case[key])
    accepted = Draft202012Validator(case['inputSchema']).is_valid(case['input'])
    assert accepted == case['valid'], f'Input acceptance mismatch in case {index}: {case}'
    if case['valid']:
        Draft202012Validator(case['outputSchema']).validate(case['output'])
    for key, fallback in [('openApiInput', 'inputSchema'), ('openApiOutput', 'outputSchema')]:
        schema = dict(case.get(key, case[fallback]))
        schema.pop('$schema', None)
        OAS31Validator.check_schema(schema)
        validator = OAS31Validator(schema)
        if key == 'openApiInput':
            assert validator.is_valid(case['input']) == case['valid'], f'OpenAPI input mismatch in case {index}: {case}'
        elif case['valid']:
            validator.validate(case['output'])
print(f'Validated {len(cases)} runtime/input pairs and every successful output (JSON Schema 2020-12 and OpenAPI 3.1).')
