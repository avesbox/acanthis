---
description: Export native schemas as strict JSON Schema contracts, or compile a JSON Schema for validation.
---

# JSON Schema

Export a native schema when its behavior can be represented in JSON Schema 2020-12. Import a JSON contract when that contract defines your boundary.

## Export a schema {#audited-input-and-output-contracts}

```dart
final account = object({
  'name': string().notEmpty().withDefault('Guest'),
  'score': number().gte(0).lte(100),
});

final input = account.toJsonSchema();
final output = account.toJsonSchema(mode: AcanthisSchemaMode.output);
print(input['type']); // object
print(output['required']); // [name, score]
```

`toJsonSchema()` defaults to input mode. `exportJsonSchema(mode: ...)` is an explicit-mode alias. Both use the same strict audit and return independent JSON maps.

### Input and output

| Mode | Describes |
| --- | --- |
| `AcanthisSchemaMode.input` | Accepted JSON input, including omission/null handled by valid defaults |
| `AcanthisSchemaMode.output` | Successful parsed JSON output |

Unknown-key stripping can accept extra input keys while omitting them from output. External JSON validators do not necessarily insert defaults or strip keys. Neither mode describes invalid recovery values.

### Unsupported behavior

Unsupported constraints throw `AcanthisSchemaExportException` with a JSON-pointer `path` and a `reason`. Export does not run arbitrary validation callbacks to guess a contract.

```dart
try {
  string().email().toJsonSchema();
} on AcanthisSchemaExportException catch (error) {
  print(error.path);
  print(error.reason);
}
```

Formats, general string lengths, Dart int/double restrictions, coercion, transforms, and arbitrary checks are among the rejected behaviors. See [export compatibility](/export-compatibility) for supported shapes and the reasons for these limits.

## Recursive types

```dart
final tree = object({
  'value': number().gte(0),
  'children': lazy((parent) => parent.list()),
});
final document = tree.toJsonSchema();
print(document.containsKey(r'$defs')); // true
```

Recursion uses local `$defs` and `$ref`. Keep lazy definitions deterministic and preserve the reference scope when embedding the result.

## Metadata and instances

`.meta(MetadataEntry(...))` contributes supported descriptive annotations. Metadata does not change runtime validation or make a rejected check representable.

Field-described instance export describes the declared JSON field representation without calling getters or constructors. The instance validator still expects an instance at runtime. See [instance helpers](/schemas/instances#field-helpers-export-and-mocks).

## Pretty-print

```dart
final schema = object({'active': boolean()});
print(schema.toPrettyJsonSchema(indent: 4));
```

The default indent is two spaces. `mode:` selects the same strict input/output contract; indentation must be nonnegative.

## Import a contract

```dart
final contract = fromJsonSchema({
  'type': 'object',
  'properties': {
    'name': {'type': 'string', 'minLength': 2},
    'age': {'type': 'integer', 'minimum': 18},
  },
  'required': ['name', 'age'],
  'additionalProperties': false,
});

print(contract.validate({'name': 'Ada', 'age': 28.0})); // true
print(contract.tryParse({'name': 'A', 'age': 16}).issues.length); // 2
```

`fromJsonSchema()` and `importJsonSchema()` compile to a reusable `AcanthisJsonContract`. Compile once, then reuse `parse`, `tryParse`, and boolean validation. Imported contracts validate JSON data; their generic output does not infer a Dart class.

### JSON semantics

Imported `integer` uses mathematical integrality, so `28.0` is accepted. String lengths count Unicode code points. Equality and array uniqueness compare JSON structure. Defaults are annotations and do not fill absent fields. These semantics differ from some native Dart checks.

The supported subset includes type arrays, scalar constraints, objects and arrays, `allOf`, `anyOf`, `not`, and local references, including supported descending recursive references. Unsupported keywords throw `AcanthisSchemaImportException` with a path and reason. Remote references are not fetched, and import does not recreate Dart callbacks.

See [OpenAPI](/open-api-schema) for the corresponding Schema Object helpers and the repository's contract guide for the independent export-audit runner.
