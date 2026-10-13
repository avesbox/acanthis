---
description: Set field-specific validation messages and format structured issues for your application.
---

# Custom error messages

Give users a clear next step when a check fails. Pass `message` to a validator for fixed text, or use `messageBuilder` where supported to include the configured constraint.

## Set messages on a schema

```dart
import 'package:acanthis/acanthis.dart';

void main() {
  final account = object({
    'name': string().notEmpty(message: 'Enter your name'),
    'age': integer().gte(
      18,
      messageBuilder: (minimum) => 'You must be at least $minimum years old',
    ),
    'email': string().email(message: 'Enter a valid email address'),
  });

  final result = account.tryParse({
    'name': '',
    'age': 16,
    'email': 'invalid-email',
  });

  for (final issue in result.issues) {
    print('${issue.jsonPointer}: ${issue.message}');
  }
}
```

```text [Output]
/name: Enter your name
/age: You must be at least 18 years old
/email: Enter a valid email address
```

`notEmpty()` checks a supplied string. A missing object key is a separate required-field condition; see [objects](/schemas/objects).

## Group messages by field

Use `result.issues.formatFields()` to get messages grouped by JSON pointer. A field can have more than one message. Use `formatTree()` when your UI needs the nested structure.

## Localize at presentation time

Keep schemas reusable across languages by resolving messages from each issue’s code and parameters. A resolver returns `null` to keep the schema’s fallback message.

See [presentation and localization](/validation-results#presentation-and-localization) for a complete resolver example and the available output formats.

### Custom rules

For `checkFields()` and `checkFieldsAsync()`, resolve the rule's `name` as the
translation key; `error` supplies the fallback message. For explicit
`AcanthisRule` callbacks, resolve the returned `AcanthisIssue.code`, which is
independent of the rule's `id`. Return `null` for unknown codes to preserve the
fallback. Custom codes are translated by your application.

See [localizing custom rule messages](/contextual-rules#localize-custom-rule-messages)
for complete examples covering password confirmation, live sessions, and
parameter interpolation. The same resolver works with
`result.issues.formatFields()` and `session.issues.formatFields()`.

## Stable codes and transport

Use `AcanthisIssueCodes.minLength` and the other public string constants when
matching built-in diagnostics. Custom codes remain ordinary strings; use an
`app.*` or organization prefix. Codes, constraint parameter shapes, data paths,
and duplicate/branch order form the machine contract. English messages do not.

`AcanthisMessageCatalogs.english` and `.italian` can reformat the same issues
without rerunning checks. Use `AcanthisI18n.runWith` for request-scoped locale
selection. Explicit resolvers take precedence; returning null preserves the
stored message, and an empty string is a valid translation.

For API responses, use the versioned, locale-independent transport projection:

```dart
final result = object({'email': string().min(3)}).tryParse({'email': 'x'});
final payload = result.issues.toTransport();
// {version: 1, issues: [{path: [email], code: minLength,
//                       parameters: {value: 3}}]}
```

The envelope preserves string/int path segments and nested union branches. It
omits messages and recovery values; existing `toJson()` and `formatJson()` keep
resolved messages. Put constraints, never submitted secrets, into custom
parameters. Cyclic or oversized custom metadata is bounded with explicit markers.

The [complete contract and migration notes](https://github.com/avesbox/acanthis/blob/main/doc/error-codes.md)
list the vocabulary, parameter units, metadata limits, and observable changes.
In 2.1, instance failures use field paths plus the original check code, and
invalid input conversions become structured `ValidationError` failures.
