---
description: Validate text, check formats, and transform string values.
---

# Strings

Validate text, check formats, and transform string values.

## String

::: warning Deprecated
`string().required()` is deprecated in Acanthis 1.3.1. The validator was ambiguous and has been replaced with `string().notEmpty()`
:::

Acanthis provides many built-in validators for string validation and transformation. To perform some common validations:

```dart
string().min(5);
string().max(10);
string().length(5);
string().pattern(RegExp('^[a-zA-Z0-9]+$'));
// string().pattern('^[a-zA-Z0-9]+$'); equivalent to the previous example
string().contains('Acanthis');
string().startsWith('Acanthis');
string().endsWith('Acanthis');
string().upperCase();
string().lowerCase();
string().mixedCase();
string().notEmpty();
string().digits();
string().letters();
string().alphanumeric();
string().alphanumericWithSpaces();
string().specialCharacters();
string().allCharacters();
string().contained(['Acanthis', 'Dart']);
string().exact('Acanthis');
```

To perform simple transformations:

```dart
string().toUpperCase();
string().toLowerCase();
string().encode();
string().decode();
```

## String Formats

```dart
string().email();
string().url();
string().uri();
string().uuid();
string().dateTime();
string().time();
string().nanoid();
string().hexColor();
string().base64();
string().cuid();
string().cuid2();
string().ulid();
string().jwt();
string().card();
```

### Emails

To validate an email address, you can use the `email()` method. This method checks if the string is a valid email address format.

```dart
string().email();
```

Under the hood it uses the `email_validator` package. You can find more information about the package at [its pub.dev page](https://pub.dev/packages/email_validator).

---

[Browse all schemas](/defining-schemas) · [Understand validation results](/validation-results)
