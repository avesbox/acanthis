# Type safety analysis

## Current guarantees

`AcanthisType<O>` tracks **output**, while raw external input is `dynamic`. Same-output transforms receive and return `O`. A pipeline mapper is `T Function(O)` and its output validator is `AcanthisType<T>`, so the connection between validated input, mapper, and validator already has meaningful static typing. `AcanthisList<T>` returns `List<T>`. Nullable wrapping changes output to `T?`. Instance getter registration connects `P Function(T)` with `AcanthisType<P>`. A typed union chooses a common output supertype and runtime-checks its alternatives; it does not model a language-level union type.

`SchemaKey<T,S extends AcanthisType<T>>` records both output and concrete schema type. The owned registry checks those types even when tokens are widened. The existing negative binding/output/nested-binding compiler fixtures and AOT example passed during this review. Retain this design; it is stronger than an untyped string-to-schema registry.

The sealed valid/invalid outcome model already distinguishes validation success. A failed result may carry recovery of Dart type `T` that does not satisfy the schema, or no recovery at all. `.value` on the abstract outcome is convenient for legacy clients but is not proof of success. Match `AcanthisValid<T>` before passing output to application code.

```dart
int? acceptedAge(AcanthisOutcome<int> outcome) => switch (outcome) {
  AcanthisValid<int>(:final value) => value,
  AcanthisInvalid<int>() => null,
};
```

This uses existing Dart sealed classes and property patterns. It does not require a new result representation or TypeScript-style conditional types.

## Verified losses and runtime boundaries

| Area | Actual limitation | Remedy |
| --- | --- | --- |
| Numeric fluent methods | `positive`, `negative`, `nonPositive`, `nonNegative`, `integer`, `double`, `multipleOf`, `finite`, `infinite`, `nan`, and `notNaN` declare raw `AcanthisNumeric`, widening to the bound `num`; runtime generic can still be `int` | Preserve `AcanthisNumeric<T>` where the operation is a predicate and does not change representation. These checks do not narrow `number()` to `int` merely by returning a more specific schema. |
| Pipeline | `AcanthisPipeline<I,O>` extends `AcanthisType<O?>` although input→mapper→output success need not be nullable | Complete the contract first; separately migrate exact output to `O`, with `O` itself nullable where appropriate. |
| Object | Raw child schema map is unrelated to `V`; pure cast views can defer a wrong type until after success | Bind homogeneous children to `AcanthisType<V>` or validate setup compatibility; validate passthrough output before certifying success. |
| Tuple | Arbitrary list of heterogeneous schemas produces `List<dynamic>` | Keep honest list typing. A future explicitly arity-limited record API could improve positions, but is new functionality, not an inferred arbitrary mapped type. |
| Union | `List<dynamic>` permits heterogeneous schemas/variants but shifts compatibility checks to construction; inferred `or<T>` may fall back to broad types | Encourage explicit common `T`, keep checked construction. A typed list factory is an optional additive convenience; do not replace alternatives with unchecked casts. |
| Rules and refs | String/path-selected values are read using caller-selected `value<T>`/`RefAccessor.call<R>` casts; rule context type is cast from Zone `Object?` | Document checked runtime boundaries; typed field/ref tokens can be considered with a concrete need. Declared paths verify existence, not selected Dart type. |
| Lazy | Parent-dependent resolver and list-of-map conversion assume more than generic `O` establishes | Bind internally, preserve output typing, validate async capability, remove unconditional list reinterpretation. |
| Coercion | Accepted raw values depend on runtime configuration rather than a single Dart type | Keep unknown-input boundary and typed output; an input generic cannot precisely encode all accepted values/ranges by itself. |
| Type-changing numeric helpers | `pow` uses `math.pow(...) as T` (`number.dart:256–260`); negative exponents can produce a double even for integer input | Characterize and decide checked failure versus an explicit wider-output pipeline. Do not silently pretend every power preserves `int`. |

Two fresh compiler probes on Dart 3.13.3 failed as expected:

```dart
// Current API: compile error, num cannot be assigned to int.
final int value = integer().positive().parse(1);

// Current API: compile error, int? cannot be assigned to int.
final int converted = string()
    .pipe(integer(), transform: int.parse)
    .parse('1');
```

These are observed static limitations, not hypothetical runtime failures. The runtime numeric probe preserves `AcanthisNumeric<int>`; static return declarations cause the loss. [Evidence](evidence/runtime-probes.md) also demonstrates a typed map certifying success before a later read casts incorrectly.

## Should `Schema<I,O>` be introduced?

**Original review recommendation:** avoid a package-wide migration as a prerequisite for fixing the existing implementation. **Follow-up rewrite target:** the user's explicit preference for an extensible input/output base is developed in the [Zod/ArkType comparison and compiler experiment](zod-arktype-schema-contract.md). That proposal selects `Schema<I,O>` with unknown-input parse boundaries and exact outputs, while documenting Dart's covariance limit on naive schema-to-schema composition. The alternatives below explain the original compatibility tradeoff; they are not a prohibition on the revised rewrite design.

Input/output tracking makes stage domains explicit. Current pipelines already type their mapper input/output and output validator. The reproduced bugs come from skipped execution, incomplete members, raw returns, unconstrained map children, and recovery assumptions. Adding `I` would not correct those implementations by itself, and does not guarantee all producer/consumer input relationships at compile time in Dart.

An input type can describe either an external accepted raw value or a post-coercion/pre-operation value; these differ. For example, coercive integer parsing may accept int, integral double, or a parseable string, with accepted values constrained at runtime. Dart has no general `int | double | String` type. `Object?` as `I` is an honest untrusted boundary but adds no input restriction. `num` would exclude valid string coercion. A date schema currently coerces by default and accepts string/int/DateTime; it has the same issue.

Nullable values and optional fields are also distinct: omitting a map key is not a `T?` value, so `Schema<I?,O?>` does not model requiredness. Pipelines with output defaults accept missing/null input by bypassing the input stage; that is a presence contract, not simply input generic substitution.

### Alternatives

| Alternative | Additional guarantee | Cost and inference limit |
| --- | --- | --- |
| Keep output-only public schemas, fix concrete returns and boundaries | Exact list/primitive/nullable outputs, typed mappers and registry tokens, successful-output validation | Lowest migration cost. Unknown raw inputs remain runtime-validated, which is the purpose of validation. Recommended. |
| Add an internal typed stage `I -> O` only for already-validated values | Statically connects a typed stage producer and consumer without raw conversion | Useful if a real new composition primitive needs it. Not needed solely to rename current pipelines. Public raw parse still needs a separate boundary. |
| Introduce `Schema<I,O>` throughout public API | Can restrict callers for schemas with a single accepted input type | Every wrapper/factory/registry/custom subclass changes. Coercion requires broad inputs; Dart cannot infer record shapes from arbitrary maps or synthesize arbitrary union inputs. High API and migration cost. |
| Erase both sides to `dynamic` and cast during composition | None | Easier implementation at the expense of static correctness and more runtime errors. Rejected. |

Dart class generics are covariant unless restricted by how they are used; widening a schema does not remove runtime argument checks. An internal `Schema<I,O>` represented as a class does not automatically acquire contravariant input behavior like a function type. Typed function parameters and narrow binders should be used deliberately, with positive and negative compiler fixtures. Do not assume an associated `InputOf<S>`/`OutputOf<S>` type operator or a mapped record type exists.

## Output and recovery migration

Keep `AcanthisValid<O>.value` exact. Internally return existing outcomes where recovery can be absent. When a child invalid result lacks recovery, parent collectors merge its issues and avoid reading `.value`; if they cannot construct the complete typed parent, return `withoutValue`. This retains non-null successful output without requiring arbitrary fallbacks or widening every schema to nullable.

Existing `AcanthisOutcome<T>.value` must remain until an explicitly breaking result-API decision. Deprecating failure recovery access or adding a safe recovery accessor is optional and not required for F04. Removing the getter from the base sealed class would break `.value` calls and downstream custom code; introducing a parallel success/failure hierarchy would duplicate existing types unnecessarily.

For legacy pipelines, preserve `O?` for a compatibility release while implementing the missing methods. A major release may change the superclass to `AcanthisType<O>`. A source-compatible additive exact-output factory is another option if users need the guarantee earlier; its extra name is justified by the distinct output contract, but should not be created speculatively. Existing `.pipe` callers can migrate after compiler fixtures identify nullable callbacks, `MetadataEntry<O?>`, typed registry keys, and list element changes.

## Required compile-time checks

Keep the existing registry negative-fixture runner. Add separate compiler fixtures (not ordinary test assertions about runtimeType):

1. Numeric predicate chains preserve `int`/`double`; `number().integer()` remains `num` unless a distinct narrowing operation is explicitly introduced.
2. `list`, nullable wrappers, defaults, and metadata preserve output and concrete fluent methods where intended.
3. Wrong pipeline mapper input/output types are rejected; two-stage pipeline chaining accepts the exact previous output according to legacy versus exact contracts.
4. Homogeneous typed object construction rejects string-producing fields for `int` maps; heterogeneous `object` stays valid.
5. Valid outcome pattern matching yields exact `T`; failed recovery is never presented by an example as certified output.
6. Custom schema/check subclasses still compile using supported legacy hooks; widened generic schema/token references retain runtime guards.

Assert the intended diagnostic and relevant source location, not merely a nonzero compiler exit code. Analyze/compile positive examples too. A negative fixture rejected because of an unrelated import error is not evidence of type safety.
