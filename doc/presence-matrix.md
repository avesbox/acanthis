# Presence, null, defaults, and PATCH

Contract accepted and implemented for the unreleased 2.0 working tree on
2026-09-13. This replaces the discrepancies characterized by the September 12
audit. These are deliberate compatibility changes, not snapshot-only updates.

## Field contract

| Field | Absent | Explicit null | Valid value | Invalid value |
| --- | --- | --- | --- | --- |
| Required | Required error | Type error | Preserved/validated | Failure |
| Required nullable | Required error | Preserved as null | Validated | Failure |
| Optional | Omitted | Type error | Validated | Failure |
| Optional nullable | Omitted | Preserved as null | Validated | Failure |
| Defaulted (including optional) | Validate default | Validate default | Validate supplied value | Failure |

Nullability controls values; `optionals()` controls presence. A non-null default
wins over nullable null preservation and optional omission. A default must pass
its schema's constraints and runs through its transformations once. The default
is never substituted for a non-null invalid input to turn failure into success.
Legacy unsuccessful results may still carry recovery values: those are not
validated output. Internal/public and sync/async nullable recovery now agree.
`nullable().withDefault(null)` explicitly supplies a null default; nullable
wrapping also preserves an existing default.

Pipeline defaults are output-typed: they are validated by the output schema
without running the input mapper. Ordinary field defaults are validated by their
field schema. Omitted defaulted fields pass through the validator just like null.

## Partial/PATCH and unknown keys

`partial()` and its explicit alias `patch()` make fields optional without making
them nullable. Omitted fields stay omitted even when they have defaults. Supplied
null still invokes the normal default/nullability rules. This means PATCH null
sets null only for nullable fields without a non-null default.

`partial(deep: true)` / `patch(deep: true)` recurse through directly nested object
schemas. They do not traverse list elements, lazy schemas, or nullable wrappers.
Whole-object refinements and dependencies are retained; applications must choose
rules compatible with incomplete input rather than assume partial disables them.

The original unknown-key policy is preserved:

- `unknownKeys(AcanthisUnknownKeys.strip)`: accept and remove extras (default).
- `unknownKeys(AcanthisUnknownKeys.preserve)` or `passthrough()`: retain extras.
- `unknownKeys(AcanthisUnknownKeys.reject)`: fail with `unknownKey` issues at each
  extra key. Throwing methods throw a validation error.
- `passthrough(type: ...)`: validate retained extra values with that schema.

## Explicit exports

`exportJsonSchema(mode: AcanthisSchemaMode.input)` emits JSON Schema 2020-12.
`exportOpenApiSchema(mode: AcanthisSchemaMode.input)` emits an OpenAPI 3.1 Schema
Object, not a complete OpenAPI document. Both also accept `output`.

Input exports allow omission and null when a default supplies the value. Output
exports require filled defaulted fields except in PATCH. Required nullable fields
remain required in both modes. Stripping accepts extras on input and excludes
them on output; preserve/reject policies apply on both sides.

The first supported subset is structural JSON schemas: objects, lists, nullable
values, ordinary unions, strings, booleans, `num` numbers, and JSON scalar
literals. Checks (including built-in constraints), coercion, transformations,
guards, recursive schemas, dates, and int/double-specific schemas currently throw
`AcanthisSchemaExportException` with a schema path. Export never executes custom
callbacks. Expanding audited constraints and recursive references remains backlog.
Legacy `toJsonSchema()` / `toOpenApiSchema()` retain their best-effort behavior and
are not the explicit runtime-equivalence contract. Defaults are deliberately not
exported as annotations, since pipeline and transformed defaults can differ from
serialized output and annotations do not execute defaulting.

## Verification

- `test/presence_contract_test.dart`: explicit intended behavior, throwing and
  non-throwing sync/async paths, PATCH, defaults, recovery, live state, and mapping.
- `tool/presence_matrix.dart` and `test/fixtures/presence_matrix.json`: reviewed
  snapshot of 504 execution observations. Legacy exports remain in the snapshot.
- `test/schema_export_contract_test.dart`: structural input/output fixtures. Set
  `EXPORT_CORPUS_PATH` to a temporary JSON path when running it, then run
  `python tool/verify_schema_export.py <path>` with `jsonschema==4.25.1` installed
  to check both dialect validity and runtime acceptance independently.

The historical benchmark baselines describe their original sources; they have
not been regenerated and are not measurements of this implementation.
