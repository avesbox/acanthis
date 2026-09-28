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

if (result.isValid) {
  print(result.value['name']); // Ada
} else {
  for (final issue in result.issues) {
    print('${issue.jsonPointer}: ${issue.message}');
  }
}
```

`tryParse()` returns an `AcanthisOutcome<T>`. Both branches expose `.value`: validated output on `AcanthisValid<T>`, best-effort output on `AcanthisInvalid<T>`. Check `isValid` or match the outcome before treating the value as valid data.

## Handle invalid data

Each issue identifies the field that failed and the reason. Use the typed path or JSON pointer to associate messages with your UI.

```dart
final invalid = account.tryParse({
  'name': 'Ada',
  'email': 'not-an-email',
  'age': 28,
});

print(invalid.isValid); // false
print(invalid.issues.first.jsonPointer); // /email
print(invalid.issues.first.code); // email
```

For custom messages or localization, continue to [custom error messages](/error-customization) and [results and issues](/validation-results).

## Choose a parsing method

| When you need… | Use | On invalid input |
| --- | --- | --- |
| Validation to stop the operation | `parse(input)` | Throws `ValidationError` |
| A field error message | `validate(input)` | Returns the first validation message, or `null` on success |
| Typed success and failure branches | `tryParse(input)` | Returns `AcanthisInvalid` |
| Async checks | `tryParseAsync(input)` or `parseAsync(input)` | Returns issues or throws, respectively |
| Async field messages | `validateAsync(input)` | Returns the first message, or `null`, in a `Future` |

### `validate()` with Flutter's `TextFormField` {#flutter-textformfield}

`validate()` returns `null` for valid input and the first `ValidationError`
message for invalid input. This matches Flutter's
[`validator` callback](https://api.flutter.dev/flutter/widgets/FormField/validator.html).
Reuse a synchronous schema and normalize the callback's nullable input to an
empty string so a required-field check can display your message.

```dart
import 'package:acanthis/acanthis.dart';
import 'package:flutter/material.dart';

class EmailForm extends StatefulWidget {
  const EmailForm({super.key});

  @override
  State<EmailForm> createState() => _EmailFormState();
}

class _EmailFormState extends State<EmailForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = string()
      .notEmpty(message: 'Enter your email')
      .email(message: 'Enter a valid email address');

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) => _email.validate(value ?? ''),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // All fields passed; save or submit the form here.
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
```

You can also pass `validator: schema.validate` directly when the schema accepts
the callback's possible `null` value, for example with a nullable schema.
`string().nullable()` accepts null, but still checks a supplied empty string.
Passing null or an incompatible type to a non-nullable string schema can throw
`TypeError`; `validate()` only converts `ValidationError` into a message.
Uncaught exceptions from transformations propagate. Custom refinements retain
their existing behavior of converting thrown exceptions into check failures.

Coercions and transformations run during validation, but `validate()` discards
the parsed value and does not update the text field. Use `parse(input)`
when you need the transformed value, or `tryParse()` for all structured issues.

Async schemas throw `AsyncValidationException` in `validate()`. Run remote checks
outside the synchronous Flutter callback with `tryParseAsync()` and manage the
pending/error state in your widget. `validateAsync()` returns `Future<String?>` and can supply a message for that
state, but cannot be assigned to the synchronous `validator` callback.

For translated text today, use schema messages or resolve structured issues as
described in [presentation and localization](/validation-results#presentation-and-localization).

### `parse()`

`parse()` returns the validated value directly and throws on validation failure.

```dart
try {
  final result = account.parse({
    'name': 'Ada',
    'email': 'not-an-email',
    'age': 28,
  });
  print(result);
} on ValidationError catch (error) {
  print(error.message);
}
```

### `tryParse()`

Both branches expose `value`, `isValid`, and `issues`. An invalid outcome contains best-effort output, which may include defaults or partial transformations and may still fail the schema. Use `isValid` or match the sealed branches to decide how to handle it. `errors` is also available for compatibility; [structured issues](/validation-results#structured-diagnostics) preserve more detail.

### `parseAsync()`

Schemas with async refinements require an async parsing method. Awaiting `parseAsync()` returns the validated value directly, just like `parse()`.

```dart
final name = string().refineAsync(
  onCheck: (value) async => value != 'admin',
  name: 'reservedName',
  error: 'Choose a different name',
);

final result = await name.parseAsync('Ada');
print(result); // Ada
```

### `tryParseAsync()`

Use this to collect validation issues from a schema with async checks.

```dart
final result = await name.tryParseAsync('admin');
print(result.isValid); // false
```

::: tip Async checks
Calling a synchronous parsing method on a schema with async checks throws `AsyncValidationException`. Non-throwing parsing handles validation failures; it does not suppress arbitrary exceptions from your callbacks.
:::

## Keep going

<div class="doc-cards">
<a href="/defining-schemas.html"><strong>Build richer schemas →</strong><span>Explore objects, lists, unions, and custom checks.</span></a>
<a href="/validation-results.html"><strong>Work with results →</strong><span>Use typed outcomes, issue paths, and formatters.</span></a>
</div>
