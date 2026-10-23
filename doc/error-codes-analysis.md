# Error Codes: analysis and effort

Audit date: 2026-09-29. Baseline: `e69479d584a48b1bc3eebc146951f46a28f2bf6f`,
package 2.0.0, Dart 3.13.3 on Windows x64. Covers the corresponding investigation under
[Further Analysis](../ROADMAP.md#further-analysis). Recommendations are proposed
decisions at that baseline. Current implementation status is recorded immediately below.

See the separate [Branding analysis](branding-analysis.md) for nominal validated
types and their interaction with diagnostics.

## Findings that change the plan

### Implementation status verified on 2026-10-13

E1–E5 are implemented. E6's examples, performance measurements, and local
integration checks are implemented and executed; unmodified published Serinus
verification remains blocked by its Dart 3.13 compilation error. The tested
integration uses the explicit local compatibility patch described below.

The maintained API and migration contract is [error-codes.md](error-codes.md).
The current release selection is 2.1.0; its changelog explicitly labels the
observable diagnostic changes as breaking. The historical analysis and original
estimates below describe the pre-implementation baseline, not current gaps or a
new estimate of remaining work.

| Package | Implemented deliverable and evidence |
| --- | --- |
| E1 | Public `AcanthisIssueCodes` constants; complete vocabulary/parameter table, namespace, ordering, fallback, compatibility and migration contract. |
| E2 | Enum issues retain old metadata and expose transformed accepted names; catalogs support both forms and hex colors; corrected everyOf fallback; producer and malformed/interpolation fixtures. |
| E3 | Structured base catches, complete instance child validation with field paths/parameters/branches, normalized input conversion failures, sync/async/default/fail-fast regression fixtures. |
| E4 | Version-1 recursive `toTransport` envelope, typed paths, no messages, JSON round trips, immutable metadata with cycle/depth/size/node limits. Existing `toJson` remains message-bearing. |
| E5 | Explicit/scoped/default precedence, null/empty resolver behavior, nested restoration, concurrent awaits, resolver exceptions, isolate defaults, and locale-change verification. |
| E6 | Real Flutter locale-switching widget; Serinus HTTP 422 response checked by a Node consumer; localized/unlocalized JIT/AOT measurements and historical rules/live comparison. Serinus 2.1.12 only compiles here with the retained integration-only workaround; upstream verification is not claimed. |

Verification on 2026-10-13: **583 package tests passed**, **5 server/Standard
Schema integration tests passed**, and **1 Flutter widget test passed**. Package,
integration, Flutter, and diagnostic-benchmark analyzers are clean. The website
build and registry static-rejection/Windows AOT checks also passed. JIT/AOT
measurements are retained. See [integration reproduction commands](../integration/README.md)
and [performance measurements](../benchmark/error-contract/README.md). The two
Standard Schema packages are separately examined in [their comparison](standard-schema-analysis.md).

### Historical findings (2026-09-29)

1. Machine-readable issues and presentation-time localization already exist.
   The remaining work is consistency, a published compatibility contract, and
   verification, rather than a new diagnostic architecture.
2. The [i18n plan](error-i18n-plan.md) and roadmap description of i18n as wholly
   proposed are stale. Catalogs, global defaults, zone scopes, structured
   `ValidationError.issue`, and resolver-aware `validate` are implemented.
3. Diagnostic coverage is not universal: instance fields encode their field name
   in the code and lose parameters; some throwing type failures are `TypeError`.

## Historical evidence and reproducibility

Executed against this baseline:

| Check | Result |
| --- | --- |
| `dart run test --reporter expanded` | 463 tests passed |
| `dart analyze --fatal-infos` | No issues, including the added probe |
| `dart run tool/further_analysis_probe.dart` | Observations recorded below |
| `dart compile exe tool/further_analysis_probe.dart -o .dart_tool/further_analysis_probe.exe`, then run that executable | Successful Windows AOT build; output identical to JIT |

The retained [probe](../tool/further_analysis_probe.dart) now targets V2; the results
below describe the original V1 baseline. It prints both successful
observations and caught failures; a zero exit status alone is not its assertion
of correctness. Existing [structured issue tests](../test/structured_issues_test.dart)
cover duplicate ordering, escaped paths, union branches, async parity, custom
metadata, and live issues. The full suite does not establish complete catalog
coverage: only formatter-resolver tests were found, not dedicated bundled
catalog or locale-scope regression tests.

This audit did not execute Flutter, Serinus, Freezed, json_serializable, database
drivers, or HTTP-client integration projects. Their integration status is
explicitly unverified below. AOT verification is Windows Dart, not every Flutter
target. No throughput or allocation benchmark was performed.

## Error model and presentation

[AcanthisIssue](../lib/src/results.dart) requires `path`, `code`, and `message`.
It also contains `parameters` and ordered `branches`. Paths accept strings and
integers, and are immutable. Nested containers prefix paths; union branch paths
are absolute from the validation root. `jsonPointer` derives RFC 6901 escaping
from the same path: `['a/b~', 0]` becomes `/a~1b~0/0`. Keep the segment array on
the wire: a pointer alone cannot distinguish string key `'0'` from index `0`.

[Checks](../lib/src/operations/checks.dart) expose string `name`, `code`, `error`,
and `parameters`; `code` defaults to `name`, or `custom` if empty. Built-ins have
named check classes, not a public enum of diagnostic codes. There is no enforced
custom-code registry. Native issues retain duplicate failures; the legacy error
map remains a lossy projection and should not be the transport source.

[ValidationError](../lib/src/exceptions/validation_error.dart) now has optional
`issue`, a diagnostic constructor, and prefixing. `validate`/`validateAsync`
resolve its first issue without switching to collecting validation.
`tryParse` returns typed outcomes and does **not** accept a resolver parameter.

| Override location | Current behavior |
| --- | --- |
| Individual validator | `message`, and on parameterized checks often `messageBuilder`; builder takes precedence over message |
| Custom refinement | `error`, `name`, and optional `parameters`; cause-based checks can return text |
| Whole schema | No generic schema-wide message/resolver setting; metadata is not an error map |
| Per call | Resolver on `validate`/`validateAsync` and issue formatters; not on `parse`/`tryParse` |
| Scoped/global | `AcanthisI18n.runWith` uses a Zone; `configure` sets isolate-local defaults and returns previous configuration |

Resolution precedence is explicit method resolver, then the current zone's
resolver or isolate default, then the stored message. If an explicit resolver
returns null it falls straight back to the message, not to the scoped resolver.
A zone configuration with a null resolver likewise preserves the message.
Catalog lookup separately tries exact override, base-language override, then
bundled English/Italian. Tags normalize case and `_`/`-`. Unknown codes or
unsupported locales fall back. The probe verified concurrent English and Italian
scopes across an await. The catalog uses interpolation; it is not a general
pluralization or localized date/number formatting engine. Resolver exceptions
are application exceptions, not validation failures.

## Complete built-in failure inventory

This inventory covers check implementations in [validators](../lib/src/validators)
and structural emitters in [types](../lib/src/types). Codes below are the **actual
strings**, not the roadmap's illustrative `string.min`/`number.min` names.
Parameters are schema constraints, not the submitted value. `{}` means none.
Grouped rows enumerate each emitted code explicitly. Custom callbacks and
instance-field names make the overall possible code vocabulary open-ended.

| Family / codes | Failure condition and parameters |
| --- | --- |
| String `minLength`, `maxLength`, `exactLength` | UTF-16 length below, above, or unequal to bound; `{value}` |
| String `email` | `EmailValidator.validate` false; `{}` |
| String `uri` | `Uri.tryParse` returns null; relative URIs may pass; `{}` |
| String `url` | Empty, unparsable, no scheme, or empty host; `{}` |
| String `uncompromised` | Password hash suffix found in remote range response; `{}`; asynchronous, network failures can throw |
| String `letters`, `digits`, `alphanumeric`, `alphanumericWithSpaces`, `specialCharacters`, `allCharacters` | Respective regex does not match; `{strict}` selects pattern behavior |
| String `cuid`, `cuid2`, `ulid`, `uuid`, `nanoid`, `jwt`, `base64`, `time` | Respective built-in regex does not match; `{}`; these are pattern checks, not semantic/security verification |
| String `hexColor` | Not seven characters starting with `#` followed by hex digits; `{}` |
| String `enumerated` (enum API) | No enum name, optionally transformed by `nameTransformer`, matches; `{enumValues}` freezes enum names, not transformed accepted names |
| String `enumerated` (contained API) | Not a member of supplied strings; `{values}` |
| String `required`, `notEmpty` | Empty string; `{}`; distinct operations with equivalent predicates |
| String `contains`, `startsWith`, `endsWith` | Missing substring, prefix, suffix respectively; `{value}` |
| String `card` | After removing non-digits, length outside 13–19 or Luhn failure; `{}` |
| String `upperCase`, `lowerCase`, `mixedCase` | Not equal to uppercase/lowercase form, or equal to either form for mixed-case check; `{}` |
| String `dateTime` | `DateTime.tryParse` null; `{}` |
| String `pattern` | Pattern does not match; `{regExp}`; regex stored as its pattern text |
| Number `lte`, `gte`, `gt`, `lt` | Fails corresponding comparison; `{value}` |
| Number `between` | Outside inclusive bounds; `{min, max}` |
| Number `positive`, `negative`, `nonpositive`, `nonnegative` | Fails `> 0`, `< 0`, `<= 0`, `>= 0` respectively; `{}` |
| Number `multipleOf` | Remainder is nonzero; `{value}` |
| Number `integer`, `double` | `integer` requires Dart `int`; `double` rejects `int`; `{}`; representation checks, not JSON mathematical-integer semantics |
| Number `finite`, `infinite`, `nan`, `notNaN` | Fails corresponding numeric predicate; `{}` |
| Number `enumerated` | Not in allowed numeric values; `{values}` |
| Boolean `isTrue`, `isFalse` | Opposite boolean; `{}` |
| Common `exact` | Dart equality with constraint fails; `{value}` |
| List `minItems`, `maxItems`, `length` | Below minimum, above maximum, or unequal length; `{minItems}`, `{maxItems}`, `{length}` respectively |
| List `uniqueItems` | `toSet()` reduces length; Dart equality; `{}` |
| List `contains` | Missing item; `{item}` |
| List `anyOf` | No input element belongs to allowed list; `{items}` |
| List `everyOf` | Some input element is outside allowed list; `{items}`; does not require every allowed item to occur, despite its fallback wording |
| Map `minProperties`, `maxProperties`, `lengthProperties` | Wrong property count; `{constraintValue}` |
| Date `min`, `max` | Earlier/later than inclusive bound; `{value}` as ISO string |
| Date `differsFromNow`, `differsFrom` | Absolute time difference less than threshold; `{difference}` in microseconds, plus `{fromDate}` ISO string for explicit origin |
| Nullable `enumerated` | Non-null value outside allowed list; `{values}`; null passes |
| Structural `type` | Wrong runtime input type or failed scalar coercion; usually `{}`, no uniform `expected`/`received` fields |
| Structural `date` | Date input cannot be converted/parsed; `{}` |
| Structural `required` | Missing required map field; `{}` and field path; collection may additionally emit that field's check codes without running their predicates |
| Structural `unknownKey` | Extra key in strict object; `{}` and extra-key path |
| Structural `passthrough` | Extra value cannot satisfy map value type; `{}` and extra-key path |
| Structural `dependency` | Pairwise dependency fails or an input is unavailable; `{dependsOn}` and dependent path |
| Structural `literal` | Value unequal to literal; `{expected}`; wrong type can produce `type` first |
| Structural `templateLiteral` | Template regex mismatch; `{pattern}`; wrong input type produces `type` |
| Structural `tuple` | Fixed tuple length mismatch; `{length}`; children retain index paths |
| Structural `union` | No branch succeeds; `{}`, with ordered branch issues |
| Structural `variantGuard` | Guard did not select the variant; `{name}`, recorded in union branch diagnostics |
| Structural `transform` | Pipeline converter throws; `{}`; throwing fallback can include exception text |
| Instance fields `<field>.<check-name>` | `InstanceType.field` wraps each operation in a custom check; root path and empty parameters rather than field path and original metadata |
| Custom `custom` or supplied name/code | Empty check name uses `custom`; refinements use supplied names and parameters; selected-field rules return caller-created issues with declared output paths |

Wrong input and callback exceptions are not all normalized into this table:
`string().list().parse(42)` throws `TypeError`, while `tryParse(42)` produces
`type`. Legacy custom checks catch callback exceptions as failure; selected-field
rule application errors can propagate. Legacy user `ValidationError` may have
no issue. Arbitrary transforms, pattern constructors, and external network calls
may throw ordinary exceptions. Do not promise every thrown error is serializable
as `AcanthisIssue` without further normalization work.

## Consistency gaps and transport

The probe reproduced `InstanceType.field('email', ..., string().min(3))` as
`{path: [], code: 'email.minLength', parameters: {}}`. This is a real exception
to the otherwise data-only path model. The implementation copies child
operations, not the complete child schema: nested container validation is not
automatically equivalent to object parsing. Separately, base `tryParseInternal`
catches a `ValidationError` and reconstructs an issue from key/message, losing
its supplied `issue` metadata. This matters to custom schema subclasses.

The enum string issue contains `enumValues`, but the catalog's `enumerated`
handler expects `values`. Italian resolution returned null in the probe. A fix
must account for `nameTransformer`, not merely rename the map key. Stabilizing
parameter shapes needs tests for every producer of shared codes such as
`enumerated`, `contains`, and `required`.

`freezeIssueParameter` recursively copies lists and string-key maps. DateTime
becomes ISO text, Duration microseconds, enums their name, RegExp its pattern,
nonfinite doubles strings, and unknown objects a `<runtimeType>` placeholder.
The probe's Uri became `<_SimpleUri>`, not its URI text. Unknown-object labels
are not stable identifiers or reversible serialization. Cyclic custom containers
have no cycle guard. Ordinary JSON round trips work; there is no public
`AcanthisIssue.fromJson` and arbitrary Dart values cannot round-trip losslessly.

`toJson` emits `parameters` (not `params`), a resolved `message`, and optional
branches. Thus the entire current JSON object is locale-sensitive. For Serinus
or JS clients, recommend a separate recursive transport projection containing
only `code`, segment `path`, `parameters`, and `branches`, with a versioned
envelope. Keep existing `toJson` unchanged for compatibility. Avoid raw input in
parameters and omit custom messages when they may contain submitted data or
exception text. Do not log `outcome.value` as diagnostic metadata.

Flutter can select a resolver from the widget locale and reformat existing
issues; `formatFields` already groups by pointer. A path-aware application
adapter can supply field labels because the current resolver receives only
code/parameters. [Flutter's locale API](https://api.flutter.dev/flutter/widgets/Localizations/localeOf.html)
supports widget-scoped locale selection. JS clients can resolve the same code
payload independently. Analytics should aggregate stable codes and avoid
unbounded array indices/field names as metric labels. These are adapter designs,
not tested framework integrations.

## Recommended error contract

Keep public **string codes plus optional typed Dart constants**. Strings support
transport and custom namespaces; an enum or closed sealed hierarchy would make
application codes awkward. Constants catch typos without closing the vocabulary.
Reserve current built-in identifiers and a documented namespace for future
built-ins; recommend `app.*` or organization prefixes such as `acme.*` for custom
codes. Registration is unnecessary for validation; optional catalog registration
must be scoped and immutable. Collision prevention is currently a convention.

Treat code meaning, parameter meaning/types/units, paths, branch ordering, and
duplicate preservation as public compatibility commitments. Renaming existing
codes or replacing them with `too_small`/`string.min` is breaking. Keep current
validator-oriented codes; a new semantic taxonomy would need explicit versioned
translation. Exact English wording is a fallback, not a machine protocol.

Retain required non-null `message` as fallback for now. Semantics are already
separate from presentation. A future additive code-only factory could derive a
fallback; changing `message` to nullable would break consumers, formatters,
equality/hash behavior, legacy errors, and live issue comparisons. Preserve
existing per-check overrides, with explicit resolver text winning as it does now.
Prefer explicit or zone-scoped locale selection; keep global configuration for
startup defaults, never per-request mutation. More complete pluralization belongs
in application resolvers or an optional catalog package.

## Remaining effort

These are planning estimates, not measured implementation times or commitments.
One person-day means one experienced Dart maintainer's focused implementation,
review preparation, tests, and documentation time; scheduling and external review
latency are excluded. Ranges account for engine paths and compatibility questions.

### Work packages

| Work package | Deliverable / acceptance | Person-days | Confidence |
| --- | --- | --- | --- |
| E1. Public code contract | Publish existing vocabulary and parameter schemas; typed string constants; namespace, ordering, compatibility and fallback rules; update stale i18n status | 1–2 | High |
| E2. Catalog correctness | Cover all built-in producers, fix enumValues/values mismatch including name transformation, clarify everyOf wording, malformed-parameter and interpolation fixtures | 2–4 | Medium |
| E3. Diagnostic parity | Preserve metadata through base catches; replace instance field-in-code diagnostics with declared paths; define throwing TypeError normalization; check sync/async/default/fail-fast paths | 4–7 | Medium-low |
| E4. Locale-independent transport | Additive recursive transport serializer with versioned envelope/example; string/int path preservation, union branches, JSON round trips, bounded handling of cyclic/unsupported custom metadata | 2–3 | Medium |
| E5. Scoped presentation verification | Explicit/zone/global precedence; concurrent async scopes, nested restoration, exceptions, isolate defaults, locale changes, custom messages and resolver-null behavior | 2–3 | Medium |
| E6. Integration examples and release validation | Minimal Flutter field and Serinus/JS payload examples; same codes and pointers; rerun suite/analysis and compare localized/unlocalized JIT/AOT performance with existing baselines | 2–4 | Medium-low |
| **Complete error-contract track** | E1–E6 | **13–23** | Assumes no generic engine rewrite |

The initial E1+E2 deliverable is 3–6 days and can land before the broader parity
work. E3 is the critical risk: InstanceType currently wraps child operations, so
fixing it is more than changing a formatted string. Preserve validation order and
avoid accidentally executing child transforms or nested checks twice. Add fixtures
before choosing whether to change legacy behavior or introduce an opt-in path.

E4 is transport normalization, not reconstruction of arbitrary Dart objects.
Use already frozen constraints; do not serialize runtime type placeholders as
domain identities. Keep existing `toJson` and its message semantics intact.
Never silently change the wire field `parameters` to `params`.

## Dependencies and delivery order

1. Agree E1's existing-code stability contract and retain mandatory fallback
   messages. Land E2 before advertising complete catalog support.
2. Execute E3 and E5 using current native issue machinery. E4 can build on the
   model, but its final contract depends on E3's instance-field decision.
3. Validate E6 in real pinned integrations before claiming framework support.

The complete error-contract track is **13–23 person-days**. Native issues,
locale catalogs, fail-fast resolvers, and zone scopes already exist; the work
above addresses their remaining gaps. Re-estimate after E3, the highest-uncertainty
implementation boundary. New languages or advanced plural/date formatting are
outside this total and must be estimated per locale/package, including translation
review. Broad schema export and driver-specific integrations are excluded.

## Compatibility and migration

| Change | Recommended release treatment |
| --- | --- |
| Constants, docs, opt-in transport projection | Additive 2.x work |
| Catalog fix supporting existing enum parameters | Bug fix, preserving stored messages and code strings; document corrected rendered text |
| Rename codes, change parameter units/types, remove fallback message, change toJson fields | Breaking; explicit major version or separately versioned opt-in protocol |
| Correct instance paths/codes or normalize thrown exception classes | Observable change; decide against unreleased 2.0 status and published compatibility guarantees, otherwise opt-in transition or next major |

APIs requiring review include AcanthisIssue construction, equality/hash, formatters
and toJson; ValidationError constructors and catch sites; AcanthisCheck/custom
refinements; InstanceType.field; AcanthisType parse/validate hooks; pipeline error
propagation; and issue-based live deltas. A fallback-message removal would ripple
through these without solving the currently observed gaps.

If a new taxonomy is eventually adopted, retain old codes internally during a
transition and expose an explicitly versioned adapter. Unknown application codes
must pass through unchanged. Do not silently rebrand `email` as `string.email`.
For a failed UserId UUID check, retain `uuid` with its ordinary path; optional
brand metadata may enrich tooling. A domain rule such as account availability
can use a separate application code.

## Acceptance gates before claiming completion

Error-contract tests must be table-driven across every inventory row and every
producer of a shared code, asserting parameter names, types and units as well as
messages. Cover deterministic duplicate/branch order, escaped nested paths,
throwing versus collecting modes, coercion/defaults, custom checks and legacy
errors, transformations, genuinely async callbacks, and live revision changes.
Missing-field synthesized check issues must be distinguished from predicates
that actually ran. Catalog fixtures need unknown/malformed data, interpolation
boundaries, explicit-message overrides, empty resolver strings, and concurrent
locale isolation. Transport fixtures need recursive branches, JSON encoding,
custom values, cycles, and absence of raw input. Keep existing resolver exceptions
visible and fail-fast execution genuinely fail-fast.

The completed analysis supplies a passing baseline and reproducible observations.
It does not mark these implementation gates as passed or change production APIs.

