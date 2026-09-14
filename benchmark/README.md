# Correctness and performance work

Run from `benchmark/` unless a command says otherwise. The original
`library_comparison.dart jit|aot|verify` comparison of Acanthis, Luthor and Vine
is preserved. `--extended` adds Acanthis lifecycle workloads; it does not rank
libraries with different collection or transformation semantics. In particular,
Vine 1.8.0 retains failure diagnostics, so its invalid-input verification remains
a separate process. Do not label rebuilding a Vine validator as warmed validation.

## Reproduce the baseline

```powershell
dart run bin/library_comparison.dart verify
dart run bin/library_comparison.dart --extended jit
dart compile exe bin/library_comparison.dart -o .dart_tool/library_comparison.exe
.\.dart_tool\library_comparison.exe --extended aot
dart run bin/library_comparison.dart --allocations jit --profile
dart run bin/library_comparison.dart --allocations aot
```

Archive the JSON and compact CPU summaries with `python report_baseline.py baselines/YYYY-MM-DD` (Python standard library only). This also fingerprints the measured sources; run it before editing those sources.

For a verified run, supply an evidence JSON as the second argument. Its
`environment` and `correctness` strings should describe the actual machine
conditions and checked command logs; the report no longer assumes a test count
or power plan from an earlier run. Regenerate all four input JSON files and CPU
profiles for a fresh baseline; do not combine stale measurements with new hashes.
The 2026-09-12 archive contains `evidence.json` and command logs. The presence
audit is reproduced with `dart run test test/presence_matrix_test.dart` from the
root; regenerate its snapshot only after reviewing intentional behavior changes.

`--quick` is a smoke run (3 rounds, 25 ms), not the recorded baseline. Normal
runs use 5 rounds of 100 ms, a warmup per case, seeded randomized case order,
and 128 fresh schemas per first-validation sample. Run timing processes
sequentially on an idle machine. Record the SDK, hardware, power settings,
dependency lockfile and source revision/dirty changes when comparing runs.
The JSON records raw samples and ranges; do not treat a single median as a
statistical significance test or compare different machines as a regression.

Workloads cover 90% invalid nested inputs, JSON issue presentation, 300/3000
duplicate issues, 16/128-branch unions (no match and last match), 100 transformed
elements with stripping, 50-field live updates and full validation, and eight
sequential callbacks using completed futures, microtasks, or zero-delay events.
Callback-only controls isolate scheduling overhead without network latency.
Live workloads alternate values across field cycles so warmed updates still
change diagnostics. The full-validation comparator does not compute a delta;
the live comparator does, and setup includes its initial validation.

## What is measured

- **Construction:** factory execution only; cached payloads remain outside the clock.
- **First validation:** prebuilt fresh schema instances, validated once each in
  an already running VM. This captures lazy schema compilation but is not fresh
  process startup. Separate single first-observation timings are recorded before
  preflight; earlier cases may already have warmed shared library code.
- **Warmed validation:** a cached schema/session with an escaping result sink.
  Loop and async callback controls report harness/scheduling costs; synchronous
  batches also have one async harness boundary per ten calls.
- **Allocation probe:** a separate worker and external VM-service client inspect
  construction, fresh first validation (construction excluded), and warmed
  validation. Total allocation is explicitly unavailable on the measured SDK.
  Heap snapshots are reported separately, without per-operation estimates.

Despite their names, the measured SDK's `ClassHeapStats.accumulatedSize` and
`instancesAccumulated` are populated from the same heap census as the current
values: see the [VM implementation](https://raw.githubusercontent.com/dart-lang/sdk/main/runtime/vm/class_table.cc).
Subtracting snapshots loses objects reclaimed by intervening GC and is not a
measurement of total allocation. The probe reports raw heap bytes/object counts
before a batch (after GC) and after it (without forced GC), including worker RPC
overhead. Its own HTTP/JSON allocations live in a different process. First-use
probes use 128 instances; other batches use 1000 calls. CPU samples are collected separately
and written under `.dart_tool/continuous_profile_*.json`.

The distributed product AOT runtime may expose no VM-service isolate or counters.
The client probes the compiled executable and writes an explicit `unavailable`
result in that case. It never substitutes RSS or JIT allocations for AOT values.
To probe a non-product runtime built for the same SDK (this does not make heap
census counters into allocation totals):

```powershell
dart compile aot-snapshot bin/library_comparison.dart -o .dart_tool/library_comparison.aot
dart run bin/library_comparison.dart --allocations aot --aot-runtime=C:/path/to/non-product/dartaotruntime.exe
```

A complete allocation baseline remains pending an independently verified
allocation profiler for both runtimes. Calibrate it with known allocations,
including batches that trigger GC, before accepting bytes per operation.

## Correctness gate before any optimization

From the repository root:

```powershell
dart analyze --fatal-infos
dart run test
$env:DIFFERENTIAL_SEED='42'
$env:DIFFERENTIAL_CASES='2000'
dart run test test/differential_test.dart
```

The ordinary path is forced with primitive subclasses. A separate corpus uses
specialization-eligible nested objects without optional fields, operations or
lists that would disable specialization. The composition corpus covers missing
keys, nulls, escaped/numeric keys, defaults, transforms, lists and async equivalents.
Failures print seed, trial and payload. Tests compare acceptance, all returned
values (including recovery), ordered diagnostics, unchanged inputs and recursive
container sharing. Live sequences compare current issues, deltas and validated
outputs against full validation, including cross-field rules.

An optimization must pass this gate with the same collection policy and corpus
before timing comparisons count. Do not accept an optimization that merely
skips diagnostics, copies/reuses different containers, changes recovery values,
or moves setup into another measurement. Add reduced regressions for discovered
counterexamples. Existing CI runs the tests automatically; timings are evidence,
not a flaky machine-independent pass/fail speed threshold.

No speedup target is set. Evaluate additional generated executors only after
repeatable profiles attribute worthwhile cost to the existing compilation or
specialization. Diagnostic allocation and presentation costs need separate
investigation; faster generated type checks would not establish a solution to them.
