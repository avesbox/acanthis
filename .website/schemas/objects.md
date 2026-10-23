---
description: Validate named fields, choose an unknown-key policy, and derive reusable object shapes.
---

# Objects {#object-schemas}

## `object()` {#objects}

An object schema parses a map with named string keys. Its output is `Map<String, Object?>`.

```dart
final account = object({
  'name': string().min(2),
  'age': integer().gte(18),
});
print(account.parse({'name': 'Ada', 'age': 28, 'extra': true}));
// {name: Ada, age: 28}
```

Fields are required by default. Unknown keys are stripped. Each nested object has its own policies.

## Optional fields

```dart
final account = object({
  'name': string(),
  'nickname': string().nullable(),
}).optionals(['nickname']);

print(account.parse({'name': 'Ada'})); // {name: Ada}
print(account.parse({'name': 'Ada', 'nickname': null}));
// {name: Ada, nickname: null}
```

`.optionals()` permits omission. `.nullable()` permits a supplied null. Defaults can fill omitted fields. See the [presence table](/presence-and-defaults) before choosing a policy.

## Unknown keys

```dart
final base = object({'name': string()});
final strict = base.unknownKeys(AcanthisUnknownKeys.reject);
final loose = base.passthrough();
final typedExtras = base.passthrough(type: string());

print(strict.validate({'name': 'Ada', 'team': 'research'})); // false
print(loose.parse({'name': 'Ada', 'active': true}));
// {name: Ada, active: true}
print(typedExtras.validate({'name': 'Ada', 'active': true})); // false
```

`unknownKeys(AcanthisUnknownKeys.preserve)` preserves extras without a child schema. `strip` restores the default policy. Typed passthrough validates only the additional properties.

## Shape helpers

Each helper returns a new object schema and retains applicable configuration, metadata, and rules.

### `extend()`

Add fields while keeping existing definitions on a name collision.

```dart
final account = object({'name': string()});
final extended = account.extend({'name': integer(), 'email': string().email()});
// name still uses string().
```

### `merge()`

Add fields and replace colliding definitions with the supplied definitions.

```dart
final account = object({'name': string()});
final merged = account.merge({'name': string().min(3)});
```

### `pick()`

Keep selected fields in the requested order. Unknown names are ignored.

```dart
final account = object({'name': string(), 'age': integer()});
final publicName = account.pick(['name']);
```

### `omit()`

Remove selected fields.

```dart
final account = object({'name': string(), 'password': string()});
final publicAccount = account.omit(['password']);
```

### `partial()`

Make fields optional and preserve omission, including for fields with defaults. `.patch()` is an alias.

```dart
final patch = object({
  'name': string().withDefault('Guest'),
  'nickname': string().nullable(),
}).partial();
print(patch.parse({})); // {}
print(patch.parse({'nickname': null})); // {nickname: null}
```

Supplied values still follow their child schemas. `partial(deep: true)` applies the policy to direct nested objects. It does not make list elements into patches.

Shape helpers reject a resulting schema if a declared rule path no longer exists. Add [cross-field rules](/contextual-rules) after deriving your shape.

## Property counts

```dart
object({}).passthrough().minProperties(1).maxProperties(5);
object({}).passthrough().lengthProperties(2);
```

Counts apply to the parsed map, after child defaults and unknown-key handling.

## Recursive objects

`lazy()` receives the containing object schema. Use it for a recursive field.

```dart
final tree = object({
  'name': string(),
  'children': lazy((parent) => parent.list()),
});

print(tree.validate({
  'name': 'root',
  'children': [{'name': 'leaf', 'children': <Object?>[]}],
})); // true
```

The resolver is bound to the parent and reused. Keep definitions deterministic. Automatic binding applies to direct object fields; a standalone lazy definition must be bound explicitly with `definition(parent)`. Async child schemas require async parsing. Recursive export supports local references; mock generation does not support lazy schemas.

## Input reuse

Unchanged typed maps can be returned directly, including when checks run.

```dart
final input = <String, Object?>{'name': 'Ada'};
final output = object({'name': string()}).parse(input);
print(identical(input, output)); // true
final independent = Map<String, Object?>.of(output);
```

Mutations can be visible through both references, and read-only input can produce read-only output. A change such as stripping, a default, coercion, or transformation copies the affected ancestors. `Map.of()` creates an independent outer map; it does not deep-copy nested values. Typed lists can also reuse their input.
