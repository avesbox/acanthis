# Numeric schemas

`number()`, `integer()`, and `doubleType()` produce `Schema<num, num>`,
`Schema<int, int>`, and `Schema<double, double>` implementations respectively.
The public class aliases are `AcanthisNumber`, `AcanthisInt`, and
`AcanthisDouble`, backed by `AcanthisNumeric<T extends num>`. The same factories
are available through `Acanthis` and the existing `AcanthisType` facade alias.

```dart
final num amount = number().coerce().finite().gte(0).parse('12.5');
final int quantity = integer().coerce().positive().parse('3');
final double ratio = doubleType().coerce().between(0.0, 1.0).parse('0.5');
```

See `example/v2_number.dart` for a runnable example and a custom message map.

## Operations

Numeric checks include `lte`, `gte`, `lt`, `gt`, `between`,
`positive`, `negative`, `nonPositive`, `nonNegative`, `integer`, `double`,
`multipleOf`, `finite`, `infinite`, `nan`, `notNaN`, `enumerated`, and `exact`.
All fluent methods retain `T`, fixing V1's raw-return widening after methods
such as `positive()` and `finite()`. An integer check on `number()` still tests
runtime representation: `2` passes, but `2.0` does not. It does not change the
schema's static output from num to int; use `integer()` for that contract.

`pow(int exponent)` and `Transform<T, T>` custom transformations preserve the
output type. An integer power result that cannot be represented as int produces
a `transform` issue, with `operation: pow` and `exponent`, and retains the
previous typed value as recovery. Representable integer reciprocals, such as
`1^-1`, produce int output. Directly calling `PowerNumberTransform.apply` on an
incompatible result throws StateError; the schema uses its fallible `tryApply`
hook to produce diagnostics.

Power arithmetic otherwise follows [Dart's pow semantics](https://api.dart.dev/dart-math/pow.html),
including platform integer overflow and floating-point overflow. It does not
add arbitrary-precision numeric outputs or promise overflow-checked arithmetic.

`refine(onCheck: ..., error: ..., name: ...)` adds a typed predicate, with an
optional per-check catalog message. Use `withCheck(Check<T>)` for check objects;
`transform((value) => value * 3)` accepts a typed callback. Use
`withTransform(Transform<T, T>)` for transformation objects; `refineAsync` and
`transformAsync` keep their typed contracts and callback adapters. These APIs
also work on string schemas. See
[custom refinements](refinement.md) for localization and migration details.
There are no untyped operation lists or unchecked transformation output casts.

## Input and execution rules

- Strict schemas accept their declared runtime numeric type. Number accepts
  either int or double; integer rejects double input, even `2.0`; double rejects
  int input. Wrong types produce `type` diagnostics without invented recovery.
- Number coercion accepts numeric strings and retains V1's NaN/infinity parsing.
  Integer coercion accepts finite integral numeric values, integer strings, and
  integral decimal/exponent strings. It rejects fractional or saturated results
  and overflowing decimal integer strings instead of silently clamping them.
  Integral doubles use an exact round-trip check to detect native integer
  saturation. Only the ambiguous positive int64 endpoint needs a BigInt
  comparison; ordinary and representable large doubles avoid that allocation.
  Decimal/exponent fallback parsing otherwise retains double precision, as V1
  did; this is not an arbitrary-precision decimal parser.
- Double coercion converts ints and finite numeric strings. Already-typed
  double NaN/infinity values remain accepted, as in V1. Use `finite()` to reject
  non-finite values uniformly. Null, bool, containers, and arbitrary objects are
  not coerced to numbers.
- `withDefault` substitutes for null input and validates the supplied default.
  Coercion/default settings survive every fluent copy.
- `parse` stops after the first failing operation; `tryParse` collects checks
  on the current value and stops before a subsequent transformation on failure.
  `parse` returns raw output; `tryParse` returns an outcome. Validation methods return bool.
- Immutable operation nodes provide O(1) fluent appends. The selected schema
  materializes a typed fixed-length execution list once on demand. Chains made
  entirely of built-in NumberCheck operations use a direct predicate loop and
  allocate a sink only upon failure. Mixed/custom/async operations retain the
  general execution path. Each invocation owns its sink and context; concurrent
  and reentrant parsing cannot share diagnostics.
- Async steps execute sequentially. Synchronous entry points reject schemas
  containing async steps before running callbacks. Custom callback exceptions
  propagate and are not converted to input or power diagnostics.
- Enumeration inputs are snapshotted and exposed as immutable lists. Membership
  retains List.contains semantics for NaN and int/double equality. A zero
  `multipleOf` divisor is rejected at definition time; negative divisors retain
  V1 behavior. Reversed `between` bounds retain V1's empty-interval semantics.
- All numeric codes have default English catalog messages. User catalogs can
  override or replace these at presentation. Metadata contains frozen schema
  constraints, not the submitted value. No legacy error-map or message-argument
  compatibility layer is introduced.

## Verify numeric behavior

`test/number_test.dart` covers typed fluent returns, bounds, coercion and defaults,
operation order, transformation gating, diagnostics, async behavior, and long
chains. Its integer-coercion checks include an independent BigInt reference.
The checked-in numeric references include a frozen V1 compatibility oracle and
a V2 regression snapshot. Both exercise typed predicate results through the
parsing entry points. They do not compare the changed V1 parsing/recovery API.

```sh
dart test test/number_test.dart --reporter failures-only
dart test test/number_test.dart --compiler exe --reporter failures-only
dart analyze --fatal-infos
dart run example/v2_number.dart
```

Regenerate `test/fixtures/number_v2_reference.json` from the current V2 library with
`dart run tool/generate_v2_number_reference.dart`. The generator runs directly
against `lib/`; it does not load V1 or modify the frozen V1 fixture.
V2 snapshots record current behavior, so review changes before accepting a new
baseline. Historical source hashes in
`number-source-hashes.json` identify the earlier audit snapshot, not the current
working tree. See the [benchmark guide](../../benchmark/README.md) for current
comparison commands and measurement limits.
