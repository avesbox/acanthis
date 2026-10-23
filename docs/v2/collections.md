# List, object and record schemas

The V2 collection schemas use the same [parsing API](parsing.md) as scalar types.
Nullable composition uses a mixin like `ListableSchema`; see
[boolean, nullable and literal schemas](boolean-nullable-literal.md).
`parse` / `parseAsync` return raw values and throw `ValidationError` at the first
failure; `tryParse` / `tryParseAsync` return outcomes and collect diagnostics in
traversal order. Synchronous parsing of any schema with
async children or operations throws `StateError` before executing callbacks.

```dart
import 'package:acanthis/acanthis.dart';

final tags = list(string().trim()).min(1).unique();
final user = object({
  'name': string().trim().min(1),
  'age': integer().positive(),
  'tags': tags.withDefault(['new']),
}).optionals(['age']);
final counts = record(string().trim(), integer().coerce());

final parsedUser = user.parse({'name': ' Ada '});
// parsedUser == {'name': 'Ada', 'tags': ['new']}
final parsedCounts = counts.parse({' apples ': '3'});
// parsedCounts == {'apples': 3}, with type Map<String, int>
```

The top-level factories are also available through `Acanthis` and its
`AcanthisType` alias. Concrete types are `AcanthisList<T>`, `ObjectSchema`, and
`RecordSchema<K, V>`. A record schema describes a dictionary, not a Dart record.

## Object fields and presence

`ObjectSchema` has a fixed map of named child schemas and returns
`Map<String, Object?>`. Definitions snapshot their field map. Fields are required
unless listed in `optionals`; a missing required field produces `required`
without calling the child. Explicit null is always passed to the child.

A child implementing `DefaultSchema` with `hasDefault == true` receives null
for a missing field so that its default is parsed normally. The native string,
numeric, list, object, and record schemas implement this capability. The default
capability's standard `hasDefault` implementation treats a non-null default as
configured. Accepting null alone does not make a field optional.

`partial()` preserves omitted fields, including fields with defaults. It applies
only to this object's layer; supplied nested objects still use their own schema.
`patch()` is an alias. `partial(deep: true)` / `patch(deep: true)` also make
directly nested `ObjectSchema` fields partial, recursively. As in V1, lists,
records, nullable wrappers, and typed additional values retain their child
schemas. Parent-bound lazy fields see the derived parent, so recursive resolvers
can use `parent.patch(deep: true).list()` when recursive partial input is needed.

Use `unknownKeys(AcanthisUnknownKeys.strip / preserve / reject)` to choose how
undeclared fields are handled. Stripping is the default. Preserved values are
passed through without validation; rejection produces `unknownKey` at each
undeclared key. Object inputs must have string keys.

`passthrough()` selects preservation. `passthrough(type: schema)` also validates
and transforms every undeclared value, including explicit nulls. Declared fields
keep their own schemas. Extra values support defaults, async operations, nested
diagnostic paths, and parent-bound lazy definitions. Calling `passthrough()`
again clears the extra-value schema; selecting strip or reject clears it too.

## Object helpers

All helpers return new definitions and preserve root operations, defaults,
presence, unknown-key policy, and typed passthrough configuration:

| Helper | Behavior |
| --- | --- |
| `extend(fields)` | Append new fields; keep existing schemas on collisions. |
| `merge(fields)` | Append new fields; replace schemas on collisions. |
| `pick(names)` | Select known fields in requested order; ignore unknown names. |
| `omit(names)` | Remove named fields and preserve the remaining order. |
| `minProperties(n)` | Require at least `n` properties in the parsed map. |
| `maxProperties(n)` | Require at most `n` properties in the parsed map. |
| `lengthProperties(n)` | Require exactly `n` properties in the parsed map. |

Field maps are snapshotted. Pick/omit also remove optional markers for removed
fields, so adding a removed field later makes it required normally. Helpers
preserve lazy definitions without running their resolvers at construction time;
the resulting object's shape is used when binding them.

```dart
final contact = object({'name': string(), 'email': string()});
final publicContact = contact.pick(['name']);
final storedContact = contact.extend({'active': boolean().withDefault(true)});
final update = storedContact.patch(deep: true);
final flags = object({}).passthrough(type: boolean()).maxProperties(10);
```

Property-count checks execute in the operation pipeline after child parsing.
Stripped keys do not count; inserted defaults and preserved extras do. Earlier
root transformations can change the count seen by later checks. Diagnostics
use `minProperties`, `maxProperties`, or `lengthProperties` with a
`constraintValue` parameter.

## Record entries and paths

`RecordSchema<K, V>` validates each input key, followed by its value, in insertion
order. Key and value transformations both contribute to the typed output map.
If multiple entries produce the same parsed key, validation fails with
`duplicateKey`; entries are never silently overwritten and there is no recovery
map. In collecting mode a failed key does not prevent validation of its value.

Child issues are prefixed with the original input key, including when the key is
transformed. Key and value diagnostics share that entry path. Non-string/non-int
Dart input keys use the entry's zero-based insertion index because diagnostic
paths support only strings and integers. Nested object/record/list schemas
compose these path segments without converting keys containing dots to paths.

## Operations, defaults and recovery

Both map families support typed `withCheck`, `refine`, `refineAsync`, `transform`,
`withTransform`, `transformAsync`, `withDefault`, and boolean validation methods.
Operations execute after child parsing, in declaration order. Collecting mode
can run checks on a complete typed recovery value, but transformations stop at
the first boundary following any failure. Callback programming errors propagate.

In outcome-returning parsing, if any child lacks typed recovery, the parent is invalid without a value.
Fail-fast map traversal also returns no recovery when traversal stops early.
Reading `.value` on either outcome throws `StateError`; check `isValid` or
`AcanthisInvalid.hasValue` first. Collecting maps retain a recovery value only
when all included entries can be assembled with the promised output types.

Fluent operations share immutable definitions and keep parsing state local to
each invocation. Object and record parsing reuse correctly typed input maps
when all keys and values remain unchanged. Reused maps retain their original
insertion order, runtime type, and mutability, including read-only inputs.
Changing a returned reused map therefore changes the input too. Changed fields,
inserted defaults, converted record keys, and stripped unknown fields produce
new map containers. Unchanged nested containers can still be shared with the
input. Newly assembled object maps use schema-first field order.

Map-level callbacks receive a separate root map; that copy is shallow, so
unchanged nested values keep their ordinary Dart sharing semantics. Failed
outcomes retain independently assembled recovery maps. List parsing likewise
reuses a correctly typed unchanged list and copies when children change.
Map/list defaults and constraint collections are shallow snapshots.

Parent-bound recursive fields are available through `lazy`; see
[lazy schemas](lazy.md) for binding, operation ordering, async eligibility and
the benchmarked execution strategy.

## Migration scope

This is the first V2 replacement for the legacy combined `AcanthisMap`:
fixed fields belong to `ObjectSchema`, homogeneous entries to `RecordSchema`.
It includes traversal, presence policies, defaults, typed recovery, nested
diagnostics, and synchronous/asynchronous operations with dedicated tests.
Selected-field rules, field dependencies, request context, and cancellation are
available; see [cross-field rules](rules.md). Metadata, typed registries and
bounded mocks are covered in [metadata and mocks](metadata-and-mocks.md).
Object [live sessions](live.md) support incremental edits, revisions, and async debouncing. Shape helpers, deep partial/patch, property-count checks, and typed
passthrough are available. Native
list/object/record and recursive lazy export are supported by the strict
exporter; see [contracts](contracts.md). Eligible built-in trees use typed
validation/reuse without intermediate child outcomes; custom callbacks and
invalid inputs retain the ordinary diagnostic path. There is no compatibility
alias that conflates object and record behavior.
