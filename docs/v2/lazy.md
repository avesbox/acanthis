# Parent-bound lazy schemas

`lazy<O>((parent) => schema)` defines a recursive object field. The resolver
receives an `ObjectSchema` with the parent's fields and configuration. It runs
once per lazy definition and parent binding, rather than once per parsed value.
Top-level `lazy`, `LazyEntry<O>`, `Acanthis.lazy` and `AcanthisType.lazy` expose
the same implementation.

```dart
final tree = object({
  'name': string().min(1),
  'children': lazy((parent) => parent
      .unknownKeys(AcanthisUnknownKeys.preserve)
      .list()
      .max(10)),
});

final result = tree.tryParse({
  'name': 'root',
  'children': [
    {'name': 'leaf', 'children': [], 'extra': 1},
  ],
});
```

Use a direct lazy object field and build its containers inside the resolver:
`lazy((parent) => parent.list())` or
`lazy((parent) => record(string(), parent))`. Optional fields can terminate a
linked recursive object: `object({'next': lazy((p) => p)}).optionals(['next'])`.
Mutual recursion through references to previously declared object schemas is
also supported. Resolvers describe stable schema definitions; they must not
depend on request data or rebuild an unbounded graph of independent objects.
Input data must be finite, as with ordinary recursive validation.

## Operations and defaults

Lazy definitions support typed `withCheck`, `refine`, `refineAsync`, `transform`,
`withTransform`, `transformAsync`, and `withDefault`. Their own checks and
transforms execute after the resolved child, exactly once and in fluent order.
Fail-fast parsing stops immediately. Collecting parsing can check typed recovery
but stops at a transformation boundary after any failure. A child without typed
recovery also leaves the parent without recovery; no recursive mock is invented.

Both a wrapper default and a resolved child's default can supply a missing
object field. Wrapper defaults take precedence, are validated by the resolved
schema, and may explicitly be null for nullable output types. `partial()` still
preserves omission. Generic lazy defaults retain normal Dart ownership; use
the native list/map `withDefault` on the resolved schema for a container snapshot.

The same lazy definition can be reused in different objects or fluent variants:
each independent parent binds separately. Sharing it across fields of one
parent shares resolution; each supplied field still runs its own validation.
Fluent parent variants created within a resolver share its binding scope, so
`parent.unknownKeys(...).list()` does not rebuild a new schema at every level.
The resolver receives a stable parent view; object identity is not an API
guarantee. Configuration and child schemas match the bound parent.

## Async capability and explicit binding

An iterative, identity-based graph walk determines async capability before any
validation callbacks run. It visits recursive back edges safely and caches only
the completed result on the schema. Async descendants in lists, records,
objects, or lazy wrappers cause synchronous parsing to throw `StateError`.
No async check can be skipped by parsing an apparently synchronous parent.
All async entry points execute checks and transforms sequentially and keep
diagnostics local to the invocation.

An unbound lazy entry cannot determine its resolved async capability or parse
standalone. Bind it explicitly with `entry.call(parent)`, or use the optional
parent argument on its parse/validation methods:

```dart
final entry = lazy((_) => integer().coerce());
final parent = object({'count': entry});
final bound = entry.call(parent); // stable Schema<Object?, int>
final count = bound.parse('3');
final sameCount = entry.parse('3', parent);
```

Resolvers that return another unbound `LazyEntry`, alias cycles without a
container boundary, and reentrant resolution fail with a descriptive
`StateError`. Resolver errors are cached with their original stack trace;
validation callback errors propagate normally.

## Performance and migration

Binding is lazy setup work. Each bound definition caches its resolved target.
A wrapper without its own operations or default is removed from object
execution: the object calls its resolved schema directly. Wrappers with behavior
reuse the same persistent operation chain implementation as map schemas, with
O(1) fluent appends and iterative first-use materialization. Completed capability
results, child arrays, and primitive eligibility are also reused. Only schema
definitions are cached; parsed values, diagnostic sinks, and contexts are not.

This ports the legacy parent-based recursive validation capability and fixes
discarded wrapper operations and hidden async descendants. JSON Schema/OpenAPI
export now handles recursive collections through local `$defs` and `$ref`;
see [the strict contract](contracts.md). Unsupported wrapper callbacks are
rejected explicitly. Metadata is preserved through binding; bounded mocking rejects lazy resolvers.
Legacy standalone `LazyEntry` mock/default/metadata helpers were unimplemented;
V2 now implements defaults.

See the [benchmark guide](../../benchmark/README.md) for current comparison
commands and measurement limits.
