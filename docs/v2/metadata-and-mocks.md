# Metadata, registries and mock generation

## Metadata

```dart
final name = string().min(1).meta(const MetadataEntry<String>(
  title: 'Name', description: 'Public display name', examples: ['Ada'],
));
final AcanthisString shorter = name.max(80);
final entry = MetadataRegistry().get<String>(name.metadataKey);
```

Native `.meta` returns a new schema of the same concrete type and preserves its
operations, defaults, capabilities, and parsing optimizations. The source is
unchanged. Fluent clones, object helpers, lazy binding, and tuple/union/template
variants preserve their metadata. List/nullable composition retains annotations
on the child; container annotations belong to a separate `.meta` call.
Third-party schemas receive a transparent base-schema view.

`metadataEntry` exposes the attached entry. `metadataKey` is the registry key;
V2 uses that name because `RecordSchema.key` already means its key validator.
The singleton `MetadataRegistry()` supports `add`, typed `get<T>`, `has`, and
`remove`. Attaching metadata registers it automatically under a generated key.
Changing metadata on a derived schema keeps the key and updates the registry,
while existing schema instances retain their own entry. Removing a registry
entry does not remove a schema's metadata. The registry holds entries until
removed; use explicit removal for dynamically created schema catalogs.

Metadata collections are shallow snapshots. Nested example/default/extension
values may still be caller-owned. `toJson()` and schema exports produce fresh
JSON containers and serialize dates as ISO strings. Cycles, non-finite numbers,
opaque objects, and excessive annotation size/depth fail explicitly without
invoking custom `toJson` methods. Metadata never changes validation defaults.

JSON/OpenAPI exports include title, description, examples, `$comment`, default
annotations, deprecation, and read/write flags. Metadata IDs use the annotation
`x-acanthis-id`; they do not create JSON reference scopes. `otherProperties`
may add non-conflicting `x-` annotations, which the importer preserves.
Validation keywords cannot be supplied as metadata. Strict export rejects
metadata `format`, which has no audited runtime validation contract.
Annotated graphs rebuild exports so nested caller-owned data cannot leave a
stale cached annotation; ordinary unannotated export caching is unchanged.

## Typed schema registry

```dart
const nameKey = SchemaKey<String, AcanthisString>('account.name');
final builder = SchemaRegistryBuilder()..add(nameKey, name);
final registry = builder.build();
final AcanthisString reused = registry.get(nameKey);
final user = object({'name': reused});
```

`SchemaKey<T, S extends Schema<Object?, T>>` preserves both the output type and
the concrete schema type. Import a canonical key rather than constructing a new
token with the same ID. Lookup returns the exact schema instance. Nested types
remain typed, for example `SchemaKey<List<Map<String, int>>,
AcanthisList<Map<String, int>>>` with `record(string(), integer()).list()`.

The builder rejects duplicate tokens, IDs, schema identities, incompatible
schemas, and IDs outside `[A-Za-z_][A-Za-z0-9_.-]*`. Widened/dynamic keys retain
runtime checks against their original type arguments. `addAll(module)` imports
atomically; `build()` returns an independent immutable ordered snapshot.
`find(key)` returns null only for absent IDs; a conflicting token throws.
`contains(key)` checks canonical identity. Setup errors use
`SchemaRegistryException` and `SchemaRegistryError`, separately from validation.
Registration never parses, mocks, exports, resolves lazy fields, or executes
callbacks, and does not add metadata. Registries have explicit application
ownership and retain their bound schemas. See `example/schema_registry` for
cross-module composition and `test/schema_registry_test.dart` for binding and
lookup checks.

## Bounded mocks

```dart
final schema = object({
  'name': string().min(3).max(12),
  'age': integer().gte(18).lte(65),
  'enabled': boolean(),
});
final Map<String, Object?> sample = schema.mock();
final repeatable = schema.mockSeeded(seed: 42);
assert(schema.validate(repeatable));
```

Both APIs use the same bounded engine. `.mock()` chooses a random seed;
`.mock(42)` is an alias for `.mockSeeded(seed: 42)`. Identical schema, seed,
limits, generators, and Dart SDK produce the same result; no cross-SDK PRNG sequence is
promised. Metadata and registry lookup do not consume randomness. Returned
values retain the schema's output type. Ordinary native values validate again
when reparsed. Pipeline outputs are validated by their target and pipeline
operations and are not reparsed as source inputs. Cancellation uses the normal
validation scope.

The audited subset includes [instances with explicit factories](instances.md#constructing-mocks),
native numbers and their bounds/enumerations,
booleans, scalar literals, nullable values, string lengths/exact values/enums/
email/case checks, UUID, URL/URI, ISO date-time and Base64 strings,
native list membership/length/uniqueness, object presence and
property counts, records, tuples, plain unions, and scalar templates. Dates
support fixed bounds and fixed-date differences; checks relative to now are
rejected. Numeric sampling bounds must fit the JSON safe integer range.

Instance factories construct typed objects from generated, parsed field values;
they are explicitly permitted callbacks, and output bounds inspect declared
fields. [Pipelines](pipeline.md#mock-generation), including those nested in
objects and collections, also permit their
converter, target validation callbacks and pipeline operations. Getters,
factories, mappers and validation callbacks should be pure and deterministic.
Outside that output-validation path or a generator override, refinements, transformations,
cross-field rules/dependencies, async callbacks,
variant guards, lazy resolvers, arbitrary regex/other format checks, imported contracts,
and opaque custom schemas are rejected **before executing their callbacks**.
Container literals and non-scalar equality/membership constraints are outside
the supported subset. Metadata examples are not generation instructions.

`mockSeeded(generators: {schema: (random) => rawInput})` supplies an explicit
candidate generator for that exact schema identity, using the run's seeded
`Random`. The map is snapshotted; overrides apply to nested occurrences of the
same schema and do not mutate it. Fluent clones need their own entry. Providers
return raw inputs, not pipeline outputs. Every candidate passes normal parsing;
invalid results retry within the shared `maxAttempts`.

An override permits synchronous checks, transforms, cross-field rules and guards
in its subtree. Unsupported siblings are rejected before providers run. Async
schemas and lazy resolvers remain rejected even with an override; use a finite,
explicit source shape for recursion. Custom output must remain inspectable as
scalars, lists, maps or instances with described fields. Provider candidates are
bounded before parsing and outputs afterward. Union bounds conservatively
inspect all matching output shapes without rerunning validation callbacks.
Provider exceptions propagate and cancellation is checked around callbacks.
See `example/seeded_generators.dart` for custom regex and nested pipeline mocks.

Limits default to `maxAttempts: 64`, `maxDepth: 16`,
`maxCollectionLength: 256`, and `maxNodes: 4096`. All must be positive; maximum
depth is capped at 128 to protect the call stack. String/collection sizes,
defaults, schema traversal, and returned values are budgeted. Finite domains
never use an unbounded uniqueness retry loop. Failure throws
`AcanthisMockException` with a reason; invalid budgets throw `ArgumentError`.
Bounded sampling is not a satisfiability solver: it can fail on valid but narrow
domains. An unconstrained numeric domain samples around −1000 through 1000;
fixed bounds can move that range. Default date sampling uses 2000–2030 UTC.
