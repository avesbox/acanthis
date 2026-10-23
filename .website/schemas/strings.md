---
description: Check text length, contents, formats, and case. Transform strings before parsing them.
---

# Strings

## `string()` {#string}

`string()` accepts a Dart `String`. Empty strings are valid unless you add a check.

```dart
final name = string().trim().min(2).max(80);
print(name.parse(' Ada ')); // Ada
print(name.validate('A')); // false
```

### Length

```dart
string().min(3);     // At least 3 UTF-16 code units.
string().max(80);    // At most 80.
string().length(8);  // Exactly 8.
string().notEmpty(); // At least 1.
```

Length uses Dart's `String.length`, so some emoji count as two code units. `required()` remains a compatibility alias for nonempty text; use `notEmpty()` in new schemas. Object field presence is controlled separately.

### Contents

```dart
string().pattern(RegExp(r'^[a-z0-9-]+$'));
string().contains('dart');
string().startsWith('acct_');
string().endsWith('.dart');
string().exact('active');
string().contained(['draft', 'published']);
```

Use `contained()` for string choices or `enumerated()` for enum names.

```dart
enum Status { draft, published }

final status = string().enumerated(Status.values);
print(status.parse('draft')); // draft, a String.
```

`nameTransformer:` changes the enum names used for matching. It does not convert the output to an enum value.

### Characters and case

```dart
string().letters();
string().digits();
string().alphanumeric();
string().alphanumericWithSpaces();
string().specialCharacters();
string().allCharacters();
string().upperCase();
string().lowerCase();
string().mixedCase();
```

Character-family checks accept `strict: false` to search for a matching character instead of requiring the strict pattern. These are built-in pattern checks; use your own `RegExp` for an application's specific alphabet. Case checks validate text without changing it.

## Formats {#string-formats}

```dart
string().email();
string().url();
string().uri();
string().uuid();
string().cuid();
string().cuid2();
string().ulid();
string().nanoid();
string().jwt();
string().base64();
string().dateTime();
string().time();
string().hexColor();
string().card();
```

Format checks return strings. A date-time string does not become a `DateTime`; use [dates](/schemas/numbers#dates) for that output. JWT and card checks inspect format; they do not authenticate a token or authorize a payment.

### Email addresses {#emails}

```dart
final email = string().email();
print(email.validate('ada@example.com')); // true
```

`email()` checks address syntax using the package's email validator. It does not verify ownership or delivery.

### Compromised passwords

`string().uncompromised(lookup: ...)` adds an asynchronous password-range check. Supply a `PasswordRangeLookup` for your range service, and call `tryParseAsync()` or `parseAsync()`. This check needs an external lookup; keep password values out of diagnostic parameters.

## Transformations

```dart
print(string().trim().toLowerCase().parse(' ADA ')); // ada
string().toUpperCase();
string().encode(); // Base64 encoding.
string().decode(); // Base64 decoding.
```

Operations run in declaration order. Put `.trim()` before `.min()` when length should be checked after whitespace removal. Use [coercion](/schemas/transformations#type-coercion) to accept supported non-string inputs, or [pipes](/schemas/transformations#pipes) to produce another type.
