---
description: Build an immutable catalog of schemas and retrieve them through canonical typed keys.
---

# Schema registries

A schema registry gives an application explicit, typed access to shared schemas. Define canonical keys in the module that owns the contract, then import those keys wherever you need the schema.

## Register and retrieve

```dart
const accountKey = SchemaKey<Map<String, Object?>, ObjectSchema>('account');

final builder = SchemaRegistryBuilder()
  ..add(accountKey, object({'email': string().email()}));
final registry = builder.build();

final ObjectSchema account = registry.get(accountKey);
final Map<String, Object?> value = account.parse({'email': 'ada@example.com'});
print(value['email']); // ada@example.com
```

`SchemaKey<Output, SchemaType>` preserves the parsed type and the concrete schema type. `registry.get(accountKey)` retains object helpers such as `.pick()` and `.patch()`.

## Lookup behavior

| API | Behavior |
| --- | --- |
| `get(key)` | Returns the schema or throws for a missing binding |
| `find(key)` | Returns null for an absent ID |
| `contains(key)` | Checks canonical token identity |
| `entries` | Iterates insertion-ordered, read-only bindings |

Keys use canonical token identity, not only the string ID. A conflicting token with an existing ID throws even through `find()`. IDs must match `[A-Za-z_][A-Za-z0-9_.-]*`. Duplicate IDs, tokens, schema identities, and incompatible bindings throw `SchemaRegistryException` during setup.

## Compose modules

Build a registry in each module, then import its bindings with `builder.addAll(moduleRegistry)`. A failed import leaves the builder unchanged. `build()` snapshots bindings; later builder edits do not affect an existing registry.

Registration and lookup do not parse, mock, export, or run validation callbacks. Bindings are immutable, but captured application state is not deep-frozen. Each application or isolate owns its registry. No global schema catalog is created automatically, and schema registration does not add metadata entries.

The repository's `example/schema_registry/` directory shows contracts shared across modules. See [metadata](/metadata) for descriptive annotations and the separate metadata registry.
