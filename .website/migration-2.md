---
description: Update V1 parsing, diagnostics, object schemas, localization, export, and mock adapters.
---

# Migrating to V2

This guide covers breaking API and behavior changes. Start with return types, then update your schema and UI adapters.

## SDK requirement

V2 requires Dart 3.13 or later and a compatible Flutter SDK.

## Parsing return types

| Previous usage | V2 usage |
| --- | --- |
| `schema.parse(input).value` | `schema.parse(input)` |
| `(await schema.parseAsync(input)).value` | `await schema.parseAsync(input)` |
| `result.success` | `result.isValid` |
| `result.errors` | `result.issues.formatFields()` for messages |
| `result.metadata` | `schema.metadataEntry` |
| `AcanthisType<T>` as a schema base | `Schema<Input, Output>` |
| `AcanthisMap` | `ObjectSchema` or `RecordSchema<K, V>` |
| `withTransformation(...)` | `withTransform(...)` |

`tryParse()` returns `AcanthisOutcome<T>` and collects ordered diagnostics.
Read `value` on success, or check `AcanthisInvalid.hasValue` before reading typed
recovery. Missing recovery throws `StateError`; no mock value is fabricated.

`validate()` returns `bool`, and `validateAsync()` returns `Future<bool>`.
Flutter's `FormField.validator` requires `String?`: adapt `tryParse()` to return
null on success and `issues.first.message` on failure. See the
[validator adapter](/basic-usage#check-validity).

## Parsed values can share input identity

Unchanged typed maps and lists can be returned directly. Mutating the result can
affect the input; read-only input can produce read-only output. Use `Map.of` or
`List.of` for an independent outer container. Changed ancestors are copied when
defaults, coercion, transformations or stripping change a child.

## Presence, defaults and PATCH

Fields are required even when nullable, unless listed in `optionals()` or supplied
by a default. Explicit null is validated normally. Defaults replace missing/null
input and are themselves validated; supplied invalid values remain invalid.
`partial()` / `patch()` preserve omission and suppress defaults on absent fields.
`deep: true` recurses through direct object children. Unknown-key policies and
typed passthrough are retained. See [presence and defaults](/presence-and-defaults).

## Diagnostic paths and legacy errors

Paths contain data locations only; the check code is separate. List indices are
integers. `issues.formatFields()` preserves duplicate messages at a location;
`formatTree()` also distinguishes field names from integer indices.
`issues.toTransport()` is the versioned, locale-independent protocol.
The lossy legacy errors map is removed.

## Message catalogs and custom checks

Replace built-in `message:` / `messageBuilder:` arguments and resolver callbacks
with immutable `AcanthisMessageCatalog` entries. Presentation methods accept
`catalog:`. String-length parameters retain V1's `value` key.
`refine()` accepts a synchronous predicate and optional fallback text;
`refineAsync()` takes an `AsyncCheck<T>` such as `CallbackAsyncCheck`.
Use `withCheck(PredicateCheck<T>(..., parameters: ...))` for parameterized custom
checks. Programming exceptions propagate instead of becoming failed checks.

`AcanthisLocaleConfig.forLocale(locale, overrides: ...)` and
`AcanthisMessageCatalogs.forLocale(locale, overrides: ...)` accept catalogs keyed
by locale. Exact regional overrides fall back to base-language overrides, then
bundled English/Italian translations. Resolver callbacks from V1 become catalog
entries in V2. See [localization](/error-customization#localize-at-presentation-time).

## Async and live validation

Async schemas require async parsing methods; synchronous use throws `StateError`.
Synchronous schemas use the same behavior through async entry points.
`watch()` and `watchAsync()` provide live edits, revisions, deltas and cancellation.
See [live validation](/live-validation).

## Export and mocks

All JSON/OpenAPI export helpers now use the strict audited exporter. Unsupported
behavior throws rather than silently omitting constraints. Input/output modes
select accepted JSON input or successful JSON output. OpenAPI export requires
an explicit mode and emits a 3.1 Schema Object. See [export compatibility](/export-compatibility).

`mock()` and `mock(seed)` use the same bounded generator as `mockSeeded()`.
Returned values are validated; unsupported schemas or exhausted budgets throw
`AcanthisMockException`. Class pipelines validate mapped output and use bounded
retries. See [seeded mocking](/seeded-mocking) for the supported subset.
