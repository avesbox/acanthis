# Audited schema export

Implementation: 2026-09-14. Targets: JSON Schema 2020-12 and OpenAPI 3.1
Schema Objects. The legacy `toJsonSchema()` and `toOpenApiSchema()` APIs remain
best-effort exporters; use `exportJsonSchema(mode: ...)` and
`exportOpenApiSchema(mode: ...)` for the audited subset.

`input` describes accepted JSON inputs, including null inputs replaced by valid
defaults. `output` describes successful JSON outputs, including inserted defaults
and stripped unknown properties. These contracts concern JSON values: finite
numbers, strings, booleans, null, lists, and objects with string keys. They do not
describe arbitrary Dart objects or promise to enumerate exactly every reachable
output. Presence follows [the presence contract](presence-matrix.md).

## Supported constraints

| Runtime behavior | Export |
| --- | --- |
| `number()` bounds (`gte`, `lte`, `gt`, `lt`, `between`) | Inclusive/exclusive minimum and maximum |
| Positive, negative, nonpositive, nonnegative numbers | Bounds at zero |
| Finite / not-NaN checks | No additional restriction on JSON numbers |
| Infinite / NaN checks | Unsatisfiable schema on JSON inputs |
| Numeric enumeration, scalar exact equality, string `contained` | Deduplicated `enum` |
| Boolean `isTrue` / `isFalse` | `const` |
| String `required` / `notEmpty` | `minLength: 1` |
| List `min`, `max`, `length` | `minItems` / `maxItems` |

Each check is retained in `allOf`, so repeated checks intersect and contradictory
bounds stay contradictory. Negative list bounds produce either a vacuous lower
bound or an unsatisfiable schema, matching runtime behavior. Non-finite constraint
parameters fail export. Defaults must pass validation before they can widen the
input contract to accept null. Ordinary overlapping unions use `anyOf`.

## Recursive objects

```dart
final tree = object({
  'value': number().gte(0),
  'children': lazy((parent) => parent.list().max(10)),
});
final input = tree.exportJsonSchema(mode: AcanthisSchemaMode.input);
```

References target deterministic, export-local `$defs`. Recursion can pass through
lists, nullable wrappers, and unions. Shared schemas and nested objects do not
share mutable export state across calls. Lazy callbacks must be deterministic
and reuse stable schema identities. `parent.list()` and `parent.nullable()` work;
callbacks rebuilding the parent on every expansion, such as
`parent.passthrough().list()`, fail with a diagnostic after 64 active schema
levels. This bound also applies to deeply nested acyclic schemas. Configure
the parent policy before using it recursively. Lazy entries are supported as
direct object fields, matching their runtime parent-resolution API.

The OpenAPI API returns a standalone Schema Object, not an OpenAPI document.
Local references are relative to that returned resource. If embedding it inside
a larger document, preserve a separate schema resource or rebase the references
to its document location.

## Explicit limitations

Unsupported behavior throws `AcanthisSchemaExportException` with an escaped
schema path and a reason. Checks are recognized by their built-in classes,
not a custom callback's name or parameter dictionary.

* String length checks count UTF-16 units, whereas JSON Schema length counts
  Unicode code points. For example, `string().min(2)` accepts a single emoji;
  JSON Schema `minLength: 2` does not. General length checks remain unsupported.
* List uniqueness uses Dart equality, whereas JSON Schema compares JSON values
  structurally. Collection equality and membership have not been audited.
* Dart int/double representation checks and typed numeric schemas have no exact
  JSON representation equivalent. Floating-point `multipleOf` remains unaudited.
* Object property-count checks run after normalization; input stripping and
  inserted defaults prevent a direct property-count keyword mapping.
* Regexes, formats, enum name callbacks, arbitrary checks, async operations,
  coercion, transformations, variant guards, cross-field rules, and operations
  attached to `LazyEntry` remain unsupported. Tuples, dates, instances, and other
  unaudited schema types also fail explicitly.
* Presentation metadata is limited to title, description, deprecated, readOnly,
  and writeOnly. Metadata cannot override validation or reference keywords.

See the official [validation specification](https://json-schema.org/draft/2020-12/json-schema-validation)
and [core specification](https://json-schema.org/draft/2020-12/json-schema-core)
for keyword and reference semantics.

## Reproduce verification

From the package root:

```sh
python -m pip install jsonschema==4.25.1 openapi-schema-validator==0.6.3
dart run tool/audit_schema_export.dart
dart analyze
dart run test
```

The runner generates temporary corpora and checks them with both independent
validators. Its optional argument adds a local dependency directory to
`PYTHONPATH`. The original structural corpus contains 140 cases; the new audit
contains 1,480 cases, including repeated and contradictory constraints, nullable
defaults, recursive lists and linked objects, shared schemas, escaped field
names, unknown-key policies, PATCH, and overlapping unions. Runtime checks compare
sync and async recovery and successful throwing parses. Separate regressions
cover diagnostics, metadata, and export state isolation.

Verification on 2026-09-14: 407 Dart tests passed. The exporter changes do not
change runtime validation; existing performance archives have not been refreshed.
