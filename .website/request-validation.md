---
description: Decode a request, validate its body, return structured issues, and apply a PATCH safely.
---

# Validate an API request

Validate decoded input before constructing domain values or saving data. This framework-neutral example returns a status and JSON-ready body; adapt those to your server's response API.

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
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return (status: 400, body: {'error': 'Malformed JSON'});
  }
  if (decoded is! Map<String, Object?>) {
    return (status: 400, body: {'error': 'Expected a JSON object'});
  }
  final result = accountInput.tryParse(decoded);
  if (!result.isValid) {
    return (status: 422, body: result.issues.toTransport());
  }
  return (status: 200, body: result.value);
}

void main() {
  print(validateRequest('{"name":"Ada","email":"ada@example.com"}').status);
  // 200
  print(validateRequest('{"name":"A","email":"invalid"}').status); // 422
  print(validateRequest('invalid JSON').status); // 400
}
```

The example chooses 400 for malformed JSON/non-object bodies and 422 for schema failures. Its error response uses the [versioned transport envelope](/validation-results#send-issues-over-the-wire), so clients can localize codes without receiving submitted values. Use `formatFields()` or `formatJson()` when the server should render messages.

This schema rejects unknown keys. Use the default strip policy to accept and discard them. Each nested object controls its own extras.

## Construct a typed value

After a successful parse, map fields explicitly into your domain class. Put reusable mapping in a [class schema](/schemas/instances#class-schemas). Object schemas return maps; they do not generate Dart classes. Serialize domain objects explicitly when returning JSON.

## Apply a PATCH

Derive a patch schema, merge only parsed supplied fields, then validate the complete object before saving.

```dart
final account = object({
  'name': string().min(2),
  'email': string().email(),
  'nickname': string().nullable(),
}).optionals(['nickname']).unknownKeys(AcanthisUnknownKeys.reject);
final existing = <String, Object?>{
  'name': 'Ada',
  'email': 'ada@example.com',
  'nickname': 'Countess',
};

final patch = account.patch().tryParse({'nickname': null});
if (patch.isValid) {
  final updated = account.parse({...existing, ...patch.value});
  print(updated['name']); // Ada: omission preserved it.
  print(updated['nickname']); // null: supplied null cleared it.
}
```

`.patch()` suppresses defaults for omitted fields; it does not merge or persist data. The map spread above applies a shallow update. Define application-specific merging for nested changes. Use `containsKey()` when mapping patch fields individually so omission stays distinct from explicit null.

For async checks, call `await schema.tryParseAsync(decoded)`. Supply request-specific services through [validation context](/contextual-rules#request-context-and-asynchronous-rules). The repository's `example/issue_formatting.dart` demonstrates localized responses and transport.
