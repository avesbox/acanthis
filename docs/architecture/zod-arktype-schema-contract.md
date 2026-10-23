# Zod, ArkType, and an extensible `Schema<I, O>` base

## Decision for the rewrite design

The requested base-class model is appropriate: **use an extensible abstract `Schema<I, O>` as the shared parsing contract, with inherited implementations of `parse`, `parseAsync`, `tryParse`, and `tryParseAsync`.** Keep typed definitions and specialized execution behind that base. Generic input/output tracking and preserving the existing fast paths are compatible goals.

This refines the original review's conservative output-only recommendation. That recommendation concerned avoiding an unnecessary package-wide migration while patching the existing implementation. The follow-up now explicitly selects a redesigned, extensible base as a target. `I` must have documented semantics, and the redesign still needs compatibility and performance gates.

This is a design proposal and compiler experiment, not an implementation in `lib`. The original implementation currently resides under `v1/lib`, and the root `lib/acanthis.dart` is empty. No moved/deleted library files were restored or changed. Earlier review results describe the original snapshot, not a runnable baseline for the currently empty root library.

## What the reference libraries actually establish

Checked against official documentation and public source on 2026-10-13. Source links to `main` describe the inspected code, not a pinned release or a permanent API guarantee. No comparative library performance claims are made.

### Zod

Zod's core has `$ZodType<Output, Input>` with separate schema definition and internal execution information. The fluent `ZodType` layer extends that core and exposes the four familiar parse/safe-parse methods. This supports a shared base with input/output tracking, while separating the public fluent surface from execution internals. [Core documentation](https://zod.dev/packages/core), [fluent package documentation](https://zod.dev/packages/zod).

Crucially, the inspected fluent signatures take `unknown` for ordinary parsing. `Input` does not restrict `parse` to already correctly typed data. Zod separately provides typed decoding signatures. This is the relevant distinction for Acanthis's untrusted-input boundary. [Fluent schema source](https://github.com/colinhacks/zod/blob/main/packages/zod/src/v4/classic/schemas.ts).

Zod's four parse entry points invoke the internal runner with a sync/async context; sync calls reject a returned promise, while async calls await it. Throwing versus safe-result behavior is decided at the boundary. This is evidence for common semantics, not a requirement that Acanthis replace its direct throwing compiler with an issue-collecting runner. [Parsing source](https://github.com/colinhacks/zod/blob/main/packages/zod/src/v4/core/parse.ts).

### ArkType

ArkType exposes a callable schema returning output or `ArkErrors`, a throwing `.assert`, and a typed-input `.from`. It separately exposes inferred input/output information. Its pipeline and input/output predicate operations distinguish validation before and after transformations. These are useful models for precise stage contracts, though its surface is not the same four-method API. [Type API](https://arktype.io/docs/type-api).

The runtime has a shared `BaseRoot` over `BaseNode`; its public `Type` is a TypeScript type-level instantiation associated with that runtime. ArkType therefore also centralizes common schema machinery, but is not simply a nominal `Type<I,O>` class hierarchy to translate directly into Dart. [Runtime root source](https://github.com/arktypeio/arktype/blob/main/ark/schema/roots/root.ts), [public Type source](https://github.com/arktypeio/arktype/blob/main/ark/type/type.ts).

ArkType's FAQ states that an async morph is not supported as an awaited validation stage, apart from representing a promise in the output. It is not the reference implementation for Acanthis's existing async refinements and four execution methods. [Async morph FAQ](https://arktype.io/docs/faq#is-there-a-way-to-create-an-async-morph).

### What to adopt

| Design question | Proposed Acanthis choice |
| --- | --- |
| Shared extensible base | Yes: real abstract `Schema<I,O>`, not mandatory subclassing of many small interfaces |
| Input/output tracking | Explicit, original input retained across pipelines and final output exact |
| Public validation input | `Object?`, with narrowing at the execution boundary |
| Four execution methods | Inherited behavior, separate sync/async and throwing/collecting kernels |
| Result model | Existing `AcanthisOutcome<O>` and native issues |
| Fluent operations | Shared generic composition plus concrete schema-specific fluent methods |
| Optional integrations | Adapters/extensions; not abstract exporter/mock obligations on every new schema |
| TypeScript machinery | Do not transplant conditional/mapped types, casts or type-level parsers as presumed Dart capabilities |

These choices are architectural conclusions for Acanthis, not claims that either reference library implements this exact Dart design.

## Define `I` before implementing the base

`I` is the schema's **declared input domain**, and `O` is its **successful parsed output**. It is not the same as the type of arbitrary data submitted for validation. It also does not enumerate the full set of accepted values: constraints, defaults, omission and coercion remain runtime semantics.

For example:

| Schema | Declared type | Notes |
| --- | --- | --- |
| Plain string | `Schema<String,String>` | Wrong raw types are still accepted by the method parameter and rejected diagnostically |
| String mapped to an integer | `Schema<String,int>` | Mapping callbacks receive validated string output from the input stage |
| Coercive integer | `Schema<Object?,int>` | Broad input honestly represents heterogeneous coercible raw types in Dart |
| Nullable string | `Schema<String?,String?>` | Nullability concerns values; object optionality still concerns presence |
| Object with heterogeneous fields | `Schema<Map<String,Object?>,Map<String,Object?>>` as a broad conceptual contract | Concrete legacy map signatures can retain `dynamic` at their heterogeneous boundary; no inferred arbitrary record is promised |

Defaults may admit null even when a nominal primitive input is nonnullable. Either widen the declared input for a defaulted wrapper or document a nominal input convention consistently; do not use `I` as a mathematically exact accepted-value set while allowing undocumented exceptions. Likewise, list input annotations describe element domains; raw collection runtime type must not reject valid JSON-like data solely because the submitted list was instantiated as `List<dynamic>`.

### Recommended four-method contract

```dart
abstract class Schema<I, O> {
  bool get isAsync;

  O parse(Object? input);
  Future<O> parseAsync(Object? input);

  AcanthisOutcome<O> tryParse(Object? input);
  Future<AcanthisOutcome<O>> tryParseAsync(Object? input);
}
```

This block describes the public contract; the methods should have shared concrete implementations in the actual base. A custom schema supplies typed definition/execution hooks or compiled executors, rather than four independently written public parsing algorithms.

**Why not `parse(I input)` and `tryParse(I input)`?** Directly typed callers could no longer submit an unrelated type to obtain validation diagnostics. After generic widening or dynamic invocation, Dart argument checks can throw before `tryParse` reaches its body. That changes the purpose of the nonthrowing validation boundary. A distinct typed-input convenience could be added later, but is not required to introduce `Schema<I,O>`.

`Object?` here does not erase the output, mapper or definition types. It represents untrusted input only. Keep validated values and callbacks typed as `I`, intermediate output, or `O` according to their stage.

## Responsibilities of the base

The base should own:

1. Common public execution methods and sync/async capability checks.
2. Consistent outcome/exception finishing using existing diagnostics.
3. Access to typed immutable common definition/configuration and lazy execution facilities.
4. Generic composition contracts that preserve original input and exact final output.

Concrete schemas provide primitive preparation, structural traversal or stage compilation. A shared compiler still owns ordered checks and transformations. An object plan owns specialized field traversal; live sessions own caches and revisions. The base does not become the home for exporter traversal, generation strategies or form-session state.

A suitable execution shape is four typed facilities:

```dart
typedef SyncParse<O> = O Function(Object? input);
typedef SyncCollect<O> = AcanthisOutcome<O> Function(Object? input);
typedef AsyncParse<O> = Future<O> Function(Object? input);
typedef AsyncCollect<O> = Future<AcanthisOutcome<O>> Function(Object? input);
```

These are signatures, not a requirement to allocate four closures and a plan object for every intermediate fluent definition. Derive/cache facilities lazily. Purely synchronous schemas can inherit async methods that call the corresponding sync kernel inside `Future.sync`; genuinely async schemas supply paired async kernels. Missing async capabilities must be rejected during setup/binding rather than silently defaulting to sync execution.

The compiler experiment used constructor-injected closures to demonstrate this structure. A production protected-hook design is also valid if it achieves the same ownership without duplicated public algorithms. The choice should follow construction/first-use/warmed measurements. `@nonVirtual` is an analyzer contract, not Dart's enforcement of final methods; legacy subclasses overriding public parsing must be considered during migration.

Keep throwing mode genuinely fail-fast where Acanthis promises that behavior. Do not implement every `parse` by calling `tryParse` and throwing afterwards. Do not force sync execution through futures. Shared semantics do not require a single physical executor.

## Fluent typing and composition

Conceptually, same-output refinement retains `Schema<I,O>`, a typed output mapping produces `Schema<I,N>`, and list/nullable wrappers derive both domains appropriately. Pipeline success should expose `N`, not `N?` merely to accommodate failure. Invalid output absence belongs in `AcanthisInvalid<N>.withoutValue`.

The existing mapper-based `.pipe(outputSchema, transform: ...)` syntax can retain its name and shape. Its transform remains `N Function(O)`; the input stage validates before the mapper runs, and the output stage validates its result. The original `I` flows through the returned schema. No speculative async mapper feature is needed.

Primitive-specific fluent methods must return the concrete schema family where applicable. A base return of `Schema<I,O>` loses `.min`/`.email` members just as the current raw/base returns lose information. Dart does not provide TypeScript's polymorphic `this` return behavior automatically; use covariant concrete returns and family-local copying. A generic identity helper should preserve the schema type itself when needed rather than returning an erased base.

### Dart variance: an important limit

Dart class type parameters are covariant; function parameters are contravariant. Consequently, `Schema<int,String>` can be widened to `Schema<num,String>`. A composition signature accepting `Schema<O,N>` cannot alone prove that the downstream implementation accepts every value of the upstream Dart type. [Dart variance glossary](https://dart.dev/resources/glossary#variance-and-variance-positions).

The compiler experiment confirmed this exact counterexample: a `num` producer and an `int`-only consumer compose under a naive generic signature, but `1.5` must be rejected at runtime. **Do not claim arbitrary schema-to-schema compatibility becomes fully compile-time-safe simply by adding `I`.** Reified generic types do not supply a general source-level `O extends NextInput` constraint that repairs covariance-based widening automatically.

Typed mapping callbacks do provide useful checks: the experiment rejects an `int Function(int)` callback where the input stage produces `String`, and rejects assigning a mapped `int` output to `String`. Preserve those guarantees. Continue validating every runtime stage and isolate heterogeneous schema binding behind checked boundaries.

If stronger schema-to-schema input assignability is a requirement, evaluate explicit typed function adapters or a checked binder in a separate compiler prototype. Do not solve it by unchecked casts or by advertising an unverified generic bound.

## Preserving `AcanthisType` compatibility

There are three distinct choices; do not accidentally conflate keeping fluent names with keeping generic declarations and subclass behavior:

| Choice | Benefit | Compatibility cost |
| --- | --- | --- |
| New canonical `Schema<I,O>` plus legacy `AcanthisType<O>` class/adapter | Preserves an actual old base for existing subclasses while new implementations track input/output | New schemas must remain accepted by old nominal signatures through an explicitly designed relationship/adapter; constructor and hook compatibility needs dedicated fixtures |
| Canonical base named `AcanthisType<I,O>` | Familiar name with full input/output information | Changing generic arity breaks every explicit `AcanthisType<O>` annotation and extension; requires a major migration |
| Output-only alias `typedef AcanthisType<O> = Schema<Object?,O>` | Short old annotations can accept new input-specific schemas through covariance | An alias is not automatic full compatibility with old constructors, static factories, hooks, runtime expectations or public-method overrides |

The experiment verified the basic alias assignment and extending a generic alias. It did **not** establish that replacing the real old class with that alias preserves the entire Acanthis API. An alias plus recreated base constructors/hooks is a plausible rewrite option, not a migration guarantee.

Recommendation: make `Schema<I,O>` the target validation contract, preserve the existing fluent factories and concrete classes, and decide the legacy name relationship with real consumer/compiler fixtures before publishing. If necessary, accept an explicitly documented major type-level change while retaining fluent syntax. Do not quietly claim both nominal subclass compatibility and a changed inheritance graph.

## Prototype evidence and acceptance gates

The [compiler experiment](evidence/schema-base-probe.md) ran on Dart 3.13.3 using existing archived outcomes/checks through a temporary package configuration. It established:

- Wrong raw type becomes a diagnostic through the inherited unknown-input boundary.
- Both async methods work on synchronous schemas; genuinely async collection awaits rejection.
- Synchronous parsing rejects an async schema before execution.
- An invalid input stage skips the next stage.
- Mapping retains an exact nonnullable `int` output and original `String` input annotation.
- Basic output-only alias assignment and subclassing compile.
- Incomplete async capability pairs reject at construction.
- Wrong mapper argument type and incompatible output assignment fail compilation.
- Naive schema-to-schema composition has the covariance limitation described above.

The prototype is not a new engine, a benchmark, or a proof of complete fluent compatibility. Before implementation acceptance, add frozen definition/copy tests, primitive-specific fluent type fixtures, lazy recursive async capability tests, operation ordering, absent-recovery composition, custom subclass hooks, and preserved specialization/input-sharing comparisons. Earlier performance data remains historical until the new base is implemented and measured.

## Updated recommendation

**Proceed with `Schema<I,O>` as the rewrite's extensible base design.** Use broad external parse inputs, exact successful outputs, existing outcomes, typed callbacks and definitions, and shared implementations of all four methods over distinct execution facilities. Preserve the working compiler and specialization algorithms. Keep optional capabilities out of the minimal base, and make Dart's composition limits and legacy compatibility decisions explicit.

This adopts the useful input/output and common-base ideas seen in Zod and ArkType without assuming their TypeScript inference or async behavior transfers unchanged to Dart.
