---
description: Choose a primitive schema and add the constraints your data needs.
---

# Numbers, booleans, and dates

Choose a primitive schema and add the constraints your data needs.

## Numeric values

Acanthis provides three types to represent numeric values: `AcanthisNumber`, `AcanthisInt` and `AcanthisDouble`. They share the same fluent checks.

Use the `number()` function or the `integer()` or `doubleType()` functions to create a number schema. This method allows you to validate and transform numbers.

```dart
number().gt(5);
number().gte(10);
number().lt(5);
number().lte(10);
number().positive();
number().negative();
number().nonNegative();
number().nonPositive();
number().multipleOf(5);
number().integer();
number().double();
number().nonNan();
number().nan();
number().finite();
number().infinite();
number().enumerated([1, 2, 3]);
number().exact(5);
```

To perform simple transformations:

```dart
number().pow(2);
```

## Booleans

Use the `boolean()` method to create a boolean schema. This method allows you to validate and transform booleans.

```dart
boolean().isTrue();
boolean().isFalse();
```

## Dates

Use the `date()` method to create a date schema. This method allows you to validate and transform dates.

```dart
date().min(DateTime.now());
date().max(DateTime.now());
date().differsFromNow(Duration(days: 5));
date().differsFrom(DateTime.now(), Duration(days: 5));
```

---

[Browse all schemas](/defining-schemas) · [Understand validation results](/validation-results)
