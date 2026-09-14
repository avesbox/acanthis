---
description: Match exact values or accept one of several schema shapes.
---

# Literals and unions

Match exact values or accept one of several schema shapes.

## Literals

Use `literal()` to create a schema that matches a specific literal value.

```dart
final numeric = literal(1);
```

Literals support the same fluent refinements and transformations as other
schemas. They match the exact value before those operations run, which makes
them useful for tagged objects and unions.

## Union

To create a union type, you can use the `union()` method. This method allows you to create a type that can be one of several types.

```dart
final valueSchema = union([
  string(),
  number(),
  boolean(),
]);

final fluentSchema = string().union([
  number(),
  boolean(),
]); // it is the same as the previous example

```

This will create a type that can be either a string, number or boolean.

```dart
final fluentSchema = string().union([
  number(),
  boolean(),
]);

fluentSchema.parse('Acanthis'); // ✅
fluentSchema.parse(5); // ✅
fluentSchema.parse(true); // ✅
fluentSchema.parse([1, 2, 3]); // ❌ throws ValidationError
```

### `variant()`

Use `variant()` to build a discriminated (guarded) branch inside a `union()`.  
A variant couples a lightweight guard with a full schema. The guard decides if the schema should even be attempted, letting you short‑circuit work and produce clearer errors.

Concept:

- Guard: `bool Function(dynamic)` returning true if this branch may validate the value.
- Schema: the `AcanthisType<T>` executed only when the guard passes.
- Name (optional): label used in aggregated errors (recommended).

Why variants instead of only plain union element types?

- Selective evaluation: only schemas whose guards return true are parsed (a plain union tries branches until one succeeds).
- Cleaner error surfaces: if no guard matches you get one union error instead of multiple unrelated schema errors.
- Natural discriminators: model tagged / algebraic unions (`type` fields, prefix patterns, structural probes).
- Performance: cheap guards filter out heavy schemas early.

Basic (tagged) example:

```dart
final shape = union([
  variant(
    name: 'circle',
    guard: (v) => v is Map && v['type'] == 'circle',
    schema: object({
      'type': string().exact('circle'),
      'radius': number().positive(),
    }),
  ),
  variant(
    name: 'rectangle',
    guard: (v) => v is Map && v['type'] == 'rectangle',
    schema: object({
      'type': string().exact('rectangle'),
      'width': number().positive(),
      'height': number().positive(),
    }),
  ),
]);

shape.parse({'type': 'circle', 'radius': 10});    // ✅
shape.parse({'type': 'rectangle', 'width': 5, 'height': 7}); // ✅
shape.parse({'type': 'triangle'}); // ❌ ValidationError (no variant matched)
```

Mixing variants and plain types:

```dart
final idOrPointOrBool = union([
  variant(
    name: 'idString',
    guard: (v) => v is String && v.startsWith('id:'),
    schema: string().pattern(RegExp(r'^id:\d+$')),
  ),
  variant(
    name: 'point',
    guard: (v) => v is Map && v.containsKey('x') && v.containsKey('y'),
    schema: object({
      'x': number().finite(),
      'y': number().finite(),
    }),
  ),
  boolean(), // plain type (checked after matching variants)
]);
```

Fallback pattern (keep last):

```dart
final numericInput = union([
  variant(
    name: 'numberLike',
    guard: (v) => v is String && double.tryParse(v) != null,
    schema: string().pipe(number(), transform: double.parse),
  ),
  variant(
    name: 'rawNumber',
    guard: (v) => v is num,
    schema: number(),
  ),
]);
```

Guidelines:

- Order matters. Guards are evaluated top‑down. The first variant whose guard returns true is attempted; if its schema fails, later variants whose guards also returned true will still be considered.
- Keep guards pure, fast, and side‑effect free. They must not throw.
- Name every variant for clearer aggregated errors (`name:`).
- Combine variants with plain union element types freely. After all matching variants are tried, remaining plain types are attempted.
- If no guard matches and no plain type validates, the union fails with a single error.
- If at least one guard matches but all corresponding schemas fail, union aggregates those failures.

When to use:

- Tagged JSON objects (`type`, `kind`, `opcode`).
- Structural branching (presence of keys, collection shape).
- Prefix / pattern based routing for primitives.
- Performance sensitive large unions.

Use `variant()` whenever a cheap discriminator can prevent wasted work or produce more precise diagnostics.

## Template Literals

Use `template()` to create a schema that matches template literal strings with placeholders.

```dart

enum SizeUnit { px, em, rem }

final sizeSchema = template([
  number(),
  string().enumerated(SizeUnit.values),
]);

sizeSchema.parse('12px'); // ✅
sizeSchema.parse('5em');  // ✅
sizeSchema.parse('20rem'); // ✅
sizeSchema.parse('15pt'); // ❌ ValidationError
```

The `template()` function takes a list of schemas that represent the placeholders in the template literal. The resulting schema will match strings that follow the pattern defined by the schemas.

Template parts are literal strings or schemas whose exported shape contributes a regular-expression fragment. This checks the resulting string pattern; it does not run each part as a nested validator. Avoid complex objects and refinements as placeholders when their runtime rules must be enforced.

---

[Browse all schemas](/defining-schemas) · [Understand validation results](/validation-results)
