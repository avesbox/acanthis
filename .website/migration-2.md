# Migrating to 2.0

## SDK requirement

Acanthis 2.0 requires Dart 3.13 or later. Flutter applications need a Flutter
SDK that includes a compatible Dart version.

## Parsed values can share input identity

Validation without output changes can return the original map or typed list
through `result.value`. The result wrapper remains an `AcanthisParseResult`.
Mutations through the returned container may affect the input, and read-only
input may produce read-only output.

```dart
final input = {'name': 'Ada'};
final result = object({'name': string()}).parse(input);
final independent = Map<String, dynamic>.of(result.value);
```

This creates an independent outer map, not a deep clone. Use `List.of` for
an independent outer list. Schemas with transformations, coercion or defaults
retain their output handling.

## Nested object stripping

Unknown keys are stripped at every object level, including objects inside
lists. Use `passthrough()` on each object schema whose extra keys should be
retained. When nested stripping changes a value, the affected ancestor maps
and lists are copied; the original input is not modified. Unchanged containers
can still be reused.

## Async and non-throwing parsing

Calling `parseAsync` or `tryParseAsync` on a synchronous map or list schema now
runs the same parsing path as its synchronous counterpart. Transformations
execute once. Schemas with async checks must use async entry points.

Wrong map/list input types and non-string map keys produce failed results in
`tryParse` and `tryParseAsync`, including when nested. User callbacks can still
throw their own exceptions; these APIs do not suppress arbitrary application
errors.

## New result and session APIs

`validate` and `validateAsync` expose typed success/failure outcomes and
structured issues; see [Validation Results](/validation-results).
Object schemas expose `watch` and `watchAsync` for live sessions. Synchronous
sessions provide `explain(field)`; there is no `explainAsync` method.
See [Live Validation](/live-validation) for update deltas and async behavior.

## Diagnostic paths and legacy errors

The structured outcome API was introduced during unreleased 2.0 development.
Its final path contract uses data locations only: the draft
`['account', 'email', 'email']` becomes `['account', 'email']`, with `email`
kept separately as the code. Published 1.x did not expose this structured API.
List and tuple indices are integers. Update any adapters written against the
2.0 draft to stop removing a trailing check segment.

Use `result.issues` for complete ordered diagnostics and `branches` for union
failures. `errors` stays available but drops duplicate codes, index types, and
union branch details. Missing-dependency failures now use the stable
`dependency` code and put the dependency name in `parameters.dependsOn`.
Built-in coercion messages no longer echo the input value. Custom messages
remain application-controlled. See [Validation Results](/validation-results)
for the collection policy, formatting helpers, and localization resolver.

## Reproducible recovery and optional output

Sync and async non-throwing validation now produce equivalent recovery containers,
including stripped nested objects when a child fails. Primitive type-failure
recovery uses a fixed mock seed. Absent optional fields remain absent even when
nullable; present null is still validated normally. Unchanged invalid containers
can share input identity just as unchanged valid containers do.

`mockSeeded` is the new bounded generation contract; legacy `mock` remains best
effort. See [Seeded Mocking](/seeded-mocking) for supported schemas and limits.

## Presence, defaults and PATCH

Nullable fields are now required unless listed in `optionals()` or supplied by a
default. Explicit null remains in the parsed map for nullable fields without a
non-null default. Defaults apply to both absent and null input and undergo normal
validation; invalid supplied input remains a failure.

`partial()` now preserves omission and original nullability, and keeps the
unknown-key policy. It no longer inserts null or enables passthrough. `patch()`
is an alias; omitted fields do not receive defaults in either API. Supplied null
still uses the field default when present. Deep partial recurses through directly
nested object schemas only. Object rules remain attached.

Use `unknownKeys(AcanthisUnknownKeys.reject)` for strict objects, `strip` for
accepted-but-removed extras, or `preserve` for retained extras. Typed
`passthrough(type: ...)` is still available.

For explicit contracts use `exportJsonSchema(mode: AcanthisSchemaMode.input)` or
`output` (2020-12), and `exportOpenApiSchema(mode: ...)` for OpenAPI 3.1 Schema
Objects. These APIs currently support structural JSON schemas and reject
unsupported constraints/transforms with a path-bearing exception. Existing
`toJsonSchema()` / `toOpenApiSchema()` remain legacy best-effort APIs.
