---
description: Allow null explicitly and distinguish it from an absent object field.
---

# Nullable values

Allow null explicitly and distinguish it from an absent object field.

## Nullables

Use the `nullable()` method to create a nullable schema. This method allows you to validate and transform nullables.

Nullables are a bit special in Acanthis. They are not a type, but a modifier. You can use them with any type to make it nullable.

```dart
string().nullable(defaultValue: 'default');
number().nullable(defaultValue: 5);
boolean().nullable(defaultValue: true);
date().nullable(defaultValue: DateTime.now());
...
```

You can also validate the nullable type.

```dart
string().nullable().enumerated(['Acanthis', 'Dart']);
```

::: info
At the enumerated list will be added `null` and the default value if provided.
:::

---

[Browse all schemas](/defining-schemas) · [Understand validation results](/validation-results)
