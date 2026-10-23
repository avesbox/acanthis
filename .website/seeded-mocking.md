---
description: Control mock generation with seeded input providers and explicit search and size budgets.
---

# Seeded mocking

`.mockSeeded()` generates typed, validated output within explicit limits.

```dart
final account = object({
  'name': string().min(2).max(12),
  'age': integer().gte(18).lte(65),
});
final sample = account.mockSeeded(
  seed: 42,
  maxAttempts: 64,
  maxDepth: 16,
  maxCollectionLength: 256,
  maxNodes: 4096,
);
print(account.validate(sample)); // true
```

The displayed limits are the defaults. `.mock()` and `.mock(seed)` use this same engine. Identical results require the same schema, library version, seed, limits, generators, SDK, and deterministic callbacks. Cross-SDK random sequences are not guaranteed.

## Supported constraints {#supported-subset}

Automatic generation covers native numeric bounds and choices, booleans, scalar literals, nullable values, string lengths/exact values/enums, email/case/UUID/URL/URI/date-time/Base64 checks, list membership/length/uniqueness, objects, records, tuples, plain unions, and scalar templates. Dates support fixed bounds and fixed-date differences; clock-relative checks are rejected for reproducibility.

Unconstrained numeric candidates start around -1000 to 1000; explicit bounds can move that range. Sampling bounds must fit the JSON safe integer range. Defaults are inspected and validated. This is a candidate generator, so sparse valid domains can exhaust the attempt budget.

[Instances with factories and pipelines](/schemas/mocking#instances-and-pipelines) support explicit construction and output validation. Pipelines generate source input and validate the converted target. Root pipeline generation uses source candidates; nested null candidates follow ordinary pipeline default behavior.

## Custom generators

Supply a raw input candidate for the exact schema instance that needs one.

```dart
final sku = string().pattern(RegExp(r'^SKU-\d{3}$'));
final catalog = object({'codes': sku.list().length(3)});
final sample = catalog.mockSeeded(seed: 42, generators: {
  sku: (random) => 'SKU-${100 + random.nextInt(900)}',
});
print(catalog.validate(sample)); // true
```

The generator map is snapshotted using schema identity; a fluent clone is a different key. Providers share the seeded random stream across nested values and retries. Return **input**, including for a pipeline. Normal parsing creates and checks its typed output.

A provider explicitly permits synchronous checks, transforms, field rules, and variant guards in that subtree. Unsupported siblings still fail inspection before a provider runs. Arbitrary regex and unsupported formats need providers; async schemas and lazy resolvers remain rejected. Providers do not change exports or the schema itself.

## Budgets and failures {#limits}

| Limit | Default | Bounds |
| --- | --- | --- |
| `maxAttempts` | 64 | Positive |
| `maxDepth` | 16 | 1–128 |
| `maxCollectionLength` | 256 | Positive |
| `maxNodes` | 4096 | Positive |

Inspection, defaults, generated inputs, and described outputs are bounded. Provider candidates are checked before parsing and outputs afterward. Outputs must be inspectable scalars, maps, lists, or field-described instances. Ambiguous union outputs are inspected conservatively across matching shapes.

Invalid candidates retry within the outer attempt budget. Contradictions, unsupported schemas, or exhaustion throw `AcanthisMockException`; invalid limits throw `ArgumentError`. Provider and programming exceptions propagate. Pipeline `FormatException` can produce a failed candidate and retry. Cancellation stays separate control flow.

Budgets do not bound arbitrary work inside a callback or hidden domain state. Keep providers, getters, factories, and checks pure and deterministic. See the repository's `example/seeded_generators.dart` for a runnable provider example.
