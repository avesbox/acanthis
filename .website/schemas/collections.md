---
description: Validate repeated elements with lists and positional elements with tuples.
---

# Lists and tuples

## Lists

`list(schema)` parses every element with the same schema. `schema.list()` is equivalent.

```dart
final names = string().trim().min(2).list();
final List<String> parsed = names.parse([' Ada ', 'Grace']);
print(parsed); // [Ada, Grace]
```

Failed children include their integer index in the issue path. Unchanged typed lists can reuse their input; use `List.of(parsed)` for an independent outer list.

### Length

```dart
list(string()).min(1);
list(string()).max(10);
list(string()).length(3);
```

### Membership and uniqueness

```dart
list(string()).contains('admin');
list(string()).anyOf(['admin', 'editor']);
list(string()).everyOf(['admin', 'editor']);
list(string()).unique();
```

| Check | Requirement |
| --- | --- |
| `contains(value)` | At least one element equals the value |
| `anyOf(values)` | At least one element belongs to the allowed values |
| `everyOf(values)` | Every element belongs to the allowed values |
| `unique()` | No two elements compare equal |

Checks run on parsed elements and use Dart equality. `everyOf()` does not require every allowed value to appear. Container equality is not automatically structural.

### `unwrap()`

```dart
final names = string().min(2).list();
final element = names.unwrap();
print(element.tryParse('A').isValid); // false
```

## Tuples

`tuple()` assigns a schema to each position and requires the declared length. Output is a heterogeneous list.

```dart
final point = tuple([string(), number(), number()]);
print(point.parse(['home', 10, 20])); // [home, 10, 20]
```

`.and()` includes the receiver as the first element.

```dart
final pair = string().and([integer()]);
print(pair.parse(['Ada', 28])); // [Ada, 28]
```

### `variadic()`

Repeat the final schema zero or more times after the fixed prefix. The minimum length is one less than the original tuple length.

```dart
final row = tuple([string(), number()]).variadic();
print(row.parse(['scores', 10, 20, 30])); // [scores, 10, 20, 30]
print(row.validate(['scores'])); // true
```

## Nullable lists and elements

```dart
final List<String?> elements = string().nullable().list().parse(['Ada', null]);
final List<String>? collection = string().list().nullable().parse(null);
```

Modifier order determines which value can be null. See [nullable values](/schemas/nullable).
