# Instances and class schemas

`instance<T>()` validates an existing Dart object. A successful parse returns
the same instance unless an explicit root transform replaces it. Subtypes of
`T` are accepted; unrelated inputs return a `type` issue without invoking getters.
Both top-level factories and `Acanthis.instance<T>()` /
`Acanthis.classSchema<I, T>()` are exported.

```dart
final userType = instance<User>()
    .field('name', (user) => user.name, string().trim().min(2))
    .field('age', (user) => user.age, integer().gte(18));
final User user = userType.parse(existingUser);
final bool valid = userType.validate(existingUser);
```

Fields run their entire child schema once, including nested objects, lists,
defaults, checks and transforms. The getter is called once per visited field.
Child transformations validate their output but never assign it back to the
instance. `optional: true` skips a null getter value completely, including child
defaults. Without that flag, null goes through ordinary child validation.
Field names are literal path segments; nested issues and union branches retain
their complete paths below that segment.

Field validators, refinements and root transforms execute in fluent declaration
order. A field following a successful root transform reads the transformed
instance. Collecting validation continues after failures until a transform
boundary; throwing parsing stops on the first failed operation. Known instances
remain typed recovery values even if their field validators cannot recover.
`fieldPolicy: first` limits child checks, while `objectPolicy: first` stops at a
failed field. Root checks retain the shared operation executor's field policy.

`withDefault(instance)` substitutes null input and missing object fields. The
default is validated normally. An unrelated non-null input is still invalid;
defaults do not fabricate recovery objects. Nullable output types can declare
an explicit null default. `toMap(value)` extracts the original getter values
into a fresh map; it neither validates nor serializes those values. Optional
null fields are included, and repeated field names keep their last extracted
value while all declarations still participate in validation.

## References

```dart
final schema = userType
    .withRefs((refs) => refs.ref('minimumAge', (_) => 18))
    .refineWithRefs(
      (user, refs) => user.age >= refs.call<int>('minimumAge'),
      'User is too young',
      name: 'app.minimumAge',
    );
```

Reference getters read the current instance. They are independent of validated
fields and are evaluated when requested; they do not receive child transforms.
`withRefs` takes an immutable snapshot and merges with existing definitions.
Later changes to a retained builder cannot alter earlier schemas. Adding a
reference with the same name replaces it in the derived schema.

`refineWithCause((value, refs) => String? message)` reports its returned string
as the issue's default message, or passes when it returns null. Its optional
`name` is the diagnostic code, so catalogs can override the message normally.
Cause messages are private to each invocation. Missing references, incorrect
reference casts, getter errors and callback programming errors propagate.

## Mapping input to a class

```dart
final userSchema = classSchema<Map<String, Object?>, User>()
    .input(object({'name': string().trim(), 'age': integer()}))
    .map((data) => User(data['name'] as String, data['age'] as int))
    .validateWith(userType)
    .refine(onCheck: (user) => user.name != 'Reserved', name: 'app.reservedName')
    .build();
final User user = userSchema.parse({'name': 'Ada', 'age': 21});
```

The builder returns `AcanthisPipeline<I, T>` and uses the existing
[pipeline](pipeline.md) executor. `input` and `map` are required; without
`validateWith`, the output is checked by `instance<T>()`. Mapping runs exactly
once after successful input validation. Invalid input never invokes the mapper
or substitutes a default recovery object. Output fields retain their paths and
typed recovery. Mapper `FormatException`s become `transform` issues; other
programming errors propagate.

`refine` appends a check to the current output validator. A subsequent
`validateWith` replaces that validator, including its earlier refinements,
matching V1. Custom schemas without check composition are supported through an
identity pipeline. `defaultOutput(value)` bypasses input validation and mapping
only for null input, and still validates the default with the output schema.
Explicit nullable null defaults are supported. Each `build()` snapshots the
builder settings, so later builder edits do not change existing pipelines.

Async descendants or operations require async parse/validate methods before
any getter runs. Context and cancellation flow through field validators and
class pipelines. Cancellation is cooperative and never becomes a validation
issue. Synchronous third-party child schemas work inside async instances;
parent-dependent lazy schemas must be bound before use as field validators.

Instances and class pipelines support metadata, typed registry bindings,
nullable/list composition and checks/transforms through the V2 shared APIs.
Treat instances and defaults as caller-owned values; validation does not clone
them or undo callback side effects.

## Field-based export

`instanceType.toJsonSchema()` and `toOpenApiSchema(mode: ...)` export V1's
declared field representation: `type: object`, `properties`, and `required`
for fields without `optional: true`. Nested instances, collections, metadata,
and fresh export snapshots participate in the existing exporter. Export never
invokes getters or the mock factory and does not require a factory.

This describes JSON fields, not the Dart runtime type or a constructor. Both
modes preserve declared requiredness and pass their mode to child schemas.
Instance defaults are not serialized or evaluated. Optional getter values that
are null skip validation; describe the child as nullable if null should also
appear in the JSON representation. Duplicate names retain the last property's
description, with required names deduplicated, matching V1's property projection.

Child schemas still use V2's strict export rules. Unsupported child checks,
Dart int/double representation restrictions, and UTF-16 length checks report
an export error at the child's path. Instance root checks, transforms and async
operations also reject export rather than silently omitting their constraints.

## Constructing mocks

Dart getters cannot identify or invoke an arbitrary constructor. Supply it
explicitly, then mocks can use the described fields:

```dart
final mockable = instance<User>()
    .field('name', (u) => u.name, string().min(2))
    .field('age', (u) => u.age, integer().gte(18).lte(80))
    .withFactory((fields) => User(fields['name'] as String, fields['age'] as int));
final User sample = mockable.mockSeeded(seed: 42);
```

Factories receive an unmodifiable root map of generated, parsed field values.
Nested `List<int>` and domain instances retain their runtime types. Optional
fields may be omitted; the factory should handle absent values. Factories and
field descriptions survive fluent clones, metadata, references and defaults.
Nested instance/list/object/record/tuple/union mocks use the same engine.

The entire schema is audited before any factory runs. Existing restrictions on
opaque checks, transformations, async callbacks and lazy resolvers still apply.
Invalid generated fields skip construction; invalid constructed instances retry
up to `maxAttempts`. Collection, node and depth bounds also inspect the result's
declared fields and defaults, and reject cycles. Hidden domain state and time or
resources spent inside user factories cannot be bounded by field descriptions.
Getters and factories should be pure, and deterministic for reproducible seeds.
Constructor programming errors propagate; cancellation remains control flow.
Without `withFactory`, mocking throws an explanatory `AcanthisMockException`.

## Class-schema export and generation

A class mapper can rename, combine or discard input fields. Its input contract
and described output fields are therefore different, and output refinements can
further restrict input acceptance. They can be inspected explicitly:

```dart
final inputDescription = userSchema.inType.toJsonSchema();
final outputDescription = userSchema.outType.toJsonSchema(
  mode: AcanthisSchemaMode.output,
);
final User sample = userSchema.mockSeeded(seed: 42);
```

Class `.mock()` and `.mockSeeded()` generate and validate source values, invoke
the mapper, and validate the output with bounded retries. The mapper constructs
the object, so the output instance validator does not need `withFactory`.
Output refinements run normally; source shapes must support bounded generation.
See [pipeline mock generation](pipeline.md#mock-generation) for bounds and
callback behavior. V1's `.mock(seed)` existed but skipped output validation.

Direct class-pipeline export remains rejected. V1's pipeline JSON/OpenAPI export
methods were `UnimplementedError` stubs. Explicit input/output descriptions do
not claim to capture constraints hidden inside the mapper. Unsupported child
schemas or output refinements retain their normal export errors.
