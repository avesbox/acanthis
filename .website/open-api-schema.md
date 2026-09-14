# Open API Schema

## Audited OpenAPI 3.1 export

Use `exportOpenApiSchema` to generate an OpenAPI 3.1 Schema Object:

```dart
final schema = object({
  'name': string().notEmpty(),
  'score': number().gte(0).nullable(),
});
final input = schema.exportOpenApiSchema(mode: AcanthisSchemaMode.input);
final output = schema.exportOpenApiSchema(mode: AcanthisSchemaMode.output);
```

This API uses the same [audited contract and supported subset](/json-schema#audited-input-and-output-contracts)
as JSON Schema 2020-12. Nullable values and overlapping unions use `anyOf`;
unsupported checks or transformations throw an exception with a schema path.
Input and output modes account for defaults and unknown-key policies.

The result is a standalone Schema Object, not a complete OpenAPI document.
Recursive references use local `$defs`. When embedding that resource inside a
larger document, preserve a separate schema resource or rebase its references
to the document location.

## Legacy best-effort export

The `toOpenApiSchema` API is retained for compatibility. It uses legacy keywords
such as `nullable`; use the explicit API above for an audited OpenAPI 3.1 contract.

To convert an Acanthis type to an Open API schema, you can use the `toOpenApiSchema` method. For example:

```dart
final schema = object({
  'name': string(),
  'age': number(),
}).toOpenApiSchema(); // => Map<String, dynamic>
// => {
//   type: 'object',
//   properties: {
//     name: {type: 'string'},
//     age: {type: 'number'}
//   },
//   required: ['name', 'age'],
// }
```

This will generate an Open API schema that describes the structure of the Acanthis type.

All the types and most of the checks are converted to their closest Open API equivalents.

## Nullable Types

Nullable types are converted to Open API schema using the `nullable` keyword. This means that the schema will accept either the type or `null`. For example:

```dart
final schema = object({
  'name': string().nullable(),
}).toOpenApiSchema();
// => {
//   type: 'object',
//   properties: {
//     name: {type: 'string', nullable: true}
//   },
//   required: ['name'],
// }
```

This indicates that the `name` property can either be a string or `null`.
