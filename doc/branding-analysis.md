# Branding: analysis and effort

Audit date: 2026-09-29. Baseline: `e69479d584a48b1bc3eebc146951f46a28f2bf6f`,
package 2.0.0, Dart 3.13.3 on Windows x64. Covers the corresponding investigation under
[Further Analysis](../ROADMAP.md#further-analysis). Recommendations are proposed
decisions, not newly implemented APIs. Findings and remaining effort are included below.

See the separate [Error Codes analysis](error-codes-analysis.md) for the diagnostic
inventory, localization, and transport contract.

## Findings that change the plan

1. Branding through extension types is feasible as a static convention. It is
   not proof that validation ran, and it has no distinct runtime identity.
2. The suggested `transform(Email.new)` does not compile. Current `transform`
   preserves its type. `pipe` changes types but introduces nullable output and
   has composition/export limitations. A thin `.brand()` alias would inherit them.

## Evidence and reproducibility

Executed against this baseline:

| Check | Result |
| --- | --- |
| `dart run test --reporter expanded` | 463 tests passed |
| `dart analyze --fatal-infos` | No issues, including the added probe |
| `dart run tool/further_analysis_probe.dart` | Observations recorded below |
| `dart compile exe tool/further_analysis_probe.dart -o .dart_tool/further_analysis_probe.exe`, then run that executable | Successful Windows AOT build; output identical to JIT |
| Analyzer against an isolated negative fixture | Rejected raw `String` assignment to `Email`, `transform(Email.new)`, and assigning pipeline `List<Email?>` to `List<Email>` |

The retained [probe](../tool/further_analysis_probe.dart) prints both successful
observations and caught failures; a zero exit status alone is not its assertion
of correctness. It is shared with the Error Codes investigation.

This audit did not execute Flutter, Serinus, Freezed, json_serializable, database
drivers, or HTTP-client integration projects. Their integration status is
explicitly unverified below. AOT verification is Windows Dart, not every Flutter
target. No throughput or allocation benchmark was performed.

## Actual generic architecture

[AcanthisType](../lib/src/types/types.dart) has one type parameter `O`, not
`<I, O>`; parse entry points accept `dynamic`. Coercion occurs through schema
input hooks before operations; there is no generic public preprocessor abstraction
with a separately tracked input type. `transform` takes `O Function(O)`.
`AcanthisPipeline<O, T>` validates an input schema, converts, validates an output
schema, and extends `AcanthisType<T?>`. Here `O` describes validated intermediate
input, not necessarily the raw accepted type. ClassSchemaBuilder uses this same
pipeline and is not a codec or reverse serializer.

This works today:

```dart
extension type Email(String value) {}

final email = string().email().pipe<Email>(
  instance<Email>(),
  transform: Email.new,
);
final Email? value = email.parse('a@example.com');
final List<Email?> values = email.list().parse(['a@example.com']);
```

There is `.list()`, not `.array()`. An explicit converter is appropriate: Dart
cannot generically invoke a constructor from `T`. A generic `as T` can accept
erased extension representations but cannot establish validation or safely map
arbitrary wrapper types. Consequently `.brand<T>()` without a converter is not
a sound *validated-value guarantee*. No TypeScript intersection equivalent is
required or available in the current architecture.

[Dart's extension-type documentation](https://dart.dev/language/extension-types)
describes static interfaces erased to their representation without an extra
wrapper object. The following are local probe results, not assumptions about
third-party tooling:

| Property | Verified outcome |
| --- | --- |
| Static distinction | Raw String assignment to Email rejected by analyzer |
| Generic mapping/list | Email output preserved statically, but nullable through pipeline |
| Equality | Equal underlying strings compare equal |
| Runtime identity | Runtime type is String; pipeline runtime type displays String in place of Email |
| Dynamic/casts | `'not an email' as Email` succeeds; `instance<Email>()` accepts an arbitrary string |
| Runtime patterns | Email type test and pattern match arbitrary underlying strings |
| JSON | Branded string and list encode as strings; wrapper class without serializer fails |
| Execution modes | Same observed behavior in JIT and Windows AOT |

An ordinary wrapper class provides a distinct runtime type and can protect
construction using a private constructor/factory, at the cost of a wrapper
object in the language model, explicit serialization, and equality implementation.
Allocation cost was not measured; compiler optimizations may affect it. Extension
types provide API discipline rather than a security boundary, even with hidden
constructors, because casts can bypass their static interface.

## Composition, export, and integration decisions

| Composition case | Current finding |
| --- | --- |
| Nullable | `email.nullable().parse(null)` succeeds |
| Optional | Object `.optionals(['email'])` preserves omission; optionality is a container policy |
| Nested objects | Runtime values are mapped, but object output is `Map<String, dynamic>`; no per-key Email/UserId inference |
| Unions | Explicit `union<Email?>([email])` works; branch order remains relevant, no runtime brand distinction |
| Tuples | Values map, but output remains `List<dynamic>`, not a typed record |
| Records | No dedicated record-schema API; manual pipeline/class mapping is needed and was not separately executed |
| Transform before mapping | Trim then convert works |
| Transform after mapping | `pipeline.transform` calls unimplemented `withTransformation` |
| Additional pipeline methods | `meta`, `withCheck`, `withAsyncCheck`, legacy JSON/OpenAPI export unimplemented |
| Audited export | Pipeline rejected in both-mode architecture; probe verifies input rejection. Even unbranded `uuid()` has no audited JSON contract |

Therefore a brand is more than a converter alias only if it supplies stable
schema-level identity, introspection, and representation-preserving export.
The current operations/metadata model is not a complete stable schema-definition
format. `elementType` is insufficient because extension types erase. If added,
use explicit immutable brand metadata (for example a supplied name), never
`T.toString()` as identity. Normal validation errors should retain the underlying
code (`uuid`, currently), path, and parameters. Brand metadata should be optional;
do not replace every failure with `UserId.invalid`. Reserve application codes for
additional domain predicates. This keeps branding and localization compatible.

A truly representation-preserving brand should leave JSON semantics unchanged.
However, an arbitrary converter may normalize or produce a wrapper: export cannot
assume identity. Require a declared representation contract or codec before
exporting it transparently. Optional `x-acanthis-brand` is reasonable only as
explicit vendor metadata; it must not imply runtime validation. Auditing UUID
export is a separate prerequisite for the roadmap's UUID example. Current
metadata `otherProperties` is nested in legacy output and is not a ready-made
top-level vendor-extension API for audited export.

Direct `jsonEncode` works for the probed string extension representation; this
does not prove that a generated serializer validates it when decoding. Official
[json_serializable documentation](https://pub.dev/packages/json_serializable)
offers custom converters, and [Freezed documents converter integration](https://pub.dev/packages/freezed).
Recommendation: one reusable converter per domain type, with validated decode
and representation encode, referenced on each relevant field/model. Exact
automatic extension-type support must be tested against pinned generator
versions; it is not established here. Statically String-typed database/HTTP APIs
may require `.value` at each boundary; wrapper classes require explicit conversion
as well. Dynamic boundaries cannot recover nominal validation guarantees.

Serinus route parameters could be explicitly parsed into an Email/UserId pipeline
before calling a typed service method; handling nullable pipeline output is
currently required. Automatic injection based on runtime brand type is not a
valid strategy because of erasure. A route-binding example remains an integration
acceptance test, not an existing feature verified by this audit.

**Decision:** document extension types plus explicit pipelines now. Do not ship
`.brand()` as a thin alias. Fix/define typed mapping behavior first; decide
representation and introspection together with codecs before committing to a
dedicated brand schema. A documentation convention is additive in 2.x. A new
schema subclass can also be additive, but changing the base to
`AcanthisType<I, O>` would break every existing schema generic and is unnecessary
for the initial convention. Broad generic redesign belongs in a major-version
proposal with demonstrated use cases.

## Remaining effort

These are planning estimates, not measured implementation times or commitments.
One person-day means one experienced Dart maintainer's focused implementation,
review preparation, tests, and documentation time; scheduling and external review
latency are excluded. Ranges account for engine paths and compatibility questions.

### Implementation alternatives

These are alternatives with shared foundations, not independent totals to add.

| Option | Scope | Person-days | Recommendation |
| --- | --- | --- | --- |
| B1. Convention only | Document actual pipe API and nullable output, extension erasure and bypasses, wrapper comparison; maintain positive/negative analyzer and AOT fixtures | 2–3 | First deliverable |
| B2. Mapping foundations | Define successful-output vs recovery typing; finish mapped-schema checks/transforms/metadata; test defaults, async execution, selected rules/live behavior and container composition | 5–9 additional | Needed before promising seamless branded composition |
| B3. Dedicated brand schema | After B2: converter-based additive schema, explicit identity metadata, transparent representation contract, opt-in export metadata, code/path propagation and docs | 5–9 additional | Only if tooling/export use cases justify it |
| B4. Framework/tooling proof | Pinned Flutter and Serinus examples, generated serializers/Freezed fixture, typed boundary examples, AOT integration CI | 3–5 additional | Required before claiming cross-framework support |
| **Dedicated brand track** | B1+B2+B3+B4 | **15–26** | Does not include a general codec system |

B1 acknowledges current `Email?` and `List<Email?>` output. B2 should prefer an
additive mapped schema or explicit success API over silently changing pipeline
signatures. Brand-preserving lists must then demonstrate `List<Email>` statically
for a non-nullable successful-output contract. The negative analyzer fixture must
prove that unvalidated raw values cannot be assigned directly in static code;
separate tests must demonstrate that dynamic casts still bypass that discipline.

Objects and tuples remain dynamically shaped under this proposal. Inferring
per-field object output or converting tuple schemas into typed records is a
separate generator/type-system project. Do not include it implicitly in B3's
estimate. There is also no basis to promise zero allocation for all mapping
callbacks: only the extension-type wrapper itself is erased.

## Dependencies, sequencing, and optional expansion

1. Publish B1 independently with current limitations. Use B2 to resolve typed
   mapping behavior rather than forcing a base-class rewrite.
2. Before B3, decide whether conversions are representation-preserving brands
   or genuinely bidirectional codecs. Require explicit encode/decode for the
   latter; never infer inverse transforms.
3. Preserve the diagnostic contract in the [Error Codes analysis](error-codes-analysis.md).
   Validate B4 in real pinned integrations before claiming framework support.

The convention-only deliverable is **2–3 person-days**; the complete dedicated-brand
track is **15–26 person-days**. Re-estimate after B2, the highest-uncertainty
implementation boundary.

| Optional work outside the totals | Additional person-days | Boundary |
| --- | --- | --- |
| Audited UUID export | 1–3 | Match runtime acceptance to JSON Schema/OpenAPI expectations with independent fixtures; current uuid check is unsupported by audited export |
| General bidirectional codec foundation | 8–15 | Input/output validation, canonical round trips, nested composition, async policy and serialization/export contract; medium-low confidence |
| Replace base with `AcanthisType<I, O>` | 20–35 | Broad subclass, inference, generator and migration impact; low-confidence architectural option, not recommended prerequisite |

Generator-wide object inference, every database/HTTP driver, and broad JSON
Schema support are excluded. A specific driver adapter needs a pinned API and
example before it can be estimated responsibly. Unverified ecosystem support is
a validation task, not a claim of incompatibility.

With diagnostics and convention-only branding, the recommended first program is
**15–26 person-days** ([Error Codes E1–E6](error-codes-analysis.md#remaining-effort) plus B1). Choosing the complete dedicated-brand track
instead makes the conservative combined budget **28–49 person-days**. These sums
do not assume discounts for overlapping examples and exclude optional codec,
UUID export, and generic redesign work. Re-estimate after E3 and B2: those are
the highest-uncertainty implementation boundaries.

## Compatibility and migration

| Change | Recommended release treatment |
| --- | --- |
| New converter-based brand schema | Potentially additive 2.x if existing generics and parse behavior remain unchanged |
| Change pipeline nullability or base generic arity | Public API change; use a separate additive API or major-version migration |

APIs requiring review include AcanthisType and its subclasses,
AcanthisPipeline/ClassSchemaBuilder, collection and nullable composition,
metadata/introspection, contract/legacy exporters, and issue propagation through
mapped schemas and live sessions. Do not introduce a new diagnostic taxonomy as
a side effect of adding brands.

For a failed UserId UUID check, retain `uuid` with its ordinary path and parameters.
Optional brand metadata may enrich tooling; a separate domain predicate can use
an application code. See the [Error Codes compatibility contract](error-codes-analysis.md#compatibility-and-migration).

## Acceptance gates before claiming completion

Brand/mapping gates need compile-time positive and negative fixtures, lists,
nullable and optional fields, nested maps, explicitly typed unions, dynamic
tuples, manual record mapping, transforms before/after conversion, and conversion
exactly once. Verify converter failure issues, async and live parity, same-code
diagnostics with/without a brand, and both export dialects/modes. Test wrapper and
extension serialization separately. Compile and run AOT and the pinned Flutter
fixture; execute Serinus route parsing and generated serializer decode/encode
before claiming those integrations work.

The completed analysis supplies a passing baseline and reproducible observations.
It does not mark these implementation gates as passed or change production APIs.
