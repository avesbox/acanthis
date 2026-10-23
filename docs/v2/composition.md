# Composition

```dart
final id = Acanthis.union<Object?>([
  Acanthis.string(),
  variant<num>(guard: (input) => input is num, schema: Acanthis.number()),
]);
final pair = Acanthis.tuple([Acanthis.string(), Acanthis.number()]);
final row = pair.variadic(); // One string followed by zero or more numbers.
final label = Acanthis.template(['item-', Acanthis.integer()]);
```

Top-level `union`, `variant`, `tuple`, and `template` factories are also exported.
Schemas support `.or<T>(alternatives)` and `.and(elements)` composition.

Unions try guarded variants first, then plain schemas, preserving order within
each group. The first successful branch supplies the output. Failed branches
remain in the union issue, including guards that did not match. Empty unions
reject every input. Callback exceptions propagate as programming errors.

Tuples require the exact declared length. `.variadic()` repeats the last schema
zero or more times after the fixed prefix; an empty tuple cannot be variadic.
Issues carry element indices. Collecting failures never fabricate missing child
values or return a shortened recovery list.

All three schemas use V2's immutable checks, transformations, defaults, nullable
and list composition. Async children and operations require async entry points.
Definition lists are copied at construction.

Templates escape literal text and match the complete input. Each schema segment
then parses its substring, including built-in checks, custom refinements and
async checks. Numeric substrings become numbers, boolean substrings become
booleans, and nullable segments accept the text `null`. Unions try each branch
with its own converted substring. Segment transformations feed subsequent
segment checks but do not rewrite the template's returned string.

Boundaries are chosen by shape before callbacks run. The leftmost segment takes
the longest substring allowing the remaining shapes to match. Refinement failure
does not retry alternative splits or repeat callbacks. Use literal separators
when segment boundaries must be unambiguous. Throwing parsing stops at the first
failure; collecting parsing visits all segments. Issue paths include the index
in the original parts list, including literal entries.
Supported shapes include strings, explicit string patterns and enumerations,
numbers, integers, numeric enumerations, booleans, literals, nullable scalars,
unguarded unions, and nested templates. Guarded segment unions are rejected.

Audited JSON Schema/OpenAPI export supports plain unions, tuples, variadic
tuples and templates with unconstrained scalar segments. Segment refinements,
guards, custom operations and coercion are rejected when they cannot be
represented. Schema import now supports `prefixItems` and
regular expression `pattern` assertions for composition round trips.
