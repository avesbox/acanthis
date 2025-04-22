# Basic Usage

This page will walk you through the basics of creating and using schemas with Acanthis. We will cover the following topics:

- Creating a schema
- Parsing data

For the complete Acanthis schema API, please refer to [Defining schemas](./defining_schemas.md).

## Defining a schema

A schema is a blueprint for validating data, before we do anything else, we need to define one. For this example, we will create a schema for a user object.

```dart
import 'package:acanthis/acanthis.dart';

final userSchema = object({
  'name': string().min(3),
  'age': number().positive(),
  'email': string().email(),
});
```

## Parsing data

Once we have defined a schema, we can use it to parse data.

### `parse()`

`T parse(T value)`

Parses the value and returns a new instance of parsed value of type `T`.

```dart
userSchema.parse({
  'name': 'Francesco',
  'age': 32,
  'email': 'test@example.com',
});
// => { name: Francesco, age: 32, email: test@example.com }
```

If the value is invalid a `ValidationError` will be thrown.

```dart
userSchema.parse({
  'name': 'Francesco',
  'age': -32,
  'email': 'test@example.com',
});
// => ValidationError: {'age': 'Value must be positive'}
```

::: info
If you use any of the `AsyncCheck`, then you need to use the `parseAsync` method instead of `parse`.
:::

### `tryParse()`

`AcanthisParseResult tryParse(T value)`

To avoid throwing exceptions, you can use the `tryParse` method. This method will return an `AcanthisParseResult` object that contains the result of the parsing.

```dart
userSchema.tryParse({
  'name': 'Francesco',
  'age': 32,
  'email': 'test@example.com',
});
// => AcanthisParseResult(success: true, value: { name: Francesco, age: 32, email: test@example.com }, errors: {}, metadata: null)

userSchema.parse({
  'name': 'Francesco',
  'age': -32,
  'email': 'test@example.com',
});
// => AcanthisParseResult(success: false, value: null, errors: { age: 'Value must be positive' }, metadata: null)
```

::: info
If you use any of the `AsyncCheck`, then you need to use the `tryParseAsync` method instead of `tryParse`.
:::

### `parseAsync()`

`Future<T> parseAsync(T value)`

This method behaves exactly like `parse`, but it returns a `Future` that resolves to the parsed value.

```dart
userSchema.parseAsync({
  'name': 'Francesco',
  'age': 32,
  'email': 'test@example.com',
});
// => Future<{ name: Francesco, age: 32, email: test@example.com }>
```

### `tryParseAsync()`

`Future<AcanthisParseResult> tryParseAsync(T value)`

This method behaves exactly like `tryParse`, but it returns a `Future` that resolves to the `AcanthisParseResult` object.

```dart
userSchema.tryParseAsync({
  'name': 'Francesco',
  'age': 32,
  'email': 'test@example.com',
});
// => Future<AcanthisParseResult(success: true, value: { name: Francesco, age: 32, email: test@example.com }, errors: {}, metadata: null)>
```

Now that the basics are covered, you can now jump to the [Defining schemas](./defining_schemas.md) page to learn more about all the validators usable in your schemas.
