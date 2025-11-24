# Open API Schema

Acanthis can also generate Open API schemas from the defined types. The Open API schema generation follows the Open API Specification (OAS) version 3.1.

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
