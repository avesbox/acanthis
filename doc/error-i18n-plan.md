# Error internationalization plan

Status: proposal, 2026-09-17. This document plans future work; the APIs below
are not yet available unless explicitly described as existing.

## Existing foundation

`AcanthisIssue` already separates `code`, `parameters`, `path`, `message`, and
union `branches`. `AcanthisMessageResolver` receives a code and parameters and
returns a nullable string. `formatMessage`, `formatFields`, `formatTree`, and
`formatJson` accept this resolver; null falls back to the original message.
Applications can supply translated schema messages today or resolve issues
after `tryParse`. No locale catalog or global locale is currently provided.

`validate(input)` returns the first throwing-parser message as `String?`.
`ValidationError` currently carries only a message and key, so this route loses
the constraint parameters needed for reliable translation. Do not translate by
matching English text or assume `tryParse` has identical execution behavior:
it collects failures, whereas `validate` stops at the first failure.

## Proposed contract

Keep localization at presentation time and reuse `AcanthisMessageResolver`.
Keep the core independent of Flutter and `intl`. Applications select a resolver
per request or widget; avoid mutable process-wide locale state. One immutable
result must remain renderable in several languages without rerunning checks.

Proposed field API:

```dart
// Proposed, not implemented.
String? validate(dynamic value, {AcanthisMessageResolver? resolver});
// The same for tryParse, and async variants. Typed outcomes are returned by tryParse and tryParseAsync.
```

An omitted resolver preserves current messages and fail-fast behavior. A
provided resolver overrides the fallback, including an explicit schema message;
returning null preserves that message. This matches existing issue formatting.
An empty resolved string remains a string, never a success signal. Unknown
codes, missing parameters, and unsupported locales must fall back without
changing whether validation succeeds. Resolver exceptions should propagate as
application errors, consistently with existing formatters.

Preserve input handling, default validation, transformation ordering, async
rejection, and non-validation exception behavior. Keep `validateAsync` consistent with `validate`: it returns `Future<String?>`.
Typed outcomes are returned by `tryParse` and `tryParseAsync`.

## Delivery steps

1. Audit built-in codes and parameter shapes across scalar, presence, object,
   dependency, collection, union, and coercion failures. Publish a versioned
   catalog with each code's required parameters and English fallback. Reuse
   current names such as `minLength` / `value`; do not silently rename them.
   Document namespaced application codes and avoid inserting raw input values.
2. Preserve structured diagnostic metadata in the throwing path. Add an
   optional issue to `ValidationError` while retaining its existing constructor,
   `message`, and `key` compatibility. Populate it in both the compiled
   single-check path and composed operations, then propagate child paths and
   union details. Legacy user-thrown errors without metadata retain their
   messages. Ensure native diagnostics agree with the existing non-throwing
   path for equivalent failures, without running additional checks.
3. Add the optional resolver to `validate` and resolve the captured first
   issue once. Do not replace fail-fast parsing with `tryParse`, which could
   execute later callbacks and alter side effects. Continue returning null on
   success without calling the resolver.
4. Supply opt-in English and Italian catalogs as an initial deliverable, with
   explicit locale lookup and fallback order: exact locale, base language,
   then the schema's fallback message. Keep pluralization and date/number
   formatting behind resolver implementations; applications can adapt their
   own generated localization methods. Catalog helpers must return null for
   unsupported codes or malformed parameters.
5. Document a Flutter resolver closure using the current widget locale, plus
   server request-scoped usage. Revalidate displayed fields when the locale
   changes; existing issue lists can be reformatted directly. Include nested
   errors, custom codes, fallback behavior, and a migration example.

## Acceptance tests

- Every supported catalog code has parameter and translation fixtures;
  interpolation, singular/plural boundaries, Unicode, region fallback, and
  missing translations behave deterministically.
- Default and explicit schema messages remain unchanged without a resolver;
  resolver-null falls back, resolver text overrides, and empty text stays invalid.
- Localized `validate` stops after the first failure, runs transformations once,
  rejects async schemas, and does not hide non-validation exceptions.
- Paths, codes, parameters, duplicate ordering, union branches, and legacy
  error maps remain unchanged when formatting in different languages.
- Sync/async parsing and live-session issues can share the same catalogs;
  concurrent requests and successive Flutter locale changes cannot leak locale.
- Existing validation tests and analysis pass. Compare the unlocalized fast
  path with the existing benchmark baseline before accepting metadata changes.

## Scope and decisions

The first release targets resolver integration and two opt-in catalogs. Further
languages require translation review and the same coverage contract. Field
labels and application-specific wording belong in application resolvers for
now; a path-aware resolver can be considered separately without breaking the
existing two-argument typedef. Translation must never change validation rules,
schema exports, or the stored fallback message.

## Global locale and catalog

Add an optional process-wide default for applications that want one locale
without passing a resolver through every call. This is a presentation default,
not schema state and not part of validation semantics.

Proposed API:

```dart
// Proposed, not implemented.
class AcanthisI18n {
  static AcanthisLocaleConfig get defaults;
  static void configure(AcanthisLocaleConfig config);
  static T runWith<AcanthisLocaleConfig, T>(
    AcanthisLocaleConfig config,
    T Function() action,
  );
}

class AcanthisLocaleConfig {
  const AcanthisLocaleConfig({required this.locale, this.resolver});
  final String locale;
  final AcanthisMessageResolver? resolver;
}
```

The lookup precedence should be explicit: a resolver passed to a method wins,
then a resolver supplied by `runWith`, then the configured global default, then
the issue's stored fallback message. `configure` should replace an immutable
configuration atomically and return the previous configuration (or expose a
reset method) so tests and applications can restore state. Calling `configure`
with a null resolver keeps the stored schema messages.

The global setting must not alter `code`, `parameters`, issue ordering,
validation success, or schema exports. It should apply only when formatting
messages or when `validate`/`validateAsync` converts its first captured issue to
text. Results must retain their fallback message and remain renderable in other
locales after the global setting changes.

Global mutable state is convenient for a single-locale Flutter application but
is unsafe as request state on a concurrent server. Therefore the implementation
must document `configure` as application startup configuration, provide
request-scoped `runWith` (or an equivalent explicit context) for server work,
and avoid storing a mutable locale on schemas. If Dart isolates are used, each
isolate has its own defaults and must be configured independently. Nested
`runWith` calls restore the prior context in a `finally` block, including when
the action throws. Async propagation across awaited work must be verified; if
the runtime cannot guarantee it, use an explicit resolver/context parameter
instead of pretending the global is request-local.

Flutter integrations should read `Localizations.localeOf(context)` and prefer
an explicit resolver or `runWith` around a form rebuild. A locale change must
reformat existing issues without rerunning validation. Document that a global
default is suitable for app-wide language changes, while per-widget resolvers
are required for screens displaying different locales simultaneously.

Global configuration should be introduced only after the explicit resolver API
is stable. Add concurrency, nested-scope, isolate, reset, and locale-change
tests before making it public; benchmark the no-resolver path to ensure the
default lookup does not add meaningful overhead.
