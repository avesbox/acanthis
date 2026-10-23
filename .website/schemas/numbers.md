---
description: Validate numbers, booleans, and dates with explicit input conversions.
---

# Numbers, booleans, and dates

## Numbers {#numeric-values}

Choose the Dart output type you need.

```dart
final num amount = number().parse(12.5);
final int count = integer().parse(3);
final double ratio = doubleType().parse(0.5);
```

`integer()` accepts Dart `int` values; `doubleType()` accepts Dart `double` values. `number()` accepts both. An `integer()` schema rejects `3.0` unless coercion is enabled.

### Bounds and choices

```dart
number().gte(0); // Inclusive lower bound.
number().lte(100); // Inclusive upper bound.
number().gt(0);
number().lt(100);
number().between(0, 100); // Both bounds inclusive.
number().positive();
number().negative();
number().nonNegative();
number().nonPositive();
number().multipleOf(5); // Nonzero integer divisor.
number().exact(42);
number().enumerated([1, 2, 3]); // A nonempty list of choices.
```

### Numeric properties

```dart
number().integer();
number().double();
number().finite();
number().infinite();
number().nan();
number().notNaN();
```

`.integer()` and `.double()` on a number schema check its runtime representation; the output remains `num`. Use the corresponding factory for typed `int` or `double` output. Add `.finite()` when non-finite values must be rejected.

### Conversion

```dart
print(integer().coerce().parse('3.0')); // 3
print(doubleType().coerce().parse('3')); // 3.0
print(number().pow(2).parse(4)); // 16
```

Coercion rejects fractional values for `integer()` rather than rounding them. See the [conversion table](/schemas/transformations#accepted-conversions) for accepted inputs.

## Booleans

`boolean()` accepts only `true` and `false`. Add a check to require one of them.

```dart
boolean().isTrue();
boolean().isFalse();
print(boolean().coerce().parse(' FALSE ')); // false
```

Boolean coercion also accepts numeric `0`/`1` and trimmed, case-insensitive strings `'true'`, `'false'`, `'0'`, and `'1'`. It rejects `'yes'` and other numbers.

## Dates

`date()` accepts `DateTime` values and strings accepted by `DateTime.tryParse`. Its output is a `DateTime`.

```dart
final birthday = date().max(DateTime.utc(2026, 1, 1));
final DateTime value = birthday.parse('2000-12-10T00:00:00Z');
print(value.year); // 2000
```

### Bounds and distance

```dart
final reference = DateTime.utc(2026, 1, 1);
date().min(reference); // Inclusive.
date().max(reference); // Inclusive.
date().differsFrom(reference, const Duration(days: 5));
date().differsFromNow(const Duration(days: 5));
```

Difference checks compare absolute duration. Parsing follows Dart's date parsing and timezone behavior; it does not force UTC or add stricter calendar-string validation.

### Timestamps

```dart
final DateTime epoch = date().coerce().parse(0);
print(epoch.millisecondsSinceEpoch); // 0
```

Numeric input requires `.coerce()` and is interpreted as milliseconds since the epoch. Fractional milliseconds are truncated. Non-finite values and timestamps outside ±8,640,000,000,000,000 fail validation with a type issue.

Native date schemas are not JSON-exportable. Use an explicit JSON boundary contract when sharing dates with other systems.
