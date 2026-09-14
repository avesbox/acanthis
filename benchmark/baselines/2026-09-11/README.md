# Correctness and performance baseline

SDK: `3.13.3 (stable) (Tue Sep 1 01:07:17 2026 -0700) on "windows_x64"`. OS: windows; logical processors: 12.
Git base: `53b2946a0ffa7a0657194c6eee0ae49dfdca264b` plus the working-tree sources fingerprinted in `source-sha256.json`.
Raw timing samples, separate lifecycle heap probes, and profile summaries are archived beside this report. Total allocation is unavailable in this baseline.

Windows Balanced power plan; no processor affinity or machine isolation. Treat these measurements as a local baseline with scheduling noise.

These are local descriptive measurements, not speed targets or cross-library rankings. Five 100 ms samples per case; construction is excluded from first-validation timing. First validation uses 128 fresh schemas in an already running VM. Process-start observations remain in JSON and are not cold-start confidence intervals.

## Lifecycle times (microseconds per operation)

| Workload | JIT build | JIT first | JIT warm | AOT build | AOT first | AOT warm |
|---|---:|---:|---:|---:|---:|---:|
| control.loop | 0.060 | 0.095 | 0.045 | 0.042 | 0.008 | 0.036 |
| object.specialized.valid | 3.147 | 4.756 | 0.320 | 3.061 | 2.964 | 0.285 |
| invalid90.nested | 3.369 | 18.964 | 7.807 | 3.704 | 12.720 | 8.443 |
| invalid90.issues.json | 3.154 | 19.368 | 12.331 | 4.087 | 20.249 | 15.913 |
| issues100.repeated | 1.291 | 441.578 | 431.868 | 1.263 | 592.750 | 648.444 |
| issues1000.repeated | 1.357 | 4762.116 | 5543.730 | 1.138 | 6074.297 | 5987.775 |
| union16.invalid | 5.095 | 30.637 | 29.036 | 6.366 | 35.273 | 29.415 |
| union16.last | 5.781 | 41.415 | 21.647 | 5.771 | 24.766 | 23.685 |
| union128.invalid | 52.664 | 256.178 | 225.984 | 41.499 | 291.647 | 238.249 |
| union128.last | 41.971 | 218.601 | 179.363 | 41.743 | 217.932 | 188.314 |
| transformed100.output | 2.555 | 12.491 | 12.010 | 2.647 | 16.377 | 13.712 |
| live50.independent | 151.890 | 8.594 | 41.657 | 131.516 | 10.416 | 58.905 |
| live50.full | 81.402 | 54.803 | 121.674 | 63.490 | 78.927 | 149.337 |
| async8.completed | 4.254 | 18.080 | 16.617 | 4.103 | 19.345 | 15.888 |
| control.async8.completed | 0.060 | 4.029 | 3.286 | 0.048 | 3.058 | 3.724 |
| async8.microtask | 3.859 | 16.709 | 18.080 | 4.028 | 15.931 | 14.623 |
| control.async8.microtask | 0.058 | 3.946 | 3.581 | 0.045 | 3.122 | 3.329 |
| async8.event | 3.580 | 97.788 | 89.268 | 3.357 | 82.744 | 85.735 |
| control.async8.event | 0.058 | 66.144 | 63.412 | 0.048 | 59.347 | 69.371 |

Warm ranges and all raw samples are in the JSON. Session setup includes initial validation, and live deltas do more work than the full-parse comparator. Zero-delay events measure local scheduling, not network latency.

## Allocation limitations

This SDK implements ClassHeapStats accumulatedSize and instancesAccumulated as heap census values, not cumulative allocation counters. Total bytes/objects allocated cannot be inferred from these snapshots. Allocation totals require an independently verified allocation profiler.

Worker reported no VM service isolate/counters in this product AOT SDK. A matching non-product runtime can expose heap snapshots, but total allocation still requires an independently verified profiler. RSS is not substituted for allocation.

## CPU sampling and executor decision

- invalid90.nested: 578 samples; `[Stub] AllocateObjectParameterized` (29 exclusive ticks), `AcanthisIssue` (25 exclusive ticks), `addAll` (24 exclusive ticks), `List.from` (23 exclusive ticks), `makeFixedListUnmodifiable` (21 exclusive ticks), `_getValueOrData` (20 exclusive ticks).
- issues1000.repeated: 311 samples; `addAll` (21 exclusive ticks), `AcanthisIssue` (18 exclusive ticks), `[Stub] Subtype4TestCache` (17 exclusive ticks), `[Stub] AllocateObjectParameterized` (16 exclusive ticks), `[Stub] AllocateClosure1` (12 exclusive ticks), `List.from` (10 exclusive ticks).
- object.specialized.valid: 343 samples; `_getValueOrData` (68 exclusive ticks), `accepts` (66 exclusive ticks), `[Stub] Subtype2TestCache` (31 exclusive ticks), `[Stub] AllocateObjectParameterized` (30 exclusive ticks), `tryParse` (24 exclusive ticks), `tryParse` (19 exclusive ticks).

The diagnostic-heavy samples include issue creation, list/map freezing and allocation stubs. This supports investigating diagnostic allocation separately; it does not establish a benefit from another generated executor. The specialized valid path is already much smaller than these invalid workloads. No generated executor or speedup target is introduced. Require equivalent acceptance, output, diagnostics and mutation behavior, then repeated matched profiles before pursuing such an optimization.

## Correctness evidence

All 386 tests passed; root and benchmark analyzers passed with fatal infos. The test suite includes seed 730201 with 500 cases per randomized corpus and a separately executed, logged seed 42 with 2000 cases per corpus. It covers specialization-eligible nested objects, composition, and independent/cross-field live updates. Seeded generation tests verify that every returned value validates and that unsupported/contradictory cases terminate with a reason. See `benchmark/README.md` for reproduction and the optimization gate.
