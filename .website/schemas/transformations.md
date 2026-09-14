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

## Default Values

To provide a default value for a schema, you can use the `withDefault()` method. This method allows you to specify a value that will be used if the validation operations fail.

```dart
final name = string().min(2).max(100).withDefault('Unknown');
name.tryParse('A').value; // 'Unknown' (the result is still unsuccessful)
name.tryParse('Acanthis').value; // 'Acanthis'
```

::: warning
This behavior is available only when using `tryParse()` or `tryParseAsync()`. When using `parse()` or `parseAsync()`, a `ValidationError` will be thrown if the validation fails regardless of the default value.
:::

## Type Coercion

Type coercion allows you to automatically convert values from one type to another during validation. This can be useful when you want to ensure that your data conforms to a specific type without manually transforming it.

To enable type coercion, you can use the `coerce()` method on a schema. This method will attempt to convert the input value to the expected type before validation.

```dart
final ageSchema = number().coerce();

ageSchema.parse('25'); // ✅ returns 25 as a number
ageSchema.parse('25.5'); // ✅ returns 25.5 as a number
ageSchema.parse('invalid'); // ❌ throws ValidationError
```

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
