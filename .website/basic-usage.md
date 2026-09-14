---
title: Quick start
description: Define your first Acanthis schema, validate input, and handle errors in Dart.
---

# Your first validation {#basic-usage}

Build a small account schema, validate an input, and handle both success and failure. [Install Acanthis](/introduction#installation) before you begin.

## Define a schema {#defining-a-schema}

Start with an object. Each key describes a field, and each field has its own schema and checks.

```dart
import 'package:acanthis/acanthis.dart';

final account = object({
  'name': string().min(2),
  'email': string().email(),
  'age': integer().gte(18),
});
```

This schema expects a name with at least two characters, an email address, and an integer age of 18 or more. Object fields are required by default; unknown keys are stripped. See [objects](/schemas/objects) for optional fields and passthrough behavior.

## Validate input {#parsing-data}

Use `tryParse()` when invalid data is an expected part of your workflow, such as a user filling in a form.

```dart
final result = account.tryParse({
  'name': 'Ada',
  'email': 'ada@example.com',
  'age': 28,
});

if (result.success) {
  print(result.value['name']); // Ada
} else {
  for (final issue in result.issues) {
    print('${issue.jsonPointer}: ${issue.message}');
  }
}
```

`tryParse()` returns an `AcanthisParseResult`. Check `success` before treating its `value` as valid data: a failed result can still contain a recovery value.

## Handle invalid data

Each issue identifies the field that failed and the reason. Use the typed path or JSON pointer to associate messages with your UI.

```dart
final invalid = account.tryParse({
  'name': 'Ada',
  'email': 'not-an-email',
  'age': 28,
});

print(invalid.success); // false
print(invalid.issues.first.jsonPointer); // /email
print(invalid.issues.first.code); // email
```

For custom messages or localization, continue to [custom error messages](/error-customization) and [results and issues](/validation-results).

## Choose a parsing method

| When you need… | Use | On invalid input |
| --- | --- | --- |
| A result you can inspect | `tryParse(input)` | Returns an unsuccessful result with issues |
| Validation to stop the operation | `parse(input)` | Throws `ValidationError` |
| Typed success and failure branches | `validate(input)` | Returns `AcanthisInvalid` |
| Any of the above with async checks | `tryParseAsync`, `parseAsync`, or `validateAsync` | Same behavior, wrapped in a `Future` |

### `parse()`

Read the validated data from `.value`. `parse()` returns a result wrapper, not the raw value.

```dart
try {
  final result = account.parse({
    'name': 'Ada',
    'email': 'not-an-email',
    'age': 28,
  });
  print(result.value);
} on ValidationError catch (error) {
  print(error.message);
}
```

### `tryParse()`

Use the result’s `success`, `value`, and `issues` fields as shown above. `errors` is also available for compatibility; [structured issues](/validation-results#structured-diagnostics) preserve more detail.

### `parseAsync()`

Schemas with async refinements require an async parsing method. Awaiting `parseAsync()` returns an `AcanthisParseResult`, just like `parse()`.

```dart
final name = string().refineAsync(
  onCheck: (value) async => value != 'admin',
  name: 'reservedName',
  error: 'Choose a different name',
);

final result = await name.parseAsync('Ada');
print(result.value); // Ada
```

### `tryParseAsync()`

Use this to collect validation issues from a schema with async checks.

```dart
final result = await name.tryParseAsync('admin');
print(result.success); // false
```

::: tip Async checks
Calling a synchronous parsing method on a schema with async checks throws `AsyncValidationException`. Non-throwing parsing handles validation failures; it does not suppress arbitrary exceptions from your callbacks.
:::

## Keep going

<div class="doc-cards">
<a href="/defining-schemas.html"><strong>Build richer schemas →</strong><span>Explore objects, lists, unions, and custom checks.</span></a>
<a href="/validation-results.html"><strong>Work with results →</strong><span>Use typed outcomes, issue paths, and formatters.</span></a>
</div>
