# Performance and testing plan

## Baseline established before implementation

Date: 2026-10-13. Package 2.1.0, Dart 3.13.3 stable, Windows x64, 12 logical processors. Reviewed source and lockfiles are pinned in [the fingerprint](evidence/source-fingerprint.md); the dirty checkout cannot be reconstructed from its base commit alone. Existing tests, source, and harnesses were unchanged.

| Check | Observed result | Qualification |
| --- | --- | --- |
| `dart analyze` | No issues; final retry exit 0 | Initial run reported no issues but exited 1 on sandbox telemetry modification; rerun outside the sandbox completed. Root analyzer excludes `benchmark/**`. |
| `dart run test --reporter expanded` | 583 tests passed, exit 0; approximately five seconds reported by test runner | Default differential seed 730201, 500 configured cases. Not a coverage percentage. |
| Seed 42, 2,000-case differential run | All five differential tests passed, exit 0 | Includes specialization-eligible randomized objects, composition and live comparisons. Initial additional run hit pub/telemetry restrictions; permitted retry completed. |
| `dart run tool/check_schema_registry_types.dart` | Three intended generic-bound compile failures verified; cross-module AOT example compiled and ran | Existing runner supplies exact package config and validates expected diagnostics. |
| Reduced review probes | Counterexamples and passing controls recorded | [Full source/output](evidence/runtime-probes.md); intentionally not added as production tests during analysis. |
| Extended lifecycle JIT and AOT | All 19 cases, five rounds, semantic preflight passed in both modes | Construction, fresh first validation, and warmed validation measured separately. |
| Error-contract JIT | Seven samples of 20,000 operations after 5,000 warmup calls | No new AOT run for this particular harness; historical AOT files remain historical. |
| Selected-rule/live JIT | Seven samples of 10,000 operations, 2,000 warmup calls; scheduling preflight passed | One field and one rule executed per settled edit out of 24 fields. |
| Independent JSON/OpenAPI export audit | Dart corpus tests passed (8 tests); Python validation unavailable | `tool/audit_schema_export.dart` exited 1 because `jsonschema` is not installed. No dependencies were added; independent validator parity is not claimed for this review. |
| Total allocations / individual-call tail latency | Not established | Existing allocation probe explicitly cannot infer total allocations from VM heap censuses. Timing harness measures batch averages, not p95/p99 calls. |

The analyzer and full suite ran before review scratch compiler files were created. Scratch Dart sources were removed after their examples/output were embedded in Markdown. Future implementation must rerun relevant analysis/tests against actual changes; these results describe the reviewed baseline.

## Fresh timing observations

All times below are median microseconds per operation. Fresh first validation excludes constructing 128 fresh schemas; process-first single observations remain separate in raw evidence. Build timings include the existing harness overhead, not an empty-loop subtraction.

| Workload | JIT build µs | JIT fresh first µs | JIT warm µs | AOT warm µs |
| --- | ---: | ---: | ---: | ---: |
| object.specialized.valid | 1.256 | 5.652 | 0.281 | 0.326 |
| invalid90.nested | 1.754 | 4.749 | 1.216 | 1.356 |
| invalid90.issues.json | 1.633 | 12.305 | 4.723 | 5.925 |
| issues1000.repeated | 0.713 | 476.219 | 478.495 | 734.827 |
| union128.invalid | 16.531 | 84.885 | 77.807 | 81.185 |
| union128.last | 18.317 | 67.034 | 65.651 | 58.919 |
| transformed100.output | 1.229 | 12.289 | 9.490 | 10.509 |
| live50.independent | 150.431 | 51.298 | 77.748 | 81.646 |
| live50.full | 38.832 | 35.366 | 23.346 | 31.476 |
| async8.completed | 2.064 | 6.171 | 6.223 | 5.580 |

All raw JIT/AOT lifecycle samples, ranges, controls, and runtime metadata are retained in [benchmark samples](evidence/benchmark-samples.md). The lifecycle harness uses randomized case order (seed 42), warmup per case, five 100 ms rounds, and an escaping result sink. Timing processes ran sequentially without concurrent test/build processes; this remained an interactive desktop session with uncontrolled background activity. A CIM CPU-model query was unavailable, and power policy was not verified. These are provisional local observations, not a controlled checkout-to-checkout comparison.

The fresh error-contract JIT run measured collection at 0.787 µs/op, fallback JSON at 3.274, English JSON at 3.804, Italian JSON at 3.471, transport at 3.124, fallback fail-fast validation at 7.152, and Italian fail-fast validation at 7.169. The initial collection samples show substantial warmup/run variation; retain them rather than selecting only favorable samples.

The 24-field selected-rule JIT run measured construction 17.396 µs/op, sync full 17.317, sync live edit/delta 24.505, async full 40.728, and async live edit/delta 32.603. The live preflight executed one field and one rule. Reduced execution count is established; faster synchronous end-to-end editing is not. Live/full operations have different snapshot/delta costs.

Historical September/October timings in `benchmark/baselines`, `benchmark/rules-live`, and `benchmark/error-contract` remain useful workload references. They are **not** a controlled before/after experiment against this dirty checkout; do not label their differences regressions caused by this proposed architecture.

## Existing coverage and what it proves

| Area | Existing evidence | Important remaining gap |
| --- | --- | --- |
| Primitive predicates/coercion | `test/types/string_test.dart`, `number_test.dart`, `boolean_test.dart`, `date_test.dart`; parameter/code inventory tests | Some tests assert validity/value only. Literal rejecting refinements and genuine async template throwing matching are absent. |
| Composition/pipelines | `pipe_test.dart`, `composition_regression_test.dart`, `regressions_test.dart`, class builder tests | Pipeline output operations are not exercised; literal test uses an accepting refinement. |
| Presence/defaults | `presence_contract_test.dart`, `presence_matrix_test.dart`, 504-observation fixture, `nullable_test.dart` | Definition alias mutation and nullable default ownership/copy matrix need dedicated tests. Snapshot changes alone must not bless new semantics. |
| Diagnostics/results | `results_test.dart`, `structured_issues_test.dart`, issue compatibility/structural/error-contract/code inventory tests | Nested invalid no-recovery outcomes are not closed under all composites; callback TypeError handling differs. |
| Optimization semantics | `object_specialization_test.dart`, `input_reuse_test.dart`, `diagnostic_reuse_test.dart`, `performance_semantics_test.dart`, differential suite | Exact accepted-type tests are strong; add mixed typed-output incompatibility and newly introduced schema wrappers to fallback corpus. |
| Rules/dependencies | `selected_field_rules_test.dart`, `collection_policy_test.dart`, map tests | Rule-enabled throwing execution must stop later callbacks; behavior of own operations after child errors needs an explicit matrix. |
| Live sessions | `live_test.dart`, `live_editing_test.dart`, `live_dependency_test.dart`, `async_live_test.dart` | Existing 200-revision nested sequence, stale/debounce/cancellation/context tests are valuable. Add absent recovery, definition mutation, and repeated opaque callbacks to parity tests. |
| Export | `schema_export_contract_test.dart`, `schema_export_audit_test.dart`, OpenAPI tests | Custom schema subclass trust boundary; independent Python validation unavailable on this run. Legacy exactness is intentionally not promised. |
| Mocks | `mock_test.dart`, `seeded_mock_test.dart` | Selected rules bypass opaque rejection; legacy anchored-pattern generation can be unbounded. |
| Registry typing | Registry tests plus negative fixtures and AOT example | Add positive/negative output inference fixtures outside the registry scenario. |

No need to discard these tests or rebuild the suite. Extend the cross-product where existing tests compare a synchronous schema through async APIs: force at least one real async operation to reach the separate executor.

## Additional tests required before each fix

1. **Literal/template execution:** all four parse methods plus validate/validateAsync; correct and incorrect shape, wrong raw type, rejecting own checks, shape-changing transform ordering, actual async checks, nested map/list/tuple/nullable/union placement. Assert callback counts and exact first issue, not merely an exception.
2. **No-value recovery:** top-level and nested `InstanceType` and typed union failures, with and without defaults; every composite and live full/incremental execution. All-policy continues independent siblings; first-policy stops as specified. Invalid parent has no certified output; access to absent recovery is never incidental inside validation.
3. **Immutable definitions:** mutate original field maps, tuple element lists, enum lists, optional sets, metadata lists/maps after construction and after first parse; inspect parse/export/async eligibility together. Do not change output identity guarantees.
4. **Copy matrix:** each derivation method preserves metadata/key, async state, defaults and explicit-null default presence, coercion, object rules/policies/optionality, tuple variadic state, and instance references. Compare builder-built schemas before/after builder mutation.
5. **Operation ordering and exceptions:** checks before/after transforms, failed transform, validation error versus callback TypeError/FormatException/StateError, repeated codes, default recovery, custom causes, and local field-first stopping with sibling issues. Test unsupported operation setup explicitly.
6. **Pipeline contracts:** mapper exactly once; mapper skipped on input/default branches; output validators and output operations; async input/output/both; metadata and copies; failed mappings; legacy nullable versus proposed exact outputs; structured unsupported exports/mocks.
7. **Deep paths/unions:** escaped names, empty/dotted/numeric-string keys, list indices, root issues, depth 32 and beyond, 16/128 branches, guard failures, branch order, duplicates, parent own checks with same-named child, legacy map projections versus native merges.
8. **Presence/coercion:** required/optional/nullable/defaulted/PATCH cross-product; invalid defaults remain invalid; null versus absent; int/double/num/string/bool/date coercion and nonfinite numeric input; transforms run once.
9. **Lazy/recursive schemas:** operations attached to lazy wrappers; hidden async descendants; direct/mutual recursion; stable identity and rebuild limits; resolution errors and unsupported standalone calls. Keep runtime recursion policy distinct from exporter expansion policy.
10. **Object dependencies/rules:** raw-input legacy reads versus parsed selected inputs; missing/null/default prerequisites; top-level and nested destinations; rule errors do not gate unrelated rules under all; throwing modes stop at first failure; unknown-key ordering and object own-operation policy are explicit.
11. **Custom schema/operation integration:** custom coercion and parsing hooks remain invoked; specialization never bypasses subclasses; audited exporter rejects opaque subclasses; seeded generator rejects rules without executing callbacks.
12. **Compile-time API:** use the fixtures described in [type analysis](type-safety-analysis.md), checking intended diagnostics and successful counterpart examples. Dart `runtimeType` tests cannot replace compiler fixtures.

Keep accepted behavioral corrections separate from pure refactor fixtures. For snapshot changes, record the old/new semantic difference and reduced regression; do not update the presence fixture wholesale to make a refactor pass.

## Measurement plan for implementation

| Workload group | Inputs/rules and lifecycle | Metrics |
| --- | --- | --- |
| Primitive and construction | Empty/one/many checks; numeric chains, nullable wrappers, fluent construction; same values and rules | Build time, first validation, warmed ns/op and throughput; allocations if calibrated |
| Objects | 2/24/50/200 fields; flat/nested; eligible specialization versus forced ordinary path; unknown keys/defaults/typed passthrough | Success/failure timings separately, output identity, copies, issue count and allocations |
| Collections/diagnostics | 100/1,000 elements; valid, 50% invalid, 90% invalid; 300/3,000 duplicate issues; deep branches | Collection-only and formatting-only costs, bytes/objects per call if available, latency distribution |
| Pipelines | 1/3/8 stages, defaults, failed input/map/output, DTO mapping, sync and real async validation | Mapper calls, stage timing, cold construction and warmed cost |
| Unions/recursion | First/last/no match, 16/128 alternatives, guarded/plain; bounded tree shapes | Branch execution counts, error volume, stack behavior, throughput |
| Async | Eight sequential completed/microtask/event callbacks plus callback-only controls | Scheduling overhead and per-call latency; no network mixed into core comparisons |
| Live | Cheap and deliberately CPU-expensive fields, 24/50/200 fields, nested edits, context/rule changes | Full vs live with equivalent presentation work where possible; executed fields/rules, snapshot/delta costs, stale work |
| Integrations | Audited export input/output recursion, generation supported/unsupported subsets | Setup latency, bounded work, independent semantic verification, no validation hot-path tax |

Run the same source payloads, validation rules, collection policy, output/diagnostic production, and input ownership behavior on both sides of a refactor comparison. A fail-fast parser cannot be ranked against a collecting parser as equivalent work. Keep schema construction outside warmed timings. Record source hashes, SDK/build mode, lockfiles, CPU, power plan, and machine activity. JIT and AOT need separate baselines; keep timing workers sequential on an idle host.

Use at least three independent process runs, each with raw samples and randomized case order; report median and variability before attributing a change. As a proposed investigation trigger, repeatable degradation exceeding 5% in a relevant warmed workload or 10% in construction merits investigation, not automatic machine-independent failure. A correctness fix may have an explicit justified cost; extraction-only changes should not accept unexplained regression. Do not assert improvement from differences within run variation.

For p50/p95/p99 latency, instrument individual calls with timer-overhead calibration and a sufficient sample count; batch means cannot supply those percentiles. Include worst-case issue volume and recursive depth. Instrumentation changes should be isolated from throughput runs.

For allocations, calibrate a profiler against known object counts/bytes in runs both with and without GC. Existing VM heap census deltas can lose reclaimed objects and are **not allocation totals**. Product AOT may expose no service counters. Report unavailable separately for each mode; never substitute RSS, JIT counts, or timing. A full allocation baseline remains an open measurement task, not evidence that a proposed abstraction is free.

## Reproduction and gates

From the package root, use existing commands:

```powershell
dart analyze
dart run test --reporter expanded
dart run tool/check_schema_registry_types.dart
$env:DIFFERENTIAL_SEED='42'
$env:DIFFERENTIAL_CASES='2000'
dart run test test/differential_test.dart --reporter expanded
```

The exact timing commands and preserved raw output are in [evidence](evidence/README.md). Independently verify export using `dart run tool/audit_schema_export.dart` in an environment with the pinned optional Python validators from `tool/schema-export-requirements.txt`; this review did not install them. Analyze changed benchmarks explicitly because root analysis excludes them.

Every implementation phase must pass relevant semantic tests plus the full suite before performance comparisons are accepted. Plan/compiler changes additionally require differential output/issue/sharing parity and JIT/AOT timing. Compilation/example and documentation checks apply to changed API examples. No extra dependency or generated executor is justified until a measured, attributable need appears.

