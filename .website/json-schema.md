# JSON Schema

To convert an Acanthis schema to JSON Schema, you can use the `toJsonSchema` method.

```dart
final schema = object({
  'name': string(),
  'age': number(),
}).toJsonSchema(); // => Map<String, dynamic>

// => {
//   type: 'object',
//   properties: {
//     name: {type: 'string'},
//     age: {type: 'number'}
//   },
//   required: ['name', 'age'],
// }

```

This will generate a JSON Schema that describes the structure of the Acanthis schema.

All the types and most of the checks are converted to their closest JSON Schema equivalents.

## Numeric Types

Acanthis exposes a single type for numbers, `number()`. This can cause confusion when converting to JSON Schema, as JSON Schema has two numeric types: `integer` and `number`.
To solve this issue Acanthis uses the following rules:

- If the schema is a `number()` and has no checks, it will be converted to `number` in JSON Schema.
- If the schema is a `number()` and has a `integer` check, it will be converted to `integer` in JSON Schema.

So, if you want to create a JSON Schema that uses `integer`, you can use the `integer` check:

```dart
final schema = object({
  'age': number().integer(),
}).toJsonSchema();

// => {
//   type: 'object',
//   properties: {
//     age: {type: 'integer'}
//   },
//   required: ['age'],
// }
```

## Nullable Types

Nullable types are converted to JSON Schema using the `oneOf` keyword. This means that the schema will accept either the type or `null`. For example:

```dart
final schema = object({
  'name': string().nullable(),
}).toJsonSchema();
// => {
//   type: 'object',
//   properties: {
//     name: { anyOf: [{type: 'string'}, {type: 'null'}]}
//   },
//   required: ['name'],
// }
```

## Recursive Types

During the generation of the schema Acanthis handles recursive types by using the `$ref` keyword. This means that the schema will reference itself when it encounters a recursive type. For example:

```dart
final schema = object({
  'name': string(),
  'children': lazy((parent) => parent.list())
}).toJsonSchema();

// => {
//   $defs: {
//     children-lazy: {
//       type: 'array',
//       items: {
//         type: 'object'
//         properties: {
//           name: {type: 'string'},
//           children: {$ref: '#/$defs/children-lazy'}
//         },
//         required: ['name', 'children']
//       }
//     }
//   },
//   type: 'object',
//   properties: {
//     name: {type: 'string'},
//     children: {$ref: '#/$defs/children-lazy'}
//   },
//   required: ['name', 'children'],
// }
```

## Metadata

As seen in the [metadata](/metadata) section, you can add metadata to your schema. This metadata is also converted to JSON Schema for example:

```dart
final schema = object({
  'name': string(),
  'age': number(),
}).meta(MetadataEntry(
  title: 'Person',
  description: 'This is a schema for a person.',
)).toJsonSchema();

// => {
//   type: 'object',
//   properties: {
//     name: {type: 'string'},
//     age: {type: 'number'}
//   },
//   required: ['name', 'age'],
//   title: 'Person',
//   description: 'This is a schema for a person.',
// }
```

## `toPrettyJsonSchema()`

`String toPrettyJsonSchema(int indent = 2)`

The `toJsonSchema` method returns a `Map<String, dynamic>` that can be converted to a JSON string using the `jsonEncode` method. You can use the `prettyPrint` parameter to format the output:

```dart
final schema = object({
  'name': string(),
  'age': number(),
}).toPrettyJsonSchema();
// => {
//   "type": "object",
//   "properties": {
//     "name": {"type": "string"},
//     "age": {"type": "number"}
//   },
//   "required": ["name", "age"],
// }
```
