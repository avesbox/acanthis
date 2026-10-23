"""Validate exports with jsonschema 4.25.1 and openapi-schema-validator 0.6.3.

Generate with COLLECTION_EXPORT_CORPUS set when running test/collection_export_test.dart,
then run: python tool/verify_schema_export.py path/to/corpus.json
Or run all current corpora with: dart run tool/audit_schema_export.dart
"""
import json
import sys
from functools import cache
from pathlib import Path

from jsonschema import Draft202012Validator
from openapi_schema_validator import OAS31Validator


@cache
def validator_for(definition, openapi):
    # Audit each distinct schema once; still validate every input and output.
    schema = json.loads(definition)
    validator_type = OAS31Validator if openapi else Draft202012Validator
    validator_type.check_schema(schema)
    return validator_type(schema)


cases = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
if not isinstance(cases, list) or not cases:
    raise ValueError('Expected a nonempty export corpus')
for index, case in enumerate(cases):
    validators = {
        key: validator_for(json.dumps(case[key], sort_keys=True), False)
        for key in ('inputSchema', 'outputSchema')
    }
    accepted = validators['inputSchema'].is_valid(case['input'])
    assert accepted == case['valid'], f'Input acceptance mismatch in case {index}: {case}'
    if case['valid']:
        validators['outputSchema'].validate(case['output'])
    for key, fallback in [('openApiInput', 'inputSchema'), ('openApiOutput', 'outputSchema')]:
        schema = dict(case.get(key, case[fallback]))
        schema.pop('$schema', None)
        validator = validator_for(json.dumps(schema, sort_keys=True), True)
        if key == 'openApiInput':
            assert validator.is_valid(case['input']) == case['valid'], f'OpenAPI input mismatch in case {index}: {case}'
        elif case['valid']:
            validator.validate(case['output'])
print(f'Validated {len(cases)} runtime/input pairs and every successful output (JSON Schema 2020-12 and OpenAPI 3.1).')
