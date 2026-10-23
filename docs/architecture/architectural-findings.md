# Architectural findings

Source locations refer to the reviewed working tree. See [runtime probes](evidence/runtime-probes.md) for the executable counterexamples, [type analysis](type-safety-analysis.md) for compiler evidence, and [the roadmap](migration-roadmap.md) for sequencing. Priority follows the requested rubric, not implementation effort.

| ID | Priority | Classification | Finding |
| --- | --- | --- | --- |
| F01 | P0 | Confirmed defect | Literal throwing execution skips attached synchronous operations |
| F02 | P0 | Confirmed defect | Genuinely async template throwing execution skips template matching |
| F03 | P0 | Confirmed defect | Lazy wrappers ignore attached operations and can hide async validation |
| F04 | P0 | Confirmed defect | Failure without typed recovery is not closed under composition |
| F05 | P0 | Confirmed unsafe contract | Typed object schema can report success with incompatible field output |
| F06 | P0 | Confirmed contract blocker | Pipeline exposes unimplemented fluent/export operations |
| F07 | P1 | Confirmed defect | Mutable schema inputs disagree with cached definitions |
| F08 | P1 | Confirmed defect | Fluent copies drop tuple, instance, and metadata configuration |
| F09 | P1 | Confirmed defect | Collecting paths misclassify callback `TypeError` as invalid input |
| F10 | P1 | Confirmed behavior gap and architectural risk | Object executors duplicate semantics; rule-enabled throwing path collects first |
| F11 | P1 | Confirmed defect and architectural risk | Mocking is coupled to recovery; bounded generator misses selected rules |
| F12 | P1 | Confirmed defect | Audited exporter trusts custom subclasses as built-ins |
| F13 | P1 | Confirmed API limitation | Output inference is widened unnecessarily by numeric fluent methods and pipelines |
| F14 | P1 | Architectural risk | Operation recognition and base/integration dependencies constrain extension |
| F15 | P2 | Architectural risk / optional enhancement | Metadata and legacy recursive export retain global state |

## F01 — Literal refinements are skipped by `parse`

**Evidence:** [`literal.dart`](../../lib/src/types/literal.dart):27–38 returns after equality and never runs `super.parseInternal`. `tryParseInternal` at 41 does run the base operations; genuinely async throwing execution at 59 also runs operations. `literal('a').refine(onCheck: (_) => false, ...).parse('a')` returns `'a'`, while `tryParse('a').isValid` is false. The existing composition regression uses a refinement that succeeds, so it cannot detect this omission. Wrong-type literal input also uses `coerceInput` directly, bypassing the base throwing input normalization.

**Consequence:** a public validation method can accept input rejected by another method on the same schema. The same omission reaches nested literal fields via `parseInternal`.

**Recommendation:** establish literal equality before user operations, then run the typed ordered executor exactly once in every mode. Characterize current transform/equality ordering first: collecting code currently runs operations before equality, so adding one super-call alone does not establish equivalence. Wrong input becomes a diagnostic only at the input conversion boundary. No new engine is necessary. Test rejecting checks, changing transforms, async checks, nesting, and callback counts. Preserve literal identity/equality rather than assuming JSON structural equality.

## F02 — Async template `parseAsync` does not match the template

**Evidence:** [`template.dart`](../../lib/src/types/template.dart):172 implements sync matching; 206 implements async collecting matching; there is no async throwing override. Base `types.dart:440` directly coerces and executes operations for an async schema, bypassing `parseInternal`. `template(['a']).refineAsync(onCheck: (_) async => true, ...).parseAsync('b')` returns `'b'`; `tryParseAsync('b')` rejects it.

**Recommendation:** share a template matching/precondition helper across throwing/collecting sync/async entry points. Keep regex construction lazy. Also explicitly retain/document template **pattern** semantics: placeholder schemas are converted to best-effort exported patterns (`template.dart:103–166`), not parsed as captured substrings. Segment refinements, length restrictions, or async callbacks do not thereby become enforced template checks. Supporting general captured-segment validation is a separate feature, not part of this refactor. Test rejecting literal templates in genuinely async mode and transformation ordering.

## F03 — Lazy operations can be ignored, including async restrictions

**Evidence:** [`map.dart`](../../lib/src/types/map.dart):1845–1971. `LazyEntry.withCheck/withTransformation/withAsyncCheck` store operations, but `call(parent)` returns only the resolved schema. Object sync traversal resolves `call(this)` and executes that schema; lazy public methods likewise delegate directly. The probe attaches a rejecting refinement to a lazy string field: object collection reports success and invokes it zero times. A lazy callback returning a schema with a rejecting async refinement leaves the parent `isAsync == false`; sync collection accepts it without executing the async check. `nullable`, `meta`, `withDefault`, and `mock` throw `UnimplementedError`; standalone parse force-unwraps an absent parent. Direct lazy list parsing assumes `List<Map<String,dynamic>>` regardless of generic output.

**Recommendation:** make parent binding an explicit internal step that preserves wrapper operations and establishes async eligibility. Resolve/cache once per owning definition where safe, with a recursion construction guard; do not repeatedly execute callbacks merely to ask for `isAsync`. For recursive async propagation, compute capabilities over a bound graph with cycle detection, or initially require an explicit async declaration and reject inconsistent resolutions before executing sync validation. Do not infer that a false flag proves a deferred callback synchronous. Keep legacy direct-object-field lazy API as a compatibility adapter. General standalone lazy schemas can wait for a distinct use case. Test lazy checks/transforms once, async descendants, mutually recursive definitions, parent errors, and stable export identities.

## F04 — Composition assumes every invalid outcome has `.value`

**Evidence:** [`results.dart`](../../lib/src/results.dart):368–383 supports `withoutValue`; [`instance.dart`](../../lib/src/types/instance.dart):70–95 uses it for a wrong input type. But async list collection (`list.dart:207–213`), tuple collection (`tuple.dart:100–106`, 179–185), nullable async collection (`nullable.dart:111–120`), and map evaluators (`map.dart:390`, 486, 1168) access child `.value` before checking recoverability. Union internal collection (`union.dart:120–125`) does the same. Sync instance composition can instead enter the inherited internal recovery hook, which calls unimplemented `mock`.

**Reproduced:** nested typed union wrong input throws `StateError`; async list of instance schemas wrong input throws `StateError`; sync list of instance schemas wrong input throws `UnimplementedError`. The existing instance tests cover top-level invalid instances/unions and successful nesting, not these invalid nesting cases.

**Recommendation:** outcome-aware internal composition. Merge diagnostics even when there is no output; propagate `AcanthisInvalid<Parent>.withoutValue` when a complete typed parent recovery cannot be assembled. Continue collecting independent children under `all`; never evaluate a mapper against absent recovery. Retain existing typed recovery where available. Do not manufacture `T` using mocks or unchecked null casts. Legacy `tryParseInternal -> O` cannot represent no-output failure; retain it for old subclasses behind a narrow adapter while built-ins migrate. This is the first architectural prerequisite for making successful pipeline output non-nullable.

## F05 — Typed map output can defer a cast failure until after success

**Evidence:** `AcanthisMap<V>` accepts raw `AcanthisType` fields (`map.dart:24`, 192) unrelated to `V`. The pure path returns lazy cast views (`map.dart:789`, 954). The reviewed code permits `AcanthisMap<int>({'a': string()})`: `tryParse({'a':'ok'}).isValid` is true, but reading `result.value['a']` throws a type error.

**Consequence:** Dart still protects the read at runtime; the defect is that successful schema validation has not established the promised `Map<String,int>` output contract. Input/output generics alone would not repair this raw field binding.

**Recommendation:** validate schema-output compatibility at construction for homogeneous typed maps, and check typed passthrough values at the runtime boundary. A constructor accepting `Map<String,AcanthisType<V>>` is the strongest static form; an initial runtime setup error can preserve source compatibility. Keep `object` heterogeneous (`dynamic`) and do not pretend Dart can infer a record from arbitrary map keys. If a type-compatible custom schema violates its own output contract, treat that as a programming failure rather than silently coercing it. Gate fixes against lazy-view and identity expectations in existing typed-map tests.

## F06 — Pipeline is an incomplete public schema subtype

**Evidence:** [`types.dart`](../../lib/src/types/types.dart):727–909. Six implementations throw `UnimplementedError`: metadata, two legacy exporters, async checks, sync checks, and transformations. `refine`, `refineAsync`, and `transform` inherit calls into those methods. A plain pipeline refinement fails during schema construction. `ClassSchemaBuilder.build` produces this same type. Pipeline `mock` transforms an input mock without checking the output schema. Mapper exceptions are normalized broadly, unlike same-type transformations.

**Recommendation:** complete the existing legacy pipeline contract before adding abstractions: copied output operations, metadata, defaults, async flag propagation, deterministic stage ordering, and structured unsupported-export/mock failures. A pipeline cannot generally export an exact input/output contract for an arbitrary mapper; it must report that limitation, not invent a schema. For legacy best-effort export, use a documented output projection only if chosen explicitly; otherwise use a named capability exception. Keep pipeline defaults output-typed. Fixing successful output nullability is an independently versioned change (F13).

## F07 — Definition immutability is partial

**Evidence:** object constructors retain caller maps (`map.dart:193`, 229) but eagerly snapshot keys/types (`564–575`). Modifying the original map after construction changes `.fields` and exports but not the compiled traversal. The probe adds required field `b`; `.fields` lists `a,b`, while parsing just `a` succeeds. Tuple constructors retain and expose `elements` (`tuple.dart:12–33`); caller mutation changes validation and can leave `isAsync` stale. Enumeration checks retain lists/iterables (`validators/number.dart:263`, `validators/string.dart:491`, `538`; list membership checks similarly). Metadata retains examples and property maps. Base operation lists, template parts, rules, issue data, and registry binding snapshots already freeze their containers.

**Recommendation:** snapshot definition containers at schema/check construction and expose unmodifiable views. Shallow freezing is sufficient for schema references and scalar constraints; it cannot freeze callback closures, domain object literals, or arbitrary user defaults. Explicitly document default/output ownership; do not deep-copy validated input, which would break intentional identity reuse. Benchmark construction separately: copying fields and constraints costs O(n) time/memory but removes cache invalidation ambiguity.

## F08 — Manual copy constructors lose configuration

**Evidence and reproduced examples:**

* Tuple `.variadic().refine(...)` becomes nonvariadic because copy methods call the public nonvariadic constructor (`tuple.dart:200–244`, 277–295). The two-element probe changes from valid to invalid.
* `InstanceType.withRefs(...).field(...).refineWithRefs(...)` loses references: `field` and other copies omit `refs` (`instance.dart:125–173`, 187–204, 261–270). Custom checks catch the missing-reference error and return failure, hiding the setup problem.
* Object `optionals` omits `metadataEntry` (`map.dart:715–729`); union `withCheck`, `withAsyncCheck`, and `withTransformation` omit it (`union.dart:248–282`). Schema key can survive while outcome/export metadata disappears. Reproduce with `.meta(...).optionals(...)` and `.meta(...).refine(...)` in phase 0.

**Recommendation:** family-local copy helpers with unchanged-by-default settings; do not introduce a global untyped configuration bag. Exhaustively test derivation preserves unrelated settings. Builders remain mutable setup tools but built results snapshot their configuration. Copy helpers should not re-register metadata or execute callbacks.

## F09 — Callback exception boundaries differ

**Evidence:** throwing base coercion catches `TypeError` only around input conversion (`types.dart:338–348`). Collecting base catches it around coercion **and the entire compiled operation chain** (`392–415`); async collection similarly wraps the entire loop (`507–594`). A deliberately failing callback cast propagates from `parse`, but `tryParse` returns `type: Invalid type: String, expected String`. Tuple throwing execution additionally catches child `TypeError` broadly (`tuple.dart:62–70`, 138–146).

**Recommendation:** narrow normalization to input conversion. Preserve documented custom refinement exception-to-false behavior in `CustomCheck/CustomCauseCheck/CustomAsyncCheck`; selected-rule exceptions already propagate intentionally. Decide pipeline mapper exception policy explicitly, preserving its established transform diagnostic for ordinary mapper failures; do not reinterpret arbitrary programming errors as input type errors. Add failure-type and call-count tests for every executor and composite. This correction can expose previously swallowed application bugs and needs release notes.

## F10 — Object semantics have multiple owners

**Evidence:** `map.dart` repeats traversal, presence, passthrough, dependency, operation, and async logic across methods at 355, 450, 733, 888, 1032, and 1132. Legacy dependencies are implemented in two helpers and repeated in async methods. Rule-enabled `parseInternal` calls `tryParse`, then throws its first issue (`733–734`); async throwing does the same (`1032–1033`). The probe shows a later field callback runs despite a first-field failure. Rule evaluators skip own object operations after child errors, while legacy traversal can still execute own operations under collect-all; this needs characterization before choosing semantics.

**Recommendation:** share field-presence decisions, rule eligibility, dependency reading, typed assembly, and outcome finishing; retain separate optimized throwing, collecting, and async loops. Provide a real fail-fast rule path in throwing execution. Specify ordering as children, selected rules, legacy dependencies, own operations; preserve current raw-vs-parsed dependency distinction. Resolve own-operation-on-invalid-children behavior explicitly with tests; do not change it incidentally while moving files. `objectPolicy:first` must not be assumed to prevent every extra issue because unknown-key scanning currently collects all extras before traversal.

## F11 — Recovery and generation have incompatible obligations

**Evidence:** base `valueOnFailure` calls `mock(0)` (`types.dart:316–323`); `InstanceType` and templates explicitly do not implement legacy mocks. Legacy string regex generation has an unbounded loop (`string.dart:685–691`): for an anchored one-character pattern and its default ten-character target, appending more generated characters cannot succeed. This nontermination follows from source; the review did not run an unbounded mock. `mockSeeded` is already bounded, but `_Generator.check` rejects map legacy dependencies, not `schema.rules` (`seeded_mock.dart:150–160`). The selected-rule probe runs an opaque callback twice despite the adapter's documented rejection policy.

**Recommendation:** remove generation from internal failure recovery (F04), reject opaque selected rules before seeded generation, and bound remaining legacy generation loops. Keep generator failure distinct from validation failure using `AcanthisMockException`. Independent strategies/capabilities can be introduced later without entering validation's hot path. Do not claim arbitrary satisfiable schemas can be mocked.

## F12 — Audited export recognizes a subclass by its base type

**Evidence:** [`schema_export.dart`](../../lib/src/schema_export.dart):199 onward uses `is AcanthisString`, `is AcanthisMap`, etc. to assert runtime-equivalent contracts. A custom string subclass overriding parsing to accept `42` exports `{'type':'string'}` without rejection; see the probe. Exact-type exclusions already protect object/list fast paths and seeded mocking, but not audited export. Current export audit rejects checks impersonating built-ins by name, not schema subclasses overriding semantics. Constraint class patterns in `_constraints` also match subclasses: a custom subclass overriding a recognized predicate is another source-backed trust-boundary risk that needs its own regression.

**Recommendation:** recognize audited exact built-in implementations or explicit trusted export capabilities. Require a custom adapter for opaque subclasses rather than infer semantics from inheritance. This is a stricter rejection of previously accepted, potentially incorrect exports, so document it as a correctness change. Independently validate custom adapter input/output fixtures before declaring them audited. The existing per-call recursive exporter should be retained.

## F13 — Static output precision is lost

**Evidence:** raw numeric return declarations (`number.dart:163–220`) widen static outputs to `num` even though instances remain `AcanthisNumeric<int>`. The compiler rejects `int x = integer().positive().parse(1)` as a `num` assignment. Pipelines return `T?` (`types.dart:727`); the compiler rejects assigning a string-to-int pipeline parse to `int`. Several `withDefault/meta/refine` return base types, also losing schema-specific fluent members. Raw tuple/union element APIs cannot express heterogeneous positional or union types statically.

**Recommendation:** preserve `AcanthisNumeric<T>` return types where semantics do not change output type; prioritize a complete output-typed pipeline contract before a major nullable-type correction. Improve covariant concrete returns family by family. Do not add `Schema<I,O>` across the package to address defects caused by raw returns. [Type analysis](type-safety-analysis.md) compares alternatives and compiler constraints.

## F14 — Extension and dependency boundaries need definition

**Evidence:** base compilers and async switches silently default for unknown operation subclasses (`types.dart:191`, 284, 488, 555 vicinity). `AcanthisOperation.call` returns `dynamic`; useful built-in subtypes narrow it, but an arbitrary operation is not guaranteed to execute. Base `types.dart` imports the public barrel, which re-exports concrete schemas and integrations; multiple types, live, rules, exporters, and mocks also import it. Static factories and concrete inheritance create a real base/concrete dependency cycle; replacing barrel imports alone cannot eliminate it. Results/sink/i18n likewise import each other.

**Recommendation:** document supported operation kinds now and reject unsupported ones at schema setup; retain external check extension via `AcanthisCheck`/async checks. Verify constructor `isAsync` consistency with supplied operations as well: public constructors accept an operation list and an independent false-default flag, so merely checking that flag is not a proof that synchronous compilation contains no async check. Split optional integration dependencies from execution; address library import cycles with explicit Dart library boundaries, as proposed in [the architecture](proposed-architecture.md). An exhaustive sealed operation hierarchy would block external subclasses and is not a compatible first step. No new registry/visitor is required for every validator.

## F15 — Legacy state can escape schema ownership

**Evidence:** singleton `MetadataRegistry` has cast-based lookup, insertion overwrite, and no lifecycle ownership (`metadata_registry.dart:1–29`). `InstanceType.meta` uses a type-derived key (`instance.dart:188–204`). Legacy lazy export marks singleton state and removes it outside `try/finally` (`map.dart:1633–1647`, 1719–1733; `lazy_object_mapper.dart`); an exception can leave marks. The audited exporter already uses per-call identity maps with cleanup in `finally` (`schema_export.dart:165–196`), and schema registration already uses owned snapshots.

**Recommendation:** use schema-local metadata as canonical and make global registration a compatibility service; migrate legacy recursion bookkeeping to a per-call context when those exporters are touched. Alternatives include leaving best-effort exporters frozen and documenting their limitations. These changes improve isolation but have lower priority than skipped validation. Do not replace the already owned schema registry with another global catalog.

## Assumptions rejected by this review

* Native outcomes, diagnostic paths, branch errors, localization, collection policies, conservative incremental dependencies, and immutable registry bindings already exist.
* Internal merging through `.errors` is not automatically lossy: native `IssueSink` recognizes native sinks. Public map materialization remains lossy by design.
* Ordinary schemas already delegate async APIs to sync; async equivalence must exercise an actual async operation.
* Defaults do not turn supplied invalid data into successful validation. Their failure recovery values are intentionally separate from validity.
* Existing specialization excludes custom subclasses and has differential tests. A generic executor is not automatically preferable.
* Existing audited export deliberately rejects unsupported semantics rather than promising complete export. Legacy best-effort exporter inaccuracies are not defects in the audited contract unless they cross its trust boundary (F12).
