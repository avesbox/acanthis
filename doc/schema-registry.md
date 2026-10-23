# Schema registry

For V2 (`ObjectSchema` / `RecordSchema`), see the updated
[metadata, registries and mocks guide](../docs/v2/metadata-and-mocks.md).

`SchemaRegistry` is an optional catalog of existing validators. Ordinary imports
still work. Create a builder during application setup, publish its snapshot, and
resolve validators once while composing schemas or binding application handlers.

```dart
import 'package:acanthis/acanthis.dart';

// Export this canonical token from the module owning the contract.
const emailKey = SchemaKey<String, AcanthisString>('accounts.email.v1');
final builder = SchemaRegistryBuilder()..add(emailKey, string().email());
final schemas = builder.build();
final AcanthisString email = schemas.get(emailKey);
```

Keys carry both the parsed value type `T` and concrete schema type
`S extends AcanthisType<T>`, preserving methods such as `.email()` and nested
generic output types:

```dart
const countsKey = SchemaKey<
  List<Map<String, int>>,
  AcanthisList<Map<String, int>>
>('counts');
final countsSchema = AcanthisMap<int>({'count': integer()}).list();
final counts = (SchemaRegistryBuilder()..add(countsKey, countsSchema)).build();
final List<Map<String, int>> values = counts.get(countsKey).parse([
  {'count': 3},
]);
```

The type bound rejects mismatches between `T` and `S`. Registration checks both
original types at runtime even when a key is widened or passed through `dynamic`.
Lookup infers `S` from the key; its full output type is preserved. Heterogeneous
catalog entries use `Object?` as their common type.

This does not add field-specific types to `object({...})`: that helper still
returns `AcanthisMap<dynamic>`. Use a typed map or a schema producing a typed
record/domain object when you need a more precise output contract. Existing
single-argument keys must migrate from `SchemaKey<S>` to `SchemaKey<T, S>`.

Import the canonical key instead of constructing another key with the same ID.
Keys use object identity; Dart may canonicalize identical `const` expressions.
`get` returns the exact registered object. `find` returns null only for a missing
ID; a different token with an occupied ID throws. `contains` checks exact token
identity and returns false for a conflicting token.

IDs are case-sensitive and match `[A-Za-z_][A-Za-z0-9_.-]*`. Duplicate tokens,
duplicate IDs, and aliases for the same schema instance are rejected. Distinct
schemas may have the same output type. Ordinary incompatible bindings fail static
checking; widened and dynamic bindings also undergo a token-owned runtime check.
Runtime checks cannot distinguish erased extension-type brands: use separate
canonical tokens for domain identity.

`SchemaRegistryException` exposes a stable `reason` (`SchemaRegistryError`), the
catalog `id`, and a diagnostic message. These are configuration errors, not
validation issues. The reasons are `invalidId`, `duplicateToken`, `duplicateId`,
`duplicateSchema`, `missingBinding`, `tokenConflict`, and `incompatibleSchema`.

Use `builder.addAll(moduleSnapshot)` to import bindings atomically. Any collision
leaves the builder unchanged. `build()` copies the bindings; subsequent additions
cannot alter existing snapshots. `entries` is an immutable list of bindings in
registration order, each exposing `id`, `key`, and `schema`.

Snapshots freeze bindings only. They do not freeze schema internals, metadata, or
callback state, and they retain strong references to schemas for their lifetime.
Build independent registries for applications, tests, and isolates. Deriving a
schema does not replace its registered base; register the derived schema under a
new key if it needs a name. There is no global catalog, replacement API, factory
resolution, or automatic registration through `.meta()`.

Registration and retrieval never validate, mock, export, or traverse schemas.
Existing recursive schemas remain supported through their normal lazy entries.
Validation paths refer to use sites, not catalog IDs. Existing exporters remain
unchanged; catalog IDs do not become JSON Schema `$id` values. Named JSON Schema
and OpenAPI bundles are deferred, as are framework-specific automatic bindings.

See the executable [cross-module example](../example/schema_registry/main.dart).
Run the registry tests with `dart run test test/registries` and verify static
rejection plus AOT reuse with `dart run tool/check_schema_registry_types.dart`.

## Implementation status (2026-10-12)

This document consolidates the usage guide and the 2026-09-29 registry analysis
(original baseline `e69479d584a48b1bc3eebc146951f46a28f2bf6f`). Status was checked
against the current working tree, including existing uncommitted implementation.
The core registry is implemented and publicly exported from `lib/acanthis.dart`.

| Phase | Status | Evidence or remaining work |
| --- | --- | --- |
| R1: contract and typing | Complete | Canonical identity, output/concrete types, widened/dynamic guards, three negative compilation fixtures, and typed AOT example pass. |
| R2: core catalog | Complete | Builder, immutable snapshots, atomic imports, ordered entries, collision checks, and structured exceptions are covered by registry tests. |
| R3: reuse and integration | Core reuse complete; framework verification open | Cross-module example and sync/async, live, context, recursion, diagnostics, and existing-export compatibility tests pass. Pinned framework bindings remain unverified. |
| R4: named JSON Schema bundles | Deferred, not implemented | Registry-aware graph traversal and named definitions remain future work. |
| R5: OpenAPI bundles | Deferred, not implemented | Components naming and reference rebasing remain future work. |

Verification performed for this audit:

- `dart run test --reporter expanded`: **491 tests passed**, including
  [registry unit tests](../test/registries/schema_registry_test.dart) and
  [reuse tests](../test/registries/schema_registry_integration_test.dart).
- `dart analyze --fatal-infos`: no issues.
- `dart run tool/check_schema_registry_types.dart`: all three incompatible
  fixtures rejected; cross-module example compiled and ran under Windows AOT.

The design rationale and original estimates below are retained for context.
Statements proposing named export, factories, or framework integrations describe
future work. The original R1–R5 totals are not estimates of work still remaining.
No registry performance improvement or automatic framework integration is claimed.

## Design rationale and deferred work

The implemented, explicitly owned `SchemaRegistry` stores existing schema
instances behind typed keys. Build it during application setup, publish an
immutable snapshot, and resolve schemas while composing validators or binding
routes. Return the original schema instance so existing validation, diagnostics,
async behavior, and specialized execution paths remain intact.

Ordinary Dart imports remain sufficient for direct reuse. A registry adds value
when modules need a common catalog, frameworks need explicit schema bindings, or
tools need stable names for discovery and export. It should not become mandatory
for schemas or a replacement for Dart's module system.

Typed registration and retrieval are delivered. Named JSON Schema/OpenAPI export
remains a separate phase. Defer factories, forward references, hierarchical overrides,
runtime replacement, and remote schema loading until specific uses justify them.

## Original source findings and probe

| Area | Source finding | Implication |
| --- | --- | --- |
| Direct composition | [object fields](../lib/src/types/map.dart), lists, unions, and pipelines accept existing schema objects | A schema can already be declared once, imported, and reused |
| MetadataRegistry | [Implementation](../lib/src/registries/metadata_registry.dart) is a singleton `Map<String, MetadataEntry>`; `add` overwrites and `get<T>` casts metadata | It stores metadata, not executable schemas; its collision/lifetime policy should not be copied |
| Generic model | [AcanthisType](../lib/src/types/types.dart) has one output parameter and dynamic parse input | A registry need not introduce a new input/output generic architecture |
| Compilation | AcanthisType lazily caches compiled operations on the schema instance | Returning the same instance preserves existing compilation reuse; cloning or rebuilding on lookup would lose that benefit |
| Recursion | [LazyEntry](../lib/src/types/map.dart) resolves a callback with its containing map | Existing object recursion is not a general named-reference registry; bare LazyEntry is not a drop-in registry proxy |
| Legacy export helper | [LazyObjectMapper](../lib/src/lazy_object_mapper.dart) stores recursion flags | It is neither a schema catalog nor a suitable runtime lookup service |
| Audited export | [_ContractExporter](../lib/src/schema_export.dart) tracks currently active objects by identity, emits local definitions for recursion, and then removes active entries | Stable recursive references work; repeated non-recursive siblings are not generally deduplicated |
| Metadata and export | Audited export selects presentation metadata and ignores arbitrary reference overrides | `meta(id: ...)` does not register a schema or provide named audited references |
| Structural ownership | Object construction stores the supplied field map; `fields` exposes an unmodifiable view of it | A frozen registry cannot promise deeply immutable schemas merely by freezing its own map |

The original V1 [probe](../tool/schema_registry_analysis_probe.dart) ran successfully
with six explicit checks:

1. Billing and shipping fields hold the exact same address schema instance.
2. A failure in billing retains `/billing/city`, rather than a definition name.
3. Deriving a nonempty string schema leaves the base string schema unchanged.
4. Audited export inlines a shared non-recursive address twice without `$defs`.
5. A stable recursive object already emits a local `$ref`.
6. Mutating the caller-owned field map is visible through an object's field view.

The sixth check observes ownership, not reliable validation after mutation:
object caches may already reflect the original fields. Treat such mutation as
unsupported usage; do not infer safe schema replacement from it.

The retained probe now runs against V2 and checks that object construction
snapshots the field map. Run it with `dart run tool/schema_registry_analysis_probe.dart`;
the six observations above record the original V1 baseline. The earlier
Error Codes/Branding baseline passed 463 tests; those results are historical
evidence, not tests of the registry. At the original analysis date, registry
implementations, framework bindings, and named bundle export had not been
executed. Current verification is recorded above. No registry performance
improvement has been measured.

## Reuse available today

For a small application, exporting a shared value from a Dart library already
meets the basic requirement:

```dart
// schemas/address.dart — current API
import 'package:acanthis/acanthis.dart';

final addressSchema = object({
  'city': string().notEmpty(),
});
```

```dart
// schemas/order.dart — current API
import 'package:acanthis/acanthis.dart';
import 'address.dart';

final orderSchema = object({
  'billing': addressSchema,
  'shipping': addressSchema,
});
```

Avoid recreating schemas inside request handlers. A registry should make the
above values discoverable without rerunning their constructors, validations, or
callbacks. It does not automatically scan Dart libraries, import definitions
from source paths, or reconstruct validation callbacks from JSON.

## Implemented API and typing

Prefer a key parameterized by the **schema type**, not only its output type.
`SchemaKey<String, AcanthisString>` preserves `.email()` and other string-specific
composition methods; returning only `AcanthisType<String>` would lose them.
A caller can deliberately declare a more general key when that is its desired
public interface.

```dart
// Implemented API.
const emailKey = SchemaKey<String, AcanthisString>('accounts.email.v1');
const addressKey =
    SchemaKey<Map<String, dynamic>, AcanthisMap<dynamic>>('common.address.v1');

// These schemas can be imported from existing modules.
final builder = SchemaRegistryBuilder()
  ..add(emailKey, emailSchema)
  ..add(addressKey, addressSchema);
final schemas = builder.build();

final AcanthisString email = schemas.get(emailKey);
final order = object({
  'email': email,
  'billing': schemas.get(addressKey),
  'shipping': schemas.get(addressKey),
});
```

Implemented surface:

| API | Contract |
| --- | --- |
| `SchemaKey<T, S extends AcanthisType<T>>(String id)` | Immutable typed token declared by the module owning the contract |
| `SchemaRegistryBuilder.add<T, S>(SchemaKey<T, S> key, S schema)` | Register an existing instance; reject collisions and incompatible bindings |
| `SchemaRegistryBuilder.addAll(SchemaRegistry module)` | Import another snapshot's bindings atomically, after checking every collision |
| `SchemaRegistryBuilder.build()` | Copy bindings into a new immutable registry snapshot |
| `SchemaRegistry.get<S>(SchemaKey<Object?, S> key)` | Return the original `S`; throw a descriptive configuration exception if missing/incompatible |
| `SchemaRegistry.find<S>(SchemaKey<Object?, S> key)` | Return null only for absence; a conflicting token or incompatible type is still an error |
| `SchemaRegistry.contains(key)` | Check that exact token, rather than merely a matching string |
| `SchemaRegistry.entries` | Read-only, deterministic catalog of IDs and schema objects for tooling |

Keys belong in a shared Dart contract library. Consumers import the canonical
token rather than construct another token with the same string. The registry
maintains both token identity and a unique string-ID index: distinct tokens with
the same ID conflict, even when their output types happen to match. An optional
future string lookup must return an erased schema or require an explicit checked
token; avoid an unchecked `get<T>('name')` cast masquerading as static safety.

Use ordinary generic checking plus a token-owned runtime compatibility check at
registration and retrieval. Test widened generic keys and dynamic inputs: Dart
covariance must not permit registering an incompatible schema behind a narrower
token. Runtime checks cannot distinguish erased extension-type brands. Separate
token identities provide domain identity; neither output `Type` nor
`runtimeType.toString()` is a sufficient registry key. See the
[Branding analysis](branding-analysis.md).

Object outputs retain their existing `Map<String, dynamic>` shape. Registry
lookup does not infer typed object properties or remove pipeline nullability.

## Registration, ownership, and lifecycle

Implemented first-release policies:

- IDs are case-sensitive and nonempty, with a conservative grammar such as
  `[A-Za-z_][A-Za-z0-9_.-]*`. Validate at registration. Module prefixes and explicit
  versions such as `accounts.user.v1` make naming intentional. They are catalog
  identifiers, not automatically JSON Schema `$id` URIs.
- Reject duplicate tokens and duplicate IDs, including repeated registration of
  the same binding. There is no last-write-wins behavior. Module import preflights
  all entries and leaves the builder unchanged on failure.
- Assign one canonical ID per schema instance in a snapshot; reject binding the
  same instance to multiple IDs initially. This avoids an arbitrary name choice
  during later export. Aliases can be a separately specified feature.
- `build()` takes a defensive copy of bindings. Later builder edits cannot alter
  a published registry. The registry has no `replace`, `remove`, or global default.
  Create a fresh snapshot for tests, configuration changes, and hot reload.
- `get` returns the exact registered schema, not a wrapper, clone, or factory
  result. Fluent derived schemas require explicit new registration if they need
  names; they do not mutate or replace the registered base.
- A registry owns strong references for its lifetime. It stores no validation
  results, live sessions, pending requests, or locale state. Releasing the registry
  does not dispose external services captured by callbacks.
- Separate applications/tests own separate registries. Each isolate builds its
  own instances; do not promise transfer of schemas containing closures across
  isolates. Request-specific context continues through existing validation scopes.

Snapshot immutability covers the bindings only. Existing user callbacks, metadata
values, custom schema subclasses, and caller-owned container definitions can
remain mutable. The implementation must document that distinction. Audit copying
of structural constructor inputs as a separate reliability change; a registry
cannot safely deep-copy arbitrary schemas or freeze captured application state.

Explicit dependency injection is sufficient for Flutter and server adapters:
pass a registry to the integration, resolve the schema during setup, then reuse
the schema in validation calls. No framework dependencies belong in the core.
Framework examples must demonstrate actual bindings before automatic route/form
discovery is advertised.

## Recursion and deferred definitions

The initial registry stores completed schema objects. Modules can register an
existing recursive object that uses `lazy((parent) => parent.list())`; retrieval
does not resolve or traverse it. Registration therefore needs no graph expansion.

Mutually dependent factory registration is a different feature. If introduced
later, it needs explicit states (unresolved, resolving, resolved, failed), one-time
factory execution per snapshot, missing-reference checks, and useful dependency
traces. Reject factory-resolution cycles such as A constructing B constructing A;
distinguish those from valid recursive validation of a finite nested value.
General schema references would also need sync/async propagation, defaults,
presence, export traversal, and live scheduling support. Do not implement them
by borrowing LazyEntry outside its containing-object contract.

Storing a recursive schema does not add cycle handling for cyclic Dart input
objects. Existing recursion and export depth limits remain in effect.

## Named schema export: optional second phase

Runtime lookup and serialized references solve different problems. The initial
registry works with existing exporters unchanged. Registration alone must not
alter emitted schemas, metadata, validation, or code paths.

For named export, extend the audited exporter with an explicit registry context
and a bundle-level traversal. Proposed entry points may be
`registry.exportJsonSchema(rootKey, mode: ...)` and a separate OpenAPI-components
exporter. Keep the dialect and input/output mode mandatory or unambiguous.

JSON Schema supports reusable definitions under `$defs` and references via
`$ref`; `$id` has URI/base-resolution semantics and is not simply a display name.
This is why a catalog ID must not be copied blindly into `$id`.
[JSON Schema structuring documentation](https://json-schema.org/understanding-json-schema/structuring)
provides the reference model.

OpenAPI supports named schemas under `components.schemas`; document-level
references must point to that location. A standalone Schema Object and a complete
document have different reference roots.
[OpenAPI 3.1.1 components](https://spec.openapis.org/oas/v3.1.1.html#components-object)
defines that container. Existing Acanthis export returns a standalone Schema
Object, as described in the [local guide](../.website/open-api-schema.md).

The implementation plan must cover:

1. One traversal and definition table per output document; use registered identity
   to name shared schemas and a reserved, collision-checked namespace for unnamed
   recursive definitions. Do not export roots independently and concatenate their
   `schema0` definitions.
2. Emit only definitions reachable from selected roots by default. A catalog
   export can explicitly select all roots. Registering an unrelated unsupported
   schema must not break a supported root's export.
3. Distinguish in-progress and completed nodes so recursion and repeated siblings
   both reference the appropriate definition. Deterministic registered IDs must
   remain stable when registration order changes.
4. Keep input and output definitions separate. When combining both modes, allocate
   collision-checked names and reject ambiguity; never reuse an input definition
   for output simply because the runtime schema instance is the same.
5. Serialize reference targets with correct pointer/URI escaping, and rebase every
   nested reference when embedding in `components.schemas`. Preserve current
   restrictions on unsupported operations rather than exporting them as `{}`.
6. Start with per-export caches. Persistent export caching is unsafe without a
   reliable immutability/invalidation contract for schemas and metadata. A failed
   export must not poison later calls.

For example, repeated address use could become two references to
`#/$defs/common.address.v1` with one definition. In an OpenAPI bundle the matching
target could be `#/components/schemas/common.address.v1`. This is intended output,
not a capability verified in the current exporter.

Remote URI fetching, JSON Schema import, schema persistence, and callback
serialization are out of scope. They require separate trust and compatibility
contracts and do not follow automatically from having a registry.

## Error codes, branding, and compatibility

Registry failures are setup/configuration errors, not invalid user data. Define
a dedicated exception with stable reasons such as duplicate ID, missing binding,
token conflict, and incompatible schema. Include the catalog ID and module context
when known, not request payloads. Do not convert these exceptions into
`AcanthisIssue` or a successful `find` miss.

Validation continues to report use-site paths and original codes. Reusing an
address definition at billing must yield `/billing/city`, not a registry-ID
prefix. Locale resolution remains independent. If schema provenance is later
exposed, make it separate optional metadata under the
[Error Codes contract](error-codes-analysis.md).

A registry can bind an existing branded pipeline under an explicit token, but
does not make it exportable or repair its composition methods. It does not infer
nominal identity from erased Dart extension types. Brand metadata and registry
IDs serve different purposes and must not silently override each other.

The core feature is additive 2.x work: new classes under `lib/src/registries/`,
public exports in `lib/acanthis.dart`, documentation, and tests. Keep
MetadataRegistry behavior intact for compatibility; do not automatically register
every `.meta()` call as a schema. Preserve legacy and audited export behavior
unless callers select the new named-bundle APIs. Constructor defensive-copy
changes and new recursion semantics require their own compatibility review.

## Original implementation sequence and estimates

Estimates assume one experienced Dart maintainer. A person-day includes focused
implementation, tests, review preparation, and documentation; external review
latency is excluded. These estimates are independent of the Error Codes and
Branding totals and are not measured timings.

| Phase | Deliverable and exit condition | Person-days | Confidence |
| --- | --- | --- | --- |
| R1. Contract and typing spike | Finalize token identity, covariance guards, naming, collisions, and snapshot semantics; compile positive/negative generic examples | 1–2 | Medium |
| R2. Core catalog | Builder, typed lookup, atomic module import, deterministic introspection, configuration errors, no wrapper or global state | 2–3 | High |
| R3. Reuse and integration verification | Cross-library examples; schema identity, diagnostics, async/live/context parity; documentation and setup-time framework binding example | 2–3 | Medium |
| **Initial release** | R1–R3: typed reuse of already-defined schemas | **5–8** | No exporter rewrite |
| R4. Named JSON Schema bundles | Identity graph traversal, repeated/recursive references, reachable roots, input/output separation, independent validation | 3–5 additional | Medium |
| R5. OpenAPI bundles | Components naming, reference rebasing, both modes, existing export compatibility, integration example | 2–4 additional | Medium |
| **Core plus named export** | R1–R5 | **10–17** | Requires audited exporter changes |

Optional later work, outside these totals: deferred factories/general references
(4–8 days, low confidence) and structural defensive-copy hardening (2–4 days,
medium-low confidence, after an ownership audit). Hierarchical registries,
hot-swappable bindings, persistence, and remote loading need separate requirements
before estimation. No general codec or two-parameter base-schema redesign is a
prerequisite for R1–R3.

Deliver R1–R3 first. Re-estimate after the typing spike if covariance requires a
different key API. Undertake R4–R5 only when an integration needs stable named
references; coordinate with existing schema-export fixtures rather than bypassing
the audited exporter. Benchmark lookup/setup separately from steady-state parsing:
the proposed runtime path resolves once and adds no per-value registry lookup.

## Acceptance criteria and remaining gates

- Define a schema in one Dart library, register it in application setup, and reuse
  it in two other modules. Lookup preserves its concrete static schema type and
  object identity; registration does not parse, mock, export, or execute callbacks.
- Compile-time fixtures reject ordinary mismatched key/schema bindings. Runtime
  fixtures reject incompatible bindings through widened/dynamic generics. Test
  identical output types with different tokens and erased brands explicitly.
- Missing entries, duplicate IDs/tokens, duplicate schema aliases, invalid names,
  and conflicting module imports have deterministic errors. Failed import is
  atomic; `find` returns null only for a genuinely absent token.
- Builder changes cannot alter snapshots. Independent registries do not leak
  entries or locale/context state. A derived schema does not replace the base.
  Document that caller-owned schema internals are not deep-frozen.
- Reused schemas match direct imports for sync/async parsing, ordered duplicate
  issues, nested paths, unions, defaults, optional fields, transforms exactly once,
  live revisions, and concurrent context. Existing supported recursive schemas
  remain usable without eagerly expanding their graph.
- Named-export tests separately cover sibling reuse, recursion, multiple roots,
  unknown IDs, name collisions, unrelated unsupported entries, input/output
  separation, both dialects, and failure cleanup. Independent validators resolve
  every reference and compare acceptance with runtime behavior on the supported
  subset. Existing exporter outputs remain unchanged without registry opt-in.
- Run the package suite and analyzer; compile a representative typed-key example
  under AOT. Run pinned framework examples before claiming automatic integration.

The core catalog is implemented and verified as recorded above. Named export
and pinned framework integration gates remain open.

