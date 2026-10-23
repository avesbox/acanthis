---
description: Compose nullability with lists, objects, and other schema capabilities.
---

# Nullable values

## `nullable()` {#nullables}

`.nullable()` wraps a schema and accepts null in addition to its ordinary input. The output type becomes `T?`.

```dart
final name = string().min(2).nullable();
final String? missingName = name.parse(null);
print(name.parse('Ada')); // Ada
print(name.validate('A')); // false
```

Nullability composes with other capabilities. The order changes the type:

```dart
final List<String?> names = string().nullable().list().parse(['Ada', null]);
final List<String>? tags = string().list().nullable().parse(null);
```

## Limit non-null values

```dart
final language = string().nullable().enumerated(['Dart', 'JavaScript']);
print(language.validate(null)); // true
print(language.validate('Dart')); // true
print(language.validate('Rust')); // false
```

Nullable enumeration always permits null. Non-null values must also satisfy the wrapped schema.

## Defaults

```dart
final name = string().min(2).nullable(defaultValue: 'Guest');
print(name.parse(null)); // Guest
```

A non-null default replaces null before validation and must pass every relevant check, including nullable enumeration. Plain `.nullable()` has no explicit null default. Use `.nullable().withDefault(null)` when an omitted object field should be filled with null.

## Nullable fields are required

```dart
final account = object({'nickname': string().nullable()});
print(account.validate({})); // false
print(account.validate({'nickname': null})); // true
```

Add `.optionals(['nickname'])` to allow omission. See [presence and defaults](/presence-and-defaults) for the complete behavior table and PATCH semantics.
