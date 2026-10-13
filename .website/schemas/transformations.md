---
description: Convert input values, chain schemas, and provide recovery defaults.
---

# Transformations and defaults

Convert input values, chain schemas, and provide recovery defaults.

## Pipes

Pipes are a way to add custom transformation to a schema. They are useful when you want to transform a value from one type to another.

You can use the `pipe()` method to add a custom transformation function to a schema.

```dart
final name = string().pipe(number(), transform: (value) => int.parse(value));
```

The input schema runs first. Only a valid input reaches the mapper; its result
then passes through the output schema. A successful conversion alone does not
guarantee a successful pipeline:

```dart
final age = string().pipe(integer().gte(18), transform: int.parse);
age.parse('21'); // 21
age.tryParse('17').isValid; // false: output fails gte(18)
age.tryParse('hello').issues.first.code; // transform
```

A default attached to the pipeline is an output value. On missing/null input it
is validated by the output schema without running the input mapper.

## Default Values

Use `withDefault()` to replace missing/null input before validation and to supply
best-effort recovery output when a supplied value fails validation. These are
different outcomes: a valid replacement for null can succeed; recovery from
invalid input remains unsuccessful.

```dart
final name = string().min(2).max(100).withDefault('Unknown');
final invalid = name.tryParse('A') as AcanthisInvalid<String>;
print(invalid.value); // 'Unknown'; validation still failed
final valid = name.tryParse('Acanthis') as AcanthisValid<String>;
print(valid.value); // 'Acanthis'
```

`name.parse(null)` returns `'Unknown'` because the default satisfies the checks.
`name.parse('A')` throws because the supplied value fails. Defaults also undergo
validation: `string().min(2).withDefault('x')` fails on null input.
See the [presence/defaults table](/presence-and-defaults) for optional fields,
nullable values, and PATCH omission.

## Type Coercion

Type coercion allows you to automatically convert values from one type to another during validation. This can be useful when you want to ensure that your data conforms to a specific type without manually transforming it.

To enable type coercion, you can use the `coerce()` method on a schema. This method will attempt to convert the input value to the expected type before validation.

```dart
final ageSchema = number().coerce();

ageSchema.parse('25'); // ✅ returns 25 as a number
ageSchema.parse('25.5'); // ✅ returns 25.5 as a number
ageSchema.parse('invalid'); // ❌ throws ValidationError
```

### Accepted conversions

| Schema | Accepted input with coercion | Examples / limits |
| --- | --- | --- |
| `string().coerce()` | Strings, numbers, booleans, `DateTime` | Uses `toString()`; does not stringify arbitrary maps/lists |
| `number().coerce()` | Numbers; trimmed strings accepted by `num.tryParse` | `'25.5'` becomes `25.5`; booleans are rejected |
| `integer().coerce()` | Integers; finite whole numbers; trimmed numeric strings representing whole numbers | `'25.0'` becomes `25`; `25.5` is rejected rather than rounded |
| `doubleType().coerce()` | Doubles; finite numbers; trimmed strings parsing to finite doubles | `'25'` becomes `25.0` |
| `boolean().coerce()` | Booleans; numeric 0/1; trimmed, case-insensitive `'true'`, `'false'`, `'0'`, `'1'` | `' FALSE '` becomes `false`; `'yes'` and `2` are rejected |
| `date()` | `DateTime`, integer milliseconds since epoch, strings accepted by `DateTime.tryParse` | Date conversion is enabled by default; an integer is milliseconds, not seconds |

Coercion is not a finiteness check: values already of the requested numeric type
pass the conversion step unchanged. Add `.finite()` when needed. Date parsing
uses Dart's parser and timezone behavior; it does not force UTC. Null is handled
by nullable/default policies, not converted to the string `'null'` or boolean false.

### Execution order

Defaults for missing/null input are resolved before coercion. Coercion precedes
the schema's checks and transformations, which run in declaration order:

```dart
final trimmed = string().transform((value) => value.trim()).refine(
  onCheck: (value) => value.length >= 2,
  name: 'minLength',
  error: 'At least two characters',
);
trimmed.tryParse(' A ').isValid; // false: the check sees 'A'
final checkedFirst = string().min(2).transform((value) => value.trim());
checkedFirst.parse(' A '); // 'A': min(2) checked the original string
```

Use a pipe when the transformed output must satisfy a separate schema.
Non-throwing parsing can collect multiple check failures; it is not a guarantee
that every later operation is skipped. A failed pipeline input does skip its
mapper and output stage. See [collection policies](/contextual-rules#collection-policies).

### Callback exceptions

| Callback | Failure behavior |
| --- | --- |
| `refine()` / `refineAsync()` | Thrown exceptions become failed checks using the configured error |
| `pipe(..., transform: ...)` | Mapper exceptions become a `transform` validation failure |
| `transform(...)` | Arbitrary callback exceptions propagate |
| Selected-field rule callbacks | Exceptions propagate as application errors |

`tryParse()` handles validation failures, not every application exception.
Use async entry points for async schemas. If a remote refinement should report a
service outage differently from an unavailable value, handle that distinction
explicitly in your service/UI instead of relying on the refinement's catch behavior.

### `coerce()` and Unions

When using `coerce()` with union types, the coercion will follow the order of the types defined in the union. The first type that can successfully coerce the value will be used.

```dart
final unionSchema = union([
  number().coerce(),
  string(),
]);

unionSchema.parse('42'); // ✅ returns 42 as a number
unionSchema.parse('hello'); // ✅ returns 'hello' as a string
unionSchema.parse(true); // ❌ throws ValidationError
```

---

[Browse all schemas](/defining-schemas) · [Understand validation results](/validation-results)
