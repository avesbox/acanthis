# Validate an API request

Validate at the boundary before constructing a domain object or writing data.
This framework-neutral recipe returns a status and JSON-ready body; adapt those
to your server's response API. The status choices are part of this example's API
design: 400 for malformed JSON or a non-object body, 422 for field failures.

## Decode and validate

```dart
import 'dart:convert';
import 'package:acanthis/acanthis.dart';

final accountInput = object({
  'name': string().min(2),
  'email': string().email(),
  'nickname': string().nullable(),
}).optionals(['nickname']).unknownKeys(AcanthisUnknownKeys.reject);

({int status, Map<String, Object?> body}) validateRequest(String body) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return (status: 400, body: {'error': 'Malformed JSON'});
  }
  if (decoded is! Map<String, dynamic>) {
    return (status: 400, body: {'error': 'Expected a JSON object'});
  }
  final result = accountInput.tryParse(decoded);
  if (!result.isValid) {
    return (
      status: 422,
      body: {'issues': result.issues.map((issue) => issue.toJson()).toList()},
    );
  }
  return (status: 200, body: result.value);
}
```

An issue includes its data path, stable code, message, and constraint parameters.
Clients can use `jsonPointer` or typed paths to associate errors with fields.
Use [presentation-time localization](/validation-results#presentation-and-localization)
for translated messages. Do not return an invalid outcome's recovery `value` as
accepted request data.

This schema rejects unknown keys explicitly. Use the default strip policy if
your API should accept and discard them, or preserve only when extras belong in
your contract. Each nested object has its own policy.

## Construct a typed value

After the success check, map validated fields into your application's type:

```dart
class Account {
  final String name;
  final String email;
  final String? nickname;
  const Account(this.name, this.email, this.nickname);
}

Account readAccount(Map<String, dynamic> values) => Account(
  values['name'] as String,
  values['email'] as String,
  values['nickname'] as String?,
);
```

`object()` produces a map; it does not infer a Dart class from field names. If
mapping belongs in a reusable schema, use [classSchema](/schemas/instances#class-schemas).
Serialize domain objects explicitly when returning JSON.

## Apply a PATCH

Derive a PATCH schema, validate, then merge only supplied fields into the stored
value. An omitted nickname leaves it unchanged; explicit null clears it.

```dart
final accountPatch = accountInput.patch();
final existing = Account('Ada', 'ada@example.com', 'Countess');
final result = accountPatch.tryParse({'nickname': null});
if (result.isValid) {
  final values = result.value;
  final updated = Account(
    values.containsKey('name') ? values['name'] as String : existing.name,
    values.containsKey('email') ? values['email'] as String : existing.email,
    values.containsKey('nickname')
        ? values['nickname'] as String?
        : existing.nickname,
  );
  print(updated.nickname); // null
}
```

The same body-decoding checks apply to PATCH requests. `.patch()` suppresses
defaults on omitted fields; it does not merge data or persist changes. For
cross-field invariants involving stored values, validate the merged object with
the full schema before saving. See [presence and defaults](/presence-and-defaults).

Async checks require `await schema.tryParseAsync(decoded)`. Per-request services
can be supplied through [validation context](/contextual-rules).

The complete runnable version is
[`example/request_validation.dart`](https://github.com/avesbox/acanthis/blob/main/example/request_validation.dart).
From the repository root, run:

```sh
dart run example/request_validation.dart
```
