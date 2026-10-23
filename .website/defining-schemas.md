---
description: Choose a native schema, compose it with other schemas, and add checks or transformations.
---

# Schema reference {#defining-schemas}

Start with a factory, then add checks and compose it into larger shapes. Import these APIs from `package:acanthis/acanthis.dart`. Top-level factories are also available through the `Acanthis` facade.

```dart
final email = string().trim().email();
final account = object({'email': email, 'tags': string().list()});
```

## Types

| Schema | Parsed output | Reference |
| --- | --- | --- |
| <span id="string"></span><span id="string-formats"></span><span id="emails"></span>`string()` | `String` | [Strings](/schemas/strings) |
| <span id="numeric-values"></span>`number()`, `integer()`, `doubleType()` | `num`, `int`, `double` | [Numbers](/schemas/numbers#numeric-values) |
| <span id="booleans"></span>`boolean()` | `bool` | [Booleans](/schemas/numbers#booleans) |
| <span id="dates"></span>`date()` | `DateTime` | [Dates](/schemas/numbers#dates) |
| <span id="objects"></span><span id="extend"></span><span id="merge"></span><span id="pick"></span><span id="omit"></span><span id="partial"></span>`object({...})` | `Map<String, Object?>` | [Objects](/schemas/objects) |
| `record(keys, values)` | `Map<K, V>` | [Records](/schemas/records) |
| <span id="lists"></span>`list(element)` or `element.list()` | `List<T>` | [Lists](/schemas/collections#lists) |
| <span id="tuples"></span><span id="variadic"></span>`tuple([...])` | Heterogeneous list | [Tuples](/schemas/collections#tuples) |
| <span id="nullables"></span>`schema.nullable()` | `T?` | [Nullable values](/schemas/nullable) |
| <span id="literals"></span>`literal(value)` | The declared literal type | [Literals](/schemas/unions#literals) |
| <span id="union"></span>`union<T>([...])` | `T` | [Unions](/schemas/unions#union) |
| <span id="variant"></span>`variant<T>(guard: ..., schema: ...)` | `T` | [Guarded branches](/schemas/unions#variant) |
| <span id="template-literals"></span>`template([...])` | `String` | [Templates](/schemas/unions#template-literals) |
| <span id="recursive-objects"></span>`lazy((parent) => ...)` | The bound child output | [Recursive objects](/schemas/objects#recursive-objects) |
| <span id="instances"></span><span id="differences-to-object"></span><span id="cross-field-validation-with-refs"></span>`instance<T>()` | Existing `T` | [Instances](/schemas/instances) |
| <span id="class-schemas"></span>`classSchema<I, T>()...build()` | Constructed `T` | [Classes](/schemas/instances#class-schemas) |

Objects do not infer Dart classes from field names. The child schemas define parsed values; class schemas provide explicit mapping into domain types.

## Composition

```dart
final name = string().min(2);
final shortName = name.max(12);
final names = name.list();
final nullableName = name.nullable();
final nameOrId = name.or<Object?>([integer()]);
final nameAndAge = name.and([integer()]);
```

Native fluent methods return new schemas. A check or transform added to `shortName` does not modify `name`. Modifier order matters: `.nullable().list()` permits null elements; `.list().nullable()` permits a null list.

## Operations

| Task | API and guide |
| --- | --- |
| Parse input or check validity | [parse, tryParse, validate](/validation-results) |
| <span id="default-values"></span>Change optional fields, defaults, or PATCH behavior | [Presence and defaults](/presence-and-defaults) |
| <span id="refinements"></span><span id="refine"></span><span id="refineasync"></span>Add a predicate or several issues | [Custom validation](/schemas/refinements) |
| <span id="pipes"></span><span id="type-coercion"></span><span id="coerce-and-unions"></span>Change values or output types | [Transforms, coercion, and pipes](/schemas/transformations) |
| Compare parsed object fields | [Cross-field rules](/contextual-rules) |
| Revalidate incremental edits | [Live validation](/live-validation) |
| Attach descriptions | [Metadata](/metadata) |
| Share schemas through typed keys | [Registries](/schema-registry) |
| <span id="mocking-schemas"></span><span id="seeded-test-data"></span>Generate validated samples | [Mock data](/schemas/mocking) |
| Export or import a JSON contract | [JSON Schema](/json-schema) and [OpenAPI](/open-api-schema) |

## Custom schemas

Extend `Schema<Input, Output>` when defining a new schema implementation. Implement raw-value `parse(Object?)` and outcome-returning `tryParse(Object?)`. Capabilities such as checks, defaults, lists, and nullability are opt-in mixins. The factory alias `AcanthisType` is not a generic schema base.

See the repository's `docs/v2/` reference notes for implementation contracts. Most application schemas can be built from native types and pipes.
