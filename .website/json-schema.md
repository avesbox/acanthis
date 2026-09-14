# JSON Schema

## Audited input and output contracts

Use `exportJsonSchema` to target JSON Schema 2020-12 with an explicit contract:

```dart
final schema = object({
  'name': string().notEmpty().withDefault('guest'),
  'score': number().gte(0).lte(100),
});
final input = schema.exportJsonSchema(mode: AcanthisSchemaMode.input);
final output = schema.exportJsonSchema(mode: AcanthisSchemaMode.output);
```

The input contract accepts omitted defaulted fields and nulls replaced by valid
defaults. The output contract describes the parsed values, including inserted
defaults and stripped unknown properties. This API supports structural JSON
schemas, numeric bounds and enumeration, scalar equality, boolean checks,
nonempty strings, and list lengths. Repeated constraints are combined with
`allOf`; overlapping unions use `anyOf`.

Stable recursive objects export through local `$defs` and `$ref`:

```dart
final tree = object({
  'value': number().gte(0),
  'children': lazy((parent) => parent.list()),
});
final exported = tree.exportJsonSchema(mode: AcanthisSchemaMode.input);
```

Lazy callbacks must reuse stable schemas. Rebuilding the parent on every level
is rejected after 64 active schema levels. Use deterministic callbacks and
configure the parent before recursion.

Unsupported behavior throws `AcanthisSchemaExportException` with a schema path
and reason. General string length checks remain unsupported because Dart counts
UTF-16 units and JSON Schema counts Unicode code points. Other exclusions include
coercion, transformations, custom/async checks, formats, regexes, Dart int/double
representation checks, `multipleOf`, object property counts, and list uniqueness.
These APIs describe JSON values, not arbitrary Dart objects.

## Legacy best-effort export

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

Nullable types are converted to JSON Schema using the `anyOf` keyword. This means that the schema will accept either the type or `null`. For example:

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

During the generation of the schema, Acanthis handles recursive types by using the `$ref` keyword. This means that the schema will reference itself when it encounters a recursive type. For example:

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
