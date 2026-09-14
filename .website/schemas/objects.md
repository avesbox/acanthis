---
description: Validate named fields, control unknown keys, and compose reusable object schemas.
---

# Objects {#object-schemas}

Validate named fields, control unknown keys, and compose reusable object schemas.

## Define an object {#objects}

Use the `object()` method to create an object schema. This method allows you to validate and transform objects.

With objects Acanthis refers to `Map<String, dynamic>` or `Map<String, Object?>` or so called json-encodeable types.

```dart
object({
  'name': string().min(3),
  'age': number().positive(),
});
```

By default, all declared properties are required and unknown properties are
stripped from the parsed output. A missing property is different from an
explicit `null`: use `nullable()` when a field may be present with null.

When validation does not change the data, pure object schemas can return the
original input map as `result.value`. This includes schemas with validation
checks, provided they do not transform or coerce values or apply defaults.
Unknown-key stripping still creates an output map when needed. Pure typed
lists can likewise return the original list.

```dart
final schema = object({'name': string().min(1)});
final input = {'name': 'Ada'};
final result = schema.parse(input);
print(identical(result.value, input)); // true
```

The input and returned value may therefore share identity: mutations through
either reference are visible through the other, and read-only input remains
read-only. Use `Map<String, dynamic>.of(result.value)` if you need an independent,
mutable outer map. Async validation may also reuse unchanged input; schemas
that change values retain their transformed output. Parsing still returns an
`AcanthisParseResult`, so access the data through `.value`.

To add optional properties, you can use the `optionals()` method.

```dart
object({
  'name': string().min(3),
  'age': number().positive(),
  'email': string().email(),
}).optionals([
  'email',
]);
```

To define a loose object schema, instead, you can use the `passthrough()` method.

```dart
object({
  'name': string().min(3),
  'age': number().positive(),
}).passthrough();
```

This will allow any additional properties to be present in the object without validation.

To the passthrough method can be passed a type to validate the additional properties.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
}).passthrough(type: string());

person.parse({
  'name': 'Acanthis',
  'age': 5,
  'email': 'test@example.com'
}); // ✅

person.parse({
  'name': 'Acanthis',
  'age': 5,
  'email': 5
}); // ❌ throws ValidationError

```

Also, Acanthis provides some built-in validators for object validation:

```dart
object({}).maxProperties(5);
object({}).minProperties(5);
```

### `extend()`

To add additional properties to the object schema, you can use the `extend()` method.

```dart
object({
  'name': string().min(3),
  'age': number().positive(),
}).extend({
  'email': string().email(),
});
```

::: warning
The `extend()` method will not overwrite the existing properties. It will only add the new properties to the schema if they do not already exist.
:::

### `merge()`

To merge two object schemas, you can use the `merge()` method.

```dart
object({
  'name': string().min(3),
  'age': number().positive(),
}).merge({
  'email': string().email(),
});
```

::: warning
The `merge()` method will overwrite the existing properties.
:::

### `pick()`

To pick specific properties from the object schema to create a new schema, you can use the `pick()` method.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
});

final personWithoutAge = person.pick(['name']);
```

### `omit()`

To omit specific properties from the object schema to create a new schema, you can use the `omit()` method.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
});

final personWithoutName = person.omit(['name']);
```

### `partial()`

The `partial()` method makes every field optional. Missing fields stay absent, including fields with defaults. A supplied value still has to pass its original schema; use `nullable()` separately to accept explicit null.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
});

final personPartial = person.partial();
```

Set `deep: true` to apply this policy to directly nested object schemas. `patch()` is an alias for `partial()`.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
  'address': object({
    'city': string().min(3),
    'country': string().min(3),
  })
});

final personPartial = person.partial(deep: true);
```

## Recursive Objects

Sometimes you need to validate recursive objects. For example, a tree structure or a linked list. Acanthis provides a way to do this using the `lazy()` method.

```dart
final tree = object({
  'value': number(),
  'children': lazy((parent) => parent.list()),
});
```

---

[Browse all schemas](/defining-schemas) · [Understand validation results](/validation-results)
