# Contract export and import

V2 supports strict native JSON Schema/OpenAPI export and compiled import.
Native metadata annotations are supported; see
[metadata and mocks](metadata-and-mocks.md) for annotation and registry behavior.
Strings, numbers, booleans, scalar literals, nullable wrappers, objects, lists,
records with string keys, and parent-bound
recursive lazy schemas participate in the same audited contract. Both
`exportJsonSchema` / `exportOpenApiSchema` and `toJsonSchema` /
`toOpenApiSchema` use the strict exporter. `toJsonSchema` defaults to input mode;
the other three methods require an explicit mode.

```dart
import 'package:acanthis/acanthis.dart' as acanthis;

final schema = acanthis.number().gte(0).lte(10).withDefault(3);
final definition = schema.exportJsonSchema(
  mode: acanthis.AcanthisSchemaMode.input,
);
final contract = acanthis.importJsonSchema(definition);
final accepted = contract.validate(5); // true
final rejected = contract.tryParse(11);    // union issue, with an lte branch issue
```

`exportJsonSchema(mode: ...)` emits JSON Schema 2020-12. `exportOpenApiSchema`
emits an OpenAPI 3.1 Schema Object, not a whole OpenAPI document. The mode selects
accepted JSON inputs or successful JSON outputs. A valid native default admits
null in the input contract; output export omits that alternative.

The native exporter supports string, num and boolean constraints, scalar literals,
nullable branches and enumeration, object presence and
unknown-key policies, list length and scalar membership/uniqueness checks,
object property-count checks and typed passthrough values,
record property names and values, defaults, and recursive lazy references.
Repeated constraints remain conjunctive `allOf` entries. Recursive nodes use
local `$defs` / `$ref` references in both dialects. Nested imported contracts
retain their own reference scope, including when annotations or constant data
contain a literal `$ref` property.

As in V1, exact export rejects coercion, transformations, custom/async checks,
including selected-field rules and legacy field dependencies,
Dart int/double representation restrictions, UTF-16 string length predicates,
and unaudited format/pattern/remainder checks. V2 also rejects non-finite
defaults and numeric constraints outside ±(2^53−1), where mixed Dart int/double
comparisons can disagree with exact JSON numeric equality. Export errors are
`AcanthisSchemaExportException` with `path` and `reason`; rejected callbacks
are never executed as part of the audit.

V1's [field-based instance export](instances.md#field-based-export) is also
available. It describes the declared JSON field representation without invoking
getters or constructors; it does not make `InstanceType<T>` accept decoded JSON
maps. Required flags come from field declarations, and instance defaults are
not projected. Child contracts retain the strict audit above. Class pipelines
can export `inType` and a described `outType` explicitly; arbitrary mapping
callbacks still have no automatic JSON contract.

## Import

`importJsonSchema(document)` and `importOpenApiSchema(document)` accept decoded
JSON schema objects or boolean schemas and return `AcanthisJsonContract`, a
`Schema<Object?, Object?>` with all four parsing entry points and bool validation.
Both functions are also available on `Acanthis` / `AcanthisType`.
Explicit dialect markers may select JSON Schema 2020-12 or the
[OpenAPI 3.1 base dialect](https://spec.openapis.org/oas/v3.1.0#schema-object).

The importer compiles these contracts directly; it does not require public
fluent object, list, boolean, or nullable schema implementations:

- JSON `type` and type arrays, including mathematical `integer` (accepts 1.0).
- `const`, `enum`, numeric bounds, Unicode code-point string length bounds.
- Array `items`, length bounds, and structural JSON `uniqueItems` equality.
- Object `properties`, `required`, property count bounds, and
  `additionalProperties` (boolean or schema).
- Object `propertyNames` and array `contains`, including recursive schemas.
- `allOf`, `anyOf`, `not`, `$defs`, and local JSON Pointer `$ref` with siblings.
- Recursive references that descend through properties, additional values,
  or array items. Shared compiled nodes are audited for same-value reference
  cycles before use; external references and anchors are rejected.
- JSON annotations (`title`, `description`, `$comment`, `default`, `examples`,
  `deprecated`, `readOnly`, `writeOnly`) are preserved without changing parsing.

The importer rejects unknown/misspelled or unsupported keywords, including
`format`, `pattern`, `multipleOf`, `oneOf`, conditional/unevaluated keywords,
`$id`, and OpenAPI 3.0 `nullable`. It never silently drops validation. Errors
are `AcanthisSchemaImportException` with an escaped JSON Pointer to the contract
location and a reason.

Compilation snapshots and freezes the definition. Import once and reuse the
result; no schema-map interpretation occurs in the parsing loop. Successful
parses return the submitted value. Failed `tryParse` outcomes retain it as
recovery, with ordered V2 issues and typed nested paths. `parse` throws
`ValidationError` at the first failure; `tryParse` collects.
`anyOf` failures retain branch diagnostics. Async methods delegate to the same
synchronous compiled validator. Messages use the normal extensible catalog.

Import validates the contract, not the original runtime program: it does not
restore coercion, transformations, custom callbacks, or default substitution.
JSON `default` is an annotation. An imported input contract can accept null and
return null even when the original native schema would substitute a default.

Only JSON values are valid inputs: finite numbers, strings, bool, null, lists,
and maps with string keys. Cyclic/non-JSON inputs fail validation. Compilation
limits definitions to 64 container levels/16,384 JSON nodes and expansion to
4,096 schema nodes/64 active reference levels. Runtime JSON container depth is
limited to 128. Integer length bounds must fit ±(2^53−1). These are explicit
resource limits, not claims of complete JSON Schema vocabulary support.

## Snapshots, round trips and performance

Exports are fresh mutable maps, including nested lists/maps. Editing one cannot
change the native schema, an imported definition, or later exports. Native
exporters defer snapshot-builder compilation until a second export; subsequent
exports use weakly cached builders. The cache never retains a caller's mutable
result. Imported contracts re-export their preserved JSON definition (boolean
roots are normalized to equivalent object schemas).

## Native collection contracts

```dart
final tree = object({
  'name': string().notEmpty(),
  'children': lazy((parent) => parent.list().max(10)).withDefault([]),
});
final input = tree.toJsonSchema(mode: AcanthisSchemaMode.input);
final output = tree.toOpenApiSchema(mode: AcanthisSchemaMode.output);
```

Objects distinguish missing fields from explicit null. An optional field with
a valid default can be omitted in the input contract and is required in the
output contract because parsing materializes it. `partial()` preserves omission
and keeps that field optional in both modes. Child defaults still accept explicit
null in input mode. Exported JSON `default` annotations are never relied upon to
perform substitution.

| Unknown-key policy | Input `additionalProperties` | Output `additionalProperties` |
| --- | --- | --- |
| strip | true | false |
| preserve | true | true |
| reject | false | false |

Typed `passthrough(type: schema)` exports the extra-value schema as
`additionalProperties` in both modes. Recursive extra values use the same local
references as named recursive fields.

Native `minProperties`, `maxProperties`, and `lengthProperties` checks observe
the parsed map. Output contracts express ordinary property-count bounds. Input
contracts account for stripped unknown keys and inserted defaults: projected
declared-key counts use presence combinations, while preserved-key counts
adjust raw length for absent defaulted fields. Export never substitutes an
incorrect bound on raw input size. These expansions are limited to 4,096
branches; configurations exceeding that limit fail explicitly. Count bounds
must fit the JSON safe integer range. Root transforms and custom/async checks
remain unsupported by strict export.

Records use `propertyNames` for the key schema and `additionalProperties` for
values. Keys must have an audited string schema; coercing/transformed keys and
Dart-only key representations are rejected. List membership and uniqueness are
audited for scalar elements. Structural container equality differs from Dart
container identity, so it is rejected rather than exported as `uniqueItems`.
Input membership checks account for child defaults before comparing values:
for example, `list(string().withDefault('x')).contains('x')` accepts `[null]`,
while its `unique()` variant rejects `[null, 'x']`.

The entire schema is audited before checking collection defaults. Default
validation uses a compiled input contract, never native validation callbacks.
Cached exports recheck default values on every call, so a caller-owned nested
default that becomes invalid cannot silently retain a stale null-admitting
contract. Exported snapshots remain independently mutable.

Unsupported checks, transforms, async behavior, invalid defaults, unbound lazy
entries, and failed resolvers produce `AcanthisSchemaExportException` with an
escaped JSON Pointer path. The existing numeric representation, UTF-16 length,
coercion, and unsafe numeric constraint restrictions still apply. Graph export
is bounded to 4,096 nodes and 64 active definition levels.

Run the complete native export audit from the repository root:

```sh
python -m pip install -r tool/schema-export-requirements.txt
dart run tool/audit_schema_export.dart
```

The runner generates six nonempty corpora from the current primitive, boolean,
nullable, literal, collection and object-helper suites, then independently checks
input acceptance and successful output with both JSON Schema 2020-12 and OpenAPI
3.1 validators. The six corpora cover 20,104 runtime/input pairs. Each distinct
schema is checked and compiled once per dialect; every data case is still
validated. A Dart test failure, missing/empty corpus or validator mismatch
fails the command. Generated corpora use a temporary directory cleaned after the run.
An optional argument adds a dependency directory to `PYTHONPATH`, for example
`dart run tool/audit_schema_export.dart .dart_tool/schema-audit-python`.

The collection corpus is generated by `test/collection_export_test.dart` with
`COLLECTION_EXPORT_CORPUS` set. `tool/verify_schema_export.py` verifies native
acceptance and successful output using independent JSON Schema 2020-12 and
OpenAPI 3.1 validators.
The object-helper corpus is generated by `test/object_helpers_export_test.dart`
with `OBJECT_HELPERS_EXPORT_CORPUS` set and uses the same independent audit.

The mappings follow the official [object keyword documentation](https://json-schema.org/understanding-json-schema/reference/object),
[recursive schema documentation](https://json-schema.org/understanding-json-schema/structuring),
and [OpenAPI 3.1 Schema Object specification](https://spec.openapis.org/oas/v3.1.1.html#schema-object).

The separate checked-in importer oracle contains 48 contracts / 10,032 input
pairs generated with independent `jsonschema` 4.25.1 and
`openapi-schema-validator` 0.6.3 validators. Dart tests exercise those pairs through all
four entry points and an import/export round trip, including recursive data,
Unicode, signed zero, structural equality, and numeric boundary cases.

Use the [benchmark guide](../../benchmark/README.md) for current comparison
commands and measurement limits. Compile an imported contract once and reuse it
instead of rebuilding it for every input.

```powershell
dart test --reporter failures-only
dart test test/contract_test.dart --compiler exe --reporter failures-only
dart run example/v2_contract.dart
# Optional oracle regeneration: requires jsonschema/openapi-schema-validator.
dart run tool/generate_v2_contract_reference.dart [path-to-python]
```

The full current suite targets V2. Archived V1 code remains under `v1/` for
explicit compatibility and benchmark comparisons.
