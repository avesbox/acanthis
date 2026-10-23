---
description: Generate typed, validated samples from supported schema constraints.
---

# Mock data

## `mock()` {#mocking-schemas}

Generate a validated sample from supported constraints. `.mock()` chooses a fresh random seed.

```dart
final account = object({
  'name': string().min(3).max(12),
  'age': integer().gte(18).lte(65),
  'email': string().email(),
});
final Map<String, Object?> sample = account.mock();
print(account.validate(sample)); // true
```

Unsupported schemas, contradictory constraints, or exhausted budgets throw `AcanthisMockException`. Generation is bounded and never returns a candidate known to fail validation.

## Repeat a sample {#seeded-test-data}

```dart
final score = integer().gte(0).lte(100);
print(score.mockSeeded(seed: 42) == score.mockSeeded(seed: 42)); // true
```

`.mock(42)` is an alias for `.mockSeeded(seed: 42)`. Reproducibility requires the same schema, library version, SDK, limits, generators, and deterministic callbacks. See [seeded mocking](/seeded-mocking) for budgets and custom generators.

## Instances and pipelines

An instance schema needs an explicit factory. It receives generated, parsed field values.

```dart
class User {
  const User(this.name);
  final String name;
}

final user = instance<User>()
    .field('name', (value) => value.name, string().min(2).max(12))
    .withFactory((fields) => User(fields['name'] as String));
final User sample = user.mockSeeded(seed: 42);
print(user.validate(sample)); // true
```

Synchronous pipelines and class schemas generate source input, convert it, then validate the output. Output is not reparsed as source input because the types can differ. Nested pipelines are supported in objects and collections. Factories, getters, mappers, and validation callbacks must be deterministic for reproducible samples.

Async schemas and lazy resolvers are unsupported, including with generator overrides. Use an explicit finite source shape for recursive fixtures.
