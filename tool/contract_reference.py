"""Optional independent oracle generator; no Python dependency in Dart tests."""
import hashlib
import json
import sys
from importlib.metadata import version
from pathlib import Path

# Reuse the optional validation dependencies already installed for the V1 audit.
optional = Path('.dart_tool/schema-audit-python')
if optional.is_dir():
    sys.path.insert(0, str(optional))
from jsonschema import Draft202012Validator
from openapi_schema_validator import OAS31Validator

cases = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
count = 0
for case in cases:
    Draft202012Validator.check_schema(case['schema'])
    validator = Draft202012Validator(case['schema'])
    valid = [validator.is_valid(value) for value in case['inputs']]
    # OpenAPI's Schema Object dialect uses object schemas, not boolean roots.
    oas = case['schema']
    if isinstance(oas, bool):
        oas = {} if oas else {'not': {}}
    else:
        oas = {k: v for k, v in oas.items() if k != '$schema'}
    OAS31Validator.check_schema(oas)
    assert valid == [OAS31Validator(oas).is_valid(value) for value in case['inputs']], case['name']
    if 'native_expected' in case:
        assert case.pop('native_expected') == valid, case['name']
    case['valid'] = valid
    count += len(valid)

result = {
    'jsonschema_version': version('jsonschema'),
    'openapi_schema_validator_version': version('openapi-schema-validator'),
    'seed': 20261015,
    'pairs': count,
    'source_sha256': {path.as_posix(): hashlib.sha256(path.read_text(encoding='utf-8').encode('utf-8')).hexdigest() for path in [
        Path('tool/generate_v2_contract_reference.dart'), Path('tool/contract_reference.py'),
    ]},
    'cases': cases,
}
Path(sys.argv[2]).write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Captured {len(cases)} contracts / {count} input pairs with JSON Schema 2020-12 and OpenAPI 3.1 validators.')
