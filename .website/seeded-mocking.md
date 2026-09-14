# Bounded seeded mocking

Use `schema.mockSeeded(seed: 42)` for deterministic generation with a validation
guarantee. Every returned value passes the schema; the generator validates both
the candidate and returned value. Repeatability is for the same schema, limits,
seed and Dart SDK, not a promise of identical random sequences across SDK releases.

```dart
final schema = object({
  'name': string().min(2).max(12),
  'age': integer().gte(18).lte(65),
});
final value = schema.mockSeeded(seed: 42);
assert(schema.tryParse(value).success);
```

The supported subset is explicit:

- Standard string schemas with min/max/exact length, required/nonempty, email,
  and exact-value checks; numeric `int`, `double`, and `num` schemas with `gte`,
  `lte`, and exact-value checks; booleans and their true/false checks.
- Primitive string/numeric/boolean literals, and nullable primitive schemas.
- Ordinary dynamic-valued object schemas with supported children and no
  cross-field callbacks; tuples with supported children.
- Lists of string, integer, double, num, bool, dynamic, or dynamic-valued maps.
  List length/min/max/unique checks are supported for string, int and dynamic
  element types. Other operations or generic combinations fail explicitly.

Numeric sampling is restricted to `[-1000, 1000]` intersected with schema bounds.
Email sampling uses deterministic `u<number>@example.com` addresses. This is a
bounded candidate generator, not a general constraint solver: a satisfiable
schema can lie outside its search domain.

Defaults are still handled by validation; they are not assumed to be valid.
Dates, unions, templates, pipelines, instance schemas, lazy recursion, custom
subclasses, arbitrary refinements, transformations, async checks and cross-field
callbacks are outside this contract. Opaque operations are rejected before
execution, so a callback that never returns is not invoked by the generator.

Defaults are 64 attempts, depth 16, collection length 256, and 4096 visited nodes
per schema inspection or candidate. Override them using `maxAttempts`,
`maxDepth`, `maxCollectionLength`, and `maxNodes`. Contradictions, unsupported
features, exhausted search and resource limits throw `AcanthisMockException`
with a `reason`; no invalid value is silently returned.

Legacy `mock([seed])` remains a compatibility, best-effort API and does not gain
this validation guarantee. Its list generator now has a finite attempt cap,
samples repeated values when uniqueness is not requested, and reports impossible
or unsuccessful generation rather than looping forever on a finite domain.
