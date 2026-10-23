# Typed pipelines

`source.pipe(target, transform: converter)` validates the source, passes its
parsed output to the typed converter once, then validates the converted result
with the target. Parsing returns the target's raw output type. `validate` returns
a boolean. Invalid input stops before conversion, including source failures that
have typed recovery values. Invalid target results retain only the target's
properly typed recovery, when available.

```dart
final age = string().trim().pipe(integer().gte(18), transform: int.parse);
final int parsed = age.parse(' 21 ');
final form = object({'age': age, 'name': string()});
```

Pipelines support chained `pipe` calls, checks, same-type transformations,
metadata, nullable/list composition and defaults. A pipeline default is an output
value: when input is null or its object field is missing, the default bypasses
the source and converter, and still passes through target validation and transforms.
Use `.withDefault(null)` for an explicit default on nullable output. Defaults
declared only on the source do not make the pipeline an optional object field.

Async source, target or pipeline operations require `parseAsync`, `tryParseAsync`
or `validateAsync`. The converter is synchronous, as in V1. All stages inherit
validation context and cooperate with cancellation. `FormatException` from the
converter becomes a `transform` issue; other callback exceptions propagate.

An unbound parent-dependent lazy definition must be bound explicitly before
piping, or return a pipeline from its resolver. Pipelines containing opaque
converters cannot be audited by JSON/OpenAPI export; export rejects them without
invoking the converter. V1's pipeline export methods were unimplemented stubs.

## Mock generation

Synchronous pipelines and class schemas support `.mock()`,
`.mock(seed)` and bounded `.mockSeeded(seed: ..., maxAttempts: ...)`.
The engine generates and validates a source value, runs each converter once per
attempt, validates the target, then runs the pipeline's own checks/transforms.
Chained source pipelines share one attempt budget. Unlike V1's `.mock(seed)`,
mapped output is validated. Invalid inputs skip conversion; invalid outputs and
converter `FormatException`s retry within the budget. Programming errors and
cancellation propagate.

The original source must support ordinary bounded mock generation. Opaque
source checks/transforms need an explicit `generators` override; async schemas
and lazy resolvers remain rejected. Mappers, output validation callbacks and pipeline operations are
explicitly executed as part of this convenience API. Keep them pure and
deterministic for reproducible seeds. Output bounds inspect actual collections
and described instance fields; an output instance needs no mock factory because
the mapper already constructs it. Hidden object state and callback runtime
cannot be bounded by schema inspection.

Mocking generates through the source instead of selecting a configured pipeline
default. Returned outputs are not reparsed as source inputs: the two types can
differ. Pipelines can also appear inside object fields, lists, records, tuples,
nullable schemas and plain unions. Containers parse generated child inputs and
retain typed outputs without reparsing those outputs as inputs. Nested null
inputs follow ordinary pipeline default behavior. All stages share the outer
attempt budget. A `generators` override returns a raw input for its exact schema;
see [bounded mocks](metadata-and-mocks.md#bounded-mocks).
