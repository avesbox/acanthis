# Dart Standard Schema packages: comparison and Acanthis integration

Sources checked 2026-10-12, with all four adapter tests passing again on
2026-10-13 using Dart 3.13.3 / Windows x64. This compares **contracts for
validation interoperability**, not competing validation engines or JSON Schema
validators. Neither package implements Acanthis's checks, live sessions, registry,
or localization for it.

## Packages and provenance

| | `enhanced_standard_schema` | `standard_schema` |
| --- | --- | --- |
| Inspected release | 1.1.0 | 0.0.1 |
| Requested repository | [louiss0/standard_schema](https://github.com/louiss0/standard_schema) | [conceptadev/standard-schema-dart](https://github.com/conceptadev/standard-schema-dart), now redirects to [btwld/standard-schema-dart](https://github.com/btwld/standard-schema-dart) |
| Published package | [1.1.0](https://pub.dev/packages/enhanced_standard_schema/versions/1.1.0) | [0.0.1](https://pub.dev/packages/standard_schema/versions/0.0.1) |
| Declared Dart SDK | `^3.0.0` | `>=3.8.0 <4.0.0` |
| Runtime dependencies | None | None |
| License | MIT | BSD-3-Clause, with upstream attribution |

Repository names are not import names. Versions above were resolved from pub.dev;
repository-head documentation can change independently. The Concepta package
records its upstream reference as commit
[`a60ec0620dba64ddff8217f19e2ce479120af234`](https://github.com/standard-schema/standard-schema/tree/a60ec0620dba64ddff8217f19e2ce479120af234).
Both are independent Dart adaptations; this audit does not infer upstream
endorsement, adoption, or maintenance guarantees from their names/version numbers.

## Contract differences

| Capability | Enhanced 1.1.0 | Standard 0.0.1 |
| --- | --- | --- |
| Interface | `StandardSchema<Output>` | `StandardSchemaV1<Input, Output>` |
| Getter | `$standard` | `standard` |
| Input at runtime | `Object?` | `Object?`; the input generic does not restrict the validate argument |
| Validation | `FutureOr` typed success/failure | `FutureOr` typed success/failure |
| Vendor options | Record-based `StandardSchemaOptions` | Map-based `StandardValidateOptions` |
| Basic issue | Abstract extensible issue, message and nullable path | Final issue, message and an immutable path (root is empty) |
| Machine-readable code | Optional hinted issue subclass | No standard code member |
| Structured metadata | Detailed issue subclass with a record | No parameters/metadata member; issue is final |
| Path | Sealed property/string and list-index/int types; explicit string segment | Raw `Object` keys or `StandardPathSegment`; permits more than Acanthis paths |
| Defensive copying | Failure/path lists are stored as provided | Failure and issue-path containers are copied into unmodifiable lists |
| JSON Schema capability | Absent | Separate input/output converter interface and combined validation/conversion interface |
| Target dialect | Not applicable | Extensible target string with 2020-12, Draft-7 and OpenAPI 3.0 constants |
| Utilities | No corresponding public utilities library | Opt-in dot-path rendering and `SchemaError` |

These differences were checked in the installed release sources, not inferred
solely from READMEs. See the publishers' descriptions of
[enhanced issues](https://github.com/louiss0/standard_schema#implementing-the-contract)
and [standard capabilities](https://github.com/btwld/standard-schema-dart#what-this-package-standardizes).

Dart's nominal typing is decisive: implementing one package's interface does not
satisfy consumers of the other, even if properties look equivalent. A typedef or
extension getter cannot bridge that identity. Acanthis needs separate wrappers
(or explicit implementation of both interfaces). Avoid treating the two packages
as drop-in replacements.

## Fit for Acanthis

**Recommendation:** keep core independent and implement optional adapter packages
only for the contract a real consumer accepts. Prefer `standard_schema` for a
consumer needing both validation and JSON Schema. Prefer the enhanced contract
when a consumer explicitly wants typed issue codes and metadata. This is a fit
assessment, not a claim that one package has greater ecosystem adoption.

For both, map a valid `AcanthisOutcome<T>` to typed success. Invalid recovery
values must never become success. Resolve `schema.isAsync` once per call or
wrapper setup: synchronous schemas should return synchronously, while async
schemas return a future. Reuse the original schema and propagate application
exceptions; do not reconstruct validators or erase schema callbacks.

For `standard_schema`, declare input `Object?` because Acanthis has an unknown
parse input and one output generic. Preserve string/int segments directly.
Converting to `StandardIssue` necessarily omits native codes, constraint
parameters, and union branches. Keep native diagnostics available separately;
do not embed machine data in human messages or flatten ordered branches silently.
Its dot-path utility is a display convenience, not a substitute for segment paths
or escaped JSON pointers.

For the enhanced package, a detailed issue record can retain `parameters` and
`branches`, with the original `code` and explicitly typed path elements. This
metadata remains vendor-specific: another consumer cannot infer Acanthis union
semantics from the generic record bound. Freeze issue and failure lists in the
adapter; `const` constructors do not defensively copy caller-owned collections.

For standard JSON conversion, map input/output explicitly to
`AcanthisSchemaMode`. Support audited JSON Schema 2020-12 only until other dialects
are independently verified. Reject Draft-7/OpenAPI 3.0 and arbitrary target names;
Acanthis's existing OpenAPI exporter describes 3.1, so it must not be relabeled as
3.0. Preserve unsupported-schema exceptions. Never fall back to the legacy
best-effort exporter to make an adapter appear universally exportable.

Standard validation issues are not a replacement for Acanthis's versioned
locale-independent transport. Select a message resolver at the adapter boundary
only when the consuming framework needs localized messages. Reserve native
transport for machine clients and preserve request-scoped locale isolation.

## Executed feasibility probes

[Example adapters](../integration/error_contract/lib/standard_adapters.dart) and
[tests](../integration/error_contract/test/standard_adapters_test.dart) verify:

- Typed string output and sync/async validation in both contracts.
- Property `'0'` versus index `0`, and native enhanced code/constraint metadata.
- Nominal incompatibility and the different defensive-copy behavior.
- Audited input/output JSON Schema, unsupported targets, and unsupported transforms.

Run `dart pub get` followed by `dart run test test/standard_adapters_test.dart`
inside `integration/error_contract`. These probes are deliberately not exported
by Acanthis. They do not yet implement vendor options or a reusable localization
policy. No adapter throughput, consumer adoption, minimum-SDK matrix, or external
form/tool framework compatibility is claimed. The separate Serinus integration
has an upstream SDK workaround described in [integration notes](../integration/README.md);
the Standard Schema probes themselves do not import Serinus.

## Delivery plan and acceptance gates

1. Agree a consuming package and one shared interface/version. Pin compatibility
   ranges carefully: `standard_schema` is pre-1.0. Keep optional dependencies
   outside the core package.
2. Ship a validation wrapper with typed output, unknown input, deterministic
   issue order, immutable diagnostics, and documented option/locale handling.
   Reject unsupported options rather than silently implying support.
3. Add a separate JSON-capability wrapper for the supported audited subset.
   Test defaults, transforms, recursion, selected-field rejection, dialects,
   and input/output differences with independent schema validators.
4. Test a real consumer, multiple async requests, branches, escaped/typed paths,
   empty failures, custom codes, extension-type erasure, and invalid outcomes
   without recovery values. Compile JIT/AOT and test the supported SDK range.

Estimated additional adapter-product work, excluding this analysis: 2–4 focused
person-days for one validation adapter, 2–3 for audited JSON conversion, and 2–4
for a second contract plus consumer/release verification. These are planning
ranges, not measured implementation time. Acanthis's schema registry can store
wrapped contracts at application setup, but it neither resolves nominal package
incompatibility nor supplies the deferred named JSON/OpenAPI bundle exporter.
