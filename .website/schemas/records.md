---
description: Validate maps whose keys and values share schemas.
---

# Records

Use `record(keySchema, valueSchema)` for a map with dynamic keys. Use [objects](/schemas/objects) for a fixed set of named fields.

```dart
final scores = record(string().notEmpty(), integer().gte(0));
final Map<String, int> parsed = scores.parse({'Ada': 10, 'Grace': 20});
print(parsed['Ada']); // 10
```

Both keys and values are parsed. Their output types determine `Map<K, V>`.

## Transform keys

```dart
final labels = record(string().trim().toLowerCase(), string());
print(labels.parse({' TEAM ': 'Research'})); // {team: Research}

final duplicate = labels.tryParse({'TEAM': 'A', 'team': 'B'});
print(duplicate.isValid); // false
print(duplicate.issues.first.code); // duplicateKey
```

Transformed key collisions fail instead of silently overwriting a value. Record values can contain any supported child schema, including nested objects, lists, nullable values, and pipelines.

## Property counts

```dart
final scores = record(string(), number()).refine(
  onCheck: (values) => values.isNotEmpty && values.length <= 10,
  name: 'scoreCount',
  error: 'Supply between 1 and 10 scores',
);
print(scores.validate({})); // false
```

Use a refinement for record property counts. Record schemas support check, transform, nullable, list, and default composition. Live editing sessions are available on `ObjectSchema`; records do not expose `.watch()`.

JSON object keys are strings. [Strict export](/export-compatibility) requires a representable string-key contract.
