---
description: Validate existing Dart instances and describe class fields.
---

# Instances and classes

Validate existing Dart instances and describe class fields.

## Instances

Use `instance<T>()` to validate already constructed Dart objects (class instances) without converting them to `Map`.  
You attach field validators via getters. Read the original instance from `result.value`; field validators do not rewrite the instance’s properties.

```dart
class User {
  final String name;
  final int age;
  final String? email;
  User(this.name, this.age, this.email);
}

final userSchema = instance<User>()
  .field('name', (u) => u.name, string().min(3))
  .field('age', (u) => u.age, number().positive())
  .field('email', (u) => u.email, string().email(), optional: true);

userSchema.parse(User('Alice', 30, null)); // ✅
userSchema.parse(User('A', 30, null));     // ❌ ValidationError (name.min)
```

::: info
A field flagged as optional will be skipped if the getter returns `null`.
:::

### Differences to `object()`

- `object()` validates `Map` data (often decoded JSON).  
- `instance()` validates real Dart objects via property getters.

### Cross-field validation with refs

Define reusable references, then create a refinement that can access them.

```dart
class Order {
  final int quantity;
  final double unitPrice;
  Order(this.quantity, this.unitPrice);
}

final orderSchema = instance<Order>()
  .field('quantity', (o) => o.quantity, number().positive())
  .field('unitPrice', (o) => o.unitPrice, number().positive())
  .withRefs((r) => r
    .ref<int>('qty', (o) => o.quantity)
    .ref<double>('price', (o) => o.unitPrice)
  )
  .refineWithRefs(
    (o, refs) => refs<int>('qty') * refs<double>('price') <= 1000,
    'Total exceeds limit',
    name: 'totalLimit',
  );
```

`refineWithRefs` supplies a `RefAccessor` so you can read previously registered references by name and perform cross-field logic.

## Class Schemas

Use `classSchema<I, T>()` to build a typed pipeline that validates the input shape (I), maps the validated input into a class (T) via a pure mapper.

```dart
class User {
  final String name;
  final int age;
  User(this.name, this.age);
}

final buildUser = classSchema<Map<String, dynamic>, User>()
  .input(object({
    'name': string().min(3),
    'age': integer().positive(),
  }))
  .map((data) => User(data['name'] as String, data['age'] as int))
  .validateWith(
    instance<User>()
      .field('name', (u) => u.name, string().max(50))
      .field('age', (u) => u.age, number().gte(18)),
  )
  .build();

final user = buildUser.parse({
  'name': 'Alice',
  'age': 30,
}).value; // User instance
```

::: info
You can also validate the result of the mapping using `validateWith` and an `instance()` schema.
:::

---

[Browse all schemas](/defining-schemas) · [Understand validation results](/validation-results)
