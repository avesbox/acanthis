# Data-only issue paths and legacy compatibility

Decision date: 2026-09-12. Accepted for the current 2.0 working tree.

`AcanthisIssue` is the native diagnostic representation. Its path identifies
data, never the check that failed. `['account', 'email']` plus code `email`
replaces the unreleased draft path `['account', 'email', 'email']`.
Published 1.x did not expose that draft structured API. Keep the legacy
`AcanthisParseResult.errors` surface for callers and custom schemas.

## Contract

- Paths contain only strings (object keys) and integers (collection indices).
  An empty path denotes the root. Numeric string keys remain strings. Empty
  keys, dots, slashes, and tildes are literal keys, not a query language.
- Codes identify checks independently of paths and display messages.
  Repeated failures with the same path/code are distinct ordered issues.
- Parameters contain constraint metadata, not raw validated inputs or caught
  exceptions. Custom messages are application-controlled and may disclose data;
  freezing metadata does not automatically redact user-provided strings.
- Paths, parameters, and union branches are defensive immutable snapshots.
  Union branch paths are absolute from the root; prefixing a child prefixes
  its nested branches as well.
- JSON arrays and the typed issue tree preserve integer/string distinctions.
  JSON Pointer is a presentation/transport address: `/0` alone cannot recover
  whether the container was an array or an object. Do not round-trip typed paths
  through a pointer or dot string.
- Diagnostics describe validation failure. Recovery values on failed results
  are not successful validated output.

## Existing prototype and compatibility bridge

The current working tree already implements the prototype in
[`results.dart`](../../lib/src/results.dart) and
[`issue_sink.dart`](../../lib/src/issue_sink.dart). Keep and validate it rather
than introduce a second issue model.

Built-in validators emit directly into an ordered `IssueSink`. Its Map
interface preserves the `tryParseInternal(..., errors: ...)` extension point.
Legacy writes such as `errors['email'] = 'Invalid email'` become native root
issues at write time; attaching a child prefixes its data path.
`AcanthisParseResult(issues: ...)` also accepts native diagnostics directly.

The legacy projection nests maps using stringified path keys and places
`code: message` at the leaf. It is intentionally lossy: duplicate codes use
the final message, integer indices become strings, parent-code/child-key
collisions overwrite according to issue order, and parameters/branch detail
are absent. Reading a legacy map cannot restore these facts.

`issuesFromLegacyErrors` treats nested map keys as data paths and leaf keys as
codes. It does not guess whether a numeric string was an array index. Existing
custom schemas that rely on overwriting or mutating a map obtained through
`errors[key]` must migrate to explicit emission: the sink accumulates issues
and map reads are projections, not mutable references into the native store.

## Migration and verification

Adapters written against the 2.0 draft must stop removing the last path segment.
New integrations consume `result.issues`; old error renderers can keep using
`result.errors`. Do not silently change the historical map into a new schema.
See [the migration guide](../../.website/migration-2.md).

[`structured_issues_test.dart`](../../test/structured_issues_test.dart) covers
duplicate checks, parent/child collisions, escaped keys, integer indices,
immutable metadata, union branches, sync/async composition, live sessions,
and native-to-legacy conversion. The additional
[`issue_compatibility_test.dart`](../../test/issue_compatibility_test.dart)
exercises legacy map writes and irreversible index conversion directly.
