# Schema export compatibility

Runtime validation can execute Dart code. JSON Schema and OpenAPI describe JSON
data, so they cannot express every runtime rule. Choose an export API explicitly:

| API | Contract | Unsupported behavior |
| --- | --- | --- |
| `exportJsonSchema(mode: ...)` | Audited JSON Schema 2020-12, input or output | Throws `AcanthisSchemaExportException` with a path and reason |
| `exportOpenApiSchema(mode: ...)` | Audited OpenAPI 3.1 Schema Object, input or output | Same supported subset and rejection behavior |
| `toJsonSchema()` / `toPrettyJsonSchema()` | Legacy best-effort description | May omit runtime semantics; no equivalence guarantee |
| `toOpenApiSchema()` | Legacy best-effort description, including `nullable` | May omit runtime semantics; no equivalence guarantee |

## Supported behavior

“Supported” below assumes every nested schema, constraint, and default is also
exportable. Both audited exporters use the same support rules.

| Behavior | Runtime | Audited exports |
| --- | --- | --- |
| JSON primitives, objects, lists, tuples, nullable values | Supported | Supported |
| Required/optional fields, valid defaults, PATCH omission | Supported | Supported; input/output modes differ |
| Strip, preserve, reject unknown keys; typed extra values | Supported | Supported; choose the appropriate mode |
| Numeric bounds; JSON scalar equality/enumeration; boolean checks | Supported | Supported |
| `string().notEmpty()`; list length bounds | Supported | Supported |
| Ordinary unions; stable recursive objects | Supported | `anyOf`; local `$defs` / `$ref` |
| General string lengths, formats, regexes | Supported | Rejected |
| Dart integer/double representation checks, `multipleOf` | Supported | Rejected |
| Object property counts, list uniqueness | Supported | Rejected |
| Coercion, transformations, pipes | Supported | Rejected |
| Custom/async checks, selected-field rules, variant guards | Supported | Rejected |
| Dart instances and `DateTime` schemas | Supported | No audited JSON contract |

String length is a notable boundary: Dart counts UTF-16 code units while JSON
Schema counts Unicode code points. Export rejects general length constraints
rather than silently changing their meaning. Repeated supported constraints
remain conjunctive instead of overwriting one another.

## Input versus output

```dart
final schema = object({
  'name': string().notEmpty().withDefault('Guest'),
  'score': number().gte(0),
});
final input = schema.exportJsonSchema(mode: AcanthisSchemaMode.input);
final output = schema.exportJsonSchema(mode: AcanthisSchemaMode.output);
```

The input contract permits the defaulted `name` to be absent or null. Successful
parsed output contains a non-null `name`. The default strip policy accepts extra
input keys but removes them from output. Exported defaults are descriptive: an
external JSON Schema validator does not necessarily insert them or strip keys.

Use input mode for incoming JSON and output mode for successful parsed JSON.
Neither mode describes best-effort values from invalid outcomes.

## Handle unsupported schemas

```dart
try {
  string().email().exportJsonSchema(mode: AcanthisSchemaMode.input);
} on AcanthisSchemaExportException catch (error) {
  print(error); // Identifies the unsupported check and its schema path.
}
```

Treat this as a schema design decision. If you publish a simpler JSON contract,
document which additional rules the application enforces. Switching to a legacy
exporter does not make the missing semantics exact.

See [JSON Schema](/json-schema) for recursion and metadata, and
[OpenAPI](/open-api-schema) for embedding a Schema Object and preserving references.
