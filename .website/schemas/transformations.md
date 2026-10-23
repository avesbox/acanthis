---
description: Transform values in order, compose typed pipelines, and control coercion and defaults.
---

# Transformations

## Same-type transforms

`.transform()` replaces the current value while keeping the schema's output type.

```dart
final name = string().transform((value) => value.trim()).min(2);
print(name.parse(' Ada ')); // Ada
print(name.validate(' A ')); // false
```

Checks and transforms run in declaration order. `string().min(2).trim()` checks the original length before trimming. Use `.transformAsync(CallbackAsyncTransform<T, T>(...))` and async parsing for asynchronous transformations.

## Pipes

`.pipe(target, transform: converter)` can change the output type. It validates the source, converts its parsed value once, then validates the target.

```dart
final age = string().trim().pipe(integer().gte(18), transform: int.parse);
final int value = age.parse(' 21 ');
print(value); // 21
print(age.validate('17')); // false: the target rejects it.
print(age.tryParse('hello').issues.first.code); // transform
```

A failed source skips the converter and target, even if it has typed recovery. A failed target keeps only correctly typed target recovery. Converters are synchronous; either schema stage can be async, in which case use async parsing.

### Pipeline defaults

```dart
final age = string().pipe(integer().gte(18), transform: int.parse).withDefault(21);
print(age.parse(null)); // 21
```

A pipeline default is an **output** value. It bypasses the source and converter on missing/null input, but still passes through the target and the pipeline's own operations.

## Default values

For ordinary native schemas, `.withDefault(value)` replaces missing/null input before normal validation.

```dart
final name = string().min(2).withDefault('Guest');
print(name.parse(null)); // Guest
print(name.validate('A')); // false
print(string().min(2).withDefault('x').validate(null)); // false
```

Defaults must pass their checks. Supplied invalid input is not replaced. [Presence and defaults](/presence-and-defaults) explains omitted object fields and PATCH behavior.

## Type coercion

Enable `.coerce()` to accept the schema's supported conversions before checks and transformations.

```dart
final count = integer().coerce().positive();
print(count.parse('3')); // 3
print(count.validate('3.5')); // false
```

### Accepted conversions

| Schema | Additional accepted input |
| --- | --- |
| `string().coerce()` | Numbers, booleans, and `DateTime`, using `toString()` |
| `number().coerce()` | Trimmed strings accepted by `num.tryParse` |
| `integer().coerce()` | Finite whole numbers and numeric strings representing whole numbers |
| `doubleType().coerce()` | Finite numbers and strings parsing to finite doubles |
| `boolean().coerce()` | Numeric 0/1; trimmed, case-insensitive strings true/false/0/1 |
| `date().coerce()` | Numeric milliseconds since the epoch; date strings already work with `date()` |

Coercion does not stringify arbitrary maps or lists. Null follows the nullable/default policy. Already correctly typed numeric values bypass conversion; add `.finite()` when required. Date parsing follows Dart's parser and timezone behavior.

### Execution order

Missing/null defaults resolve first, then coercion, then declared checks and transforms. A pipe introduces a new source/converter/target boundary. Collecting parsing stops at a transform after a failure; [collection policies](/contextual-rules#collection-policies) can stop earlier.

### `coerce()` and unions {#coerce-and-unions}

```dart
final value = union<Object?>([number().coerce(), string()]);
print(value.parse('42')); // 42, a number.
print(value.parse('hello')); // hello, a string.
```

The first successful plain branch supplies the result. Put the branch whose conversion you prefer first.

## Callback exceptions

| Callback | Behavior when it throws |
| --- | --- |
| Pipeline converter | `FormatException` becomes a `transform` issue; other exceptions propagate |
| Refinement, transform, rule, getter, or factory | Exceptions propagate |

`tryParse()` handles validation failures; it does not catch every application error. Handle service failures explicitly when they need a different UI response from invalid input. Native pipelines and arbitrary transformations are rejected by [strict export](/export-compatibility).

Built-in decoding transforms can report malformed encoded input as a `transform` issue. This does not make arbitrary exceptions from application transforms into validation failures.
