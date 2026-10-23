---
description: Validate existing Dart instances or map validated input into a class.
---

# Instances and classes

## `instance<T>()` {#instances}

Validate an existing Dart object with getters. A successful parse returns the same instance unless you add a root transformation.

```dart
class User {
  const User(this.name, this.age, this.email);
  final String name;
  final int age;
  final String? email;
}

final user = instance<User>()
    .field('name', (value) => value.name, string().min(2))
    .field('age', (value) => value.age, integer().gte(18))
    .field('email', (value) => value.email, string().email(), optional: true);

final input = User('Ada', 28, null);
print(identical(user.parse(input), input)); // true
```

An optional getter returning null skips its child schema, including any child default. A required nullable getter can instead use a nullable child schema.

Each field runs its full schema. Child transformations validate their result but do not write it back to the instance. Issues retain the field path and the child check's code. Async children require async entry points. Inputs of unrelated types fail before getters run.

### Choosing an object schema {#differences-to-object}

| Input | Schema | Output |
| --- | --- | --- |
| A map with named fields | `object({...})` | `Map<String, Object?>` |
| An existing Dart instance | `instance<T>()` | `T` |
| Data that should construct an instance | `classSchema<I, T>()` | `T` |

## Cross-field validation with refs

Register getter references once, then read them from a refinement.

```dart
class Order {
  const Order(this.quantity, this.price);
  final int quantity;
  final double price;
}

final order = instance<Order>()
    .field('quantity', (value) => value.quantity, integer().positive())
    .field('price', (value) => value.price, doubleType().positive())
    .withRefs((refs) => refs
      .ref<int>('quantity', (value) => value.quantity)
      .ref<double>('price', (value) => value.price))
    .refineWithRefs(
      (_, refs) => refs<int>('quantity') * refs<double>('price') <= 1000,
      'Total exceeds the order limit',
      name: 'orderLimit',
    );
print(order.validate(Order(2, 20))); // true
```

`refineWithCause()` accepts a callback returning null for success or a message for failure. References read the instance's getter values. For rules over parsed map fields and incremental scheduling, use [object rules](/contextual-rules).

## Class schemas

`classSchema<I, T>()` validates input, maps it to `T`, then validates the mapped output.

```dart
class User {
  const User(this.name, this.age);
  final String name;
  final int age;
}

final user = classSchema<Map<String, Object?>, User>()
    .input(object({'name': string().min(2), 'age': integer()}))
    .map((data) => User(data['name'] as String, data['age'] as int))
    .validateWith(instance<User>()
      .field('age', (value) => value.age, integer().gte(18)))
    .build();

final User parsed = user.parse({'name': 'Ada', 'age': 28});
print(parsed.name); // Ada
```

`input()` and `map()` are required. `validateWith()` is optional; without it, the output is checked as an instance of `T`. `.refine()` adds an output check. `.defaultOutput(value)` supplies an output default for missing/null input, bypassing the source and mapper while still validating the output. `build()` snapshots the builder as a [pipeline](/schemas/transformations#pipes).

## Field helpers, export, and mocks

`instanceSchema.toMap(value)` reads declared raw getter values. It neither validates nor recursively serializes the instance.

Field-based JSON/OpenAPI export describes the declared JSON representation without invoking getters or constructors. It does not make an instance schema accept a decoded map. Each field must satisfy [strict export](/export-compatibility).

For mock construction, attach `.withFactory((fields) => User(...))` to the instance schema. The factory receives generated, parsed field values. See [mock data](/schemas/mocking#instances-and-pipelines).
