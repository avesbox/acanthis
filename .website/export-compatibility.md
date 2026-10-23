---
description: Check which native Dart schema behaviors have faithful JSON Schema and OpenAPI representations.
---

# Export compatibility {#schema-export-compatibility}

Every native export helper uses the same strict audit. A contract is emitted only when the schema's supported behavior can be represented faithfully for JSON values. Unsupported behavior throws rather than disappearing from the contract.

## Export helpers

| API | Result | Default mode |
| --- | --- | --- |
| `toJsonSchema(mode: ...)` | JSON Schema 2020-12 map | Input |
| `exportJsonSchema(mode: ...)` | Same JSON Schema map | Explicit mode required |
| `toPrettyJsonSchema(indent: 2, mode: ...)` | Formatted JSON string | Input |
| `toOpenApiSchema(mode: ...)` | OpenAPI 3.1 Schema Object | Explicit mode required |
| `exportOpenApiSchema(mode: ...)` | Same OpenAPI Schema Object | Explicit mode required |

## Supported behavior

Every child, constraint, default, and annotation must pass the audit.

| Native behavior | Export |
| --- | --- |
| Unconstrained strings, numbers, booleans, scalar literals | Supported when scalar equality is representable |
| Objects, lists, tuples, nullable values, string-key records | Supported when their children and checks are supported |
| Optional fields, defaults, PATCH, unknown-key policies | Supported; input/output modes can differ |
| Numeric bounds, scalar equality/enumeration, boolean checks | Supported with representable finite constraints |
| Empty/nonempty string constraints | Supported |
| List lengths, scalar membership, uniqueness | Supported within the audited equality subset |
| Object property counts | Supported |
| Plain unions, scalar templates, stable recursive objects | Supported subset; recursion uses local references |
| Field-described instances | Declared JSON representation; getters do not run |
| General string lengths, patterns, and formats | Rejected |
| Dart `integer()` / `doubleType()` restrictions | Rejected |
| Coercion, transforms, pipes, custom/async checks, guarded unions, field rules | Rejected |
| Native dates and opaque domain schemas | Rejected |

## Why a check can be rejected

Native string lengths count UTF-16 code units; JSON Schema lengths count Unicode code points. Dart `int` and `double` are distinct runtime representations; JSON numeric types cannot enforce that distinction. Arbitrary callbacks cannot be translated into declarative JSON constraints.

Use an [imported JSON contract](/json-schema#import-a-contract) when JSON semantics are the requirement. Keep additional application checks explicit when a published contract describes only a boundary subset.

## Input versus output

Input mode describes accepted JSON, including missing/null values handled by valid defaults. Output mode describes successful parsed values, including the effects of stripping and defaults. Neither describes invalid recovery. An external validator may validate input without applying Acanthis's transformations to it.

## Handle an export failure {#handle-unsupported-schemas}

```dart
final schema = object({'email': string().email()});
try {
  schema.toJsonSchema();
} on AcanthisSchemaExportException catch (error) {
  print(error.path); // Points to the unsupported part of the schema.
  print(error.reason);
}
```

Export does not execute arbitrary validation, conversion, getter, or constructor callbacks. Supported metadata is serialized to fresh JSON containers; cycles and unsafe annotation values fail explicitly.
