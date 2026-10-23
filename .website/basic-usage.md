---
title: Quick start
description: Define a schema, parse input, and handle validation issues.
---

# Quick start {#basic-usage}

This page covers the core workflow. [Install Acanthis](/introduction#installation), then import the package:

```dart
import 'package:acanthis/acanthis.dart';
```

## Define a schema {#defining-a-schema}

An object schema assigns a schema to each named field.

```dart
final account = object({
  'name': string().min(2),
  'email': string().email(),
  'age': integer().gte(18),
});

final Map<String, Object?> value = account.parse({
  'name': 'Ada',
  'email': 'ada@example.com',
  'age': 28,
});
print(value['name']); // Ada
```

All three fields are required. Unknown keys are stripped from the output. [Objects](/schemas/objects) explains how to change either policy.

## Parse data {#parsing-data}

`parse()` returns the parsed value. Invalid input throws `ValidationError`.

```dart
final age = integer().gte(18);
final int accepted = age.parse(28);

try {
  age.parse(16);
} on ValidationError catch (error) {
  print(error.issues.first.code); // gte
}
```

Use `tryParse()` when you want to handle invalid input as a result. It collects issues and returns `AcanthisOutcome<T>`.

```dart
final account = object({'email': string().email()});
final result = account.tryParse({'email': 'invalid'});

if (result.isValid) {
  print(result.value); // Parsed output is available here.
} else {
  print(result.issues.formatFields()); // Messages grouped under /email.
}
```

An invalid result may contain recovery data that still fails validation. Read `.value` after a successful result; see [recovery values](/validation-results#recovery-values) for advanced use.

## Check validity

`validate()` returns a boolean and stops at the first failure.

```dart
final email = string().email();
print(email.validate('ada@example.com')); // true
print(email.validate('invalid')); // false
```

Use `tryParse()` when you also need messages. Flutter's `FormField.validator` expects `String?`, so adapt the result:

```dart
final email = string().email();

String? validateEmail(String? input) {
  final result = email.tryParse(input);
  return result.isValid ? null : result.issues.first.message;
}
```

Pass `validateEmail` to `TextFormField(validator: validateEmail)`. For async checks and several related fields, follow the [Flutter live-form recipe](/flutter-live-form).

<span id="flutter-textformfield"></span>

## Transform values

Checks and transformations run in the order you add them. Use `pipe()` to change the output type.

```dart
final age = string().trim().pipe(integer().gte(18), transform: int.parse);
final int value = age.parse(' 21 ');
print(value); // 21
print(age.tryParse('hello').issues.first.code); // transform
```

The source must pass before the converter runs. The target then validates the converted value. Read [transformations](/schemas/transformations) for coercion and defaults.

## Validate asynchronously {#async-validation}

Add an async check with `refineAsync()`, then use an async entry point.

```dart
final username = string().min(3).refineAsync(CallbackAsyncCheck(
  (value, context) async {
    // Replace this demonstration with an availability service.
    final available = await Future.value(value != 'admin');
    if (!available) context.addIssue('usernameTaken');
  },
));

final result = await username.tryParseAsync('admin');
print(result.isValid); // false
```

`parseAsync()` returns `Future<T>` and throws on failure. Sync parsing of an async schema throws `StateError`. Application callback errors propagate through both parsing styles.

## Reuse schemas

Derive a stricter schema without changing its base.

```dart
final name = string().min(2);
final shortName = name.max(12);
final names = name.list();
final optionalValue = name.nullable();

print(shortName.validate('Ada')); // true
print(names.parse(['Ada', 'Grace'])); // [Ada, Grace]
print(optionalValue.parse(null)); // null
```

Nullability allows a null value. [Optional fields](/presence-and-defaults) allow an object key to be absent. Parsed maps and lists can reuse input containers; copy them when you need independent mutable data.
