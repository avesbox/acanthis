---
description: Add synchronous or asynchronous rules when built-in checks are not enough.
---

# Custom validation

Add synchronous or asynchronous rules when built-in checks are not enough.

## Refinements

Refinements are a way to add custom validation to a schema. You can use the `refine()` method to add a custom validation function to a schema.

::: warning
Refinement callbacks should return a boolean. Exceptions from application callbacks are not converted into validation issues.
:::

### `refine()`

To add a custom sync validation function to a schema, you can use the `refine()` method.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
}).refine(onCheck: (value) => value['age'] > 4, error: 'Age is lower than 4', name: 'ageCheck');
```

### `refineAsync()`

To add a custom async validation function to a schema, you can use the `refineAsync()` method.

```dart
final person = object({
  'name': string().min(3),
  'age': number().positive(),
}).refineAsync(onCheck: (value) async => value['age'] > 4, error: 'Age is lower than 4', name: 'ageCheck');
```

---

[Browse all schemas](/defining-schemas) · [Understand validation results](/validation-results)
