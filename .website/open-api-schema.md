---
description: Export and import OpenAPI 3.1 Schema Objects with explicit input and output contracts.
---

# OpenAPI

## Export a Schema Object {#audited-openapi-3-1-export}

`toOpenApiSchema()` produces an OpenAPI **3.1 Schema Object**. Choose input or output mode explicitly.

```dart
final account = object({
  'name': string().notEmpty(),
  'score': number().gte(0).nullable(),
});

final requestSchema = account.toOpenApiSchema(mode: AcanthisSchemaMode.input);
final responseSchema = account.toOpenApiSchema(mode: AcanthisSchemaMode.output);
print(requestSchema['type']); // object
print(responseSchema['required']); // [name, score]
```

`exportOpenApiSchema(mode: ...)` is an alias with the same strict audit. The result describes a schema; embed it in your own OpenAPI document. Keep local `$defs` and `$ref` together so references retain their scope.

## Nullable types

Nullable values use JSON Schema alternatives containing `null`. V2 does not emit OpenAPI 3.0's `nullable: true`. A nullable property remains required unless made optional or supplied by a default.

## Import a Schema Object

```dart
final contract = fromOpenApiSchema({
  'type': ['string', 'null'],
  'enum': ['draft', 'published', null],
});
print(contract.validate('draft')); // true
print(contract.validate(null)); // true
```

`importOpenApiSchema()` is an alias. Pass a supported Schema Object rather than an entire OpenAPI document. Import follows the same JSON semantics and keyword restrictions as [JSON Schema import](/json-schema#import-a-contract).

Unsupported native behavior throws `AcanthisSchemaExportException`; unsupported imported keywords throw `AcanthisSchemaImportException`. Both report a path and reason. See [export compatibility](/export-compatibility) before publishing a contract.
