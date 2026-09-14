# Correctness and performance baseline

SDK: `3.13.3 (stable) (Tue Sep 1 01:07:17 2026 -0700) on "windows_x64"`. OS: windows; logical processors: 12.
Git base: `53b2946a0ffa7a0657194c6eee0ae49dfdca264b` plus the working-tree sources fingerprinted in `source-sha256.json`.
Raw timing samples, separate lifecycle heap probes, and profile summaries are archived beside this report. Total allocation is unavailable in this baseline.

Windows x64; PROCESSOR_IDENTIFIER: AMD64 Family 25 Model 33 Stepping 2, AuthenticAMD. Active power plan verified with powercfg: Balanced (381b4222-f694-41f0-9685-ff5bb260df2e). No processor affinity or machine isolation. Tests and timing runs were sequential; normal desktop/background activity can introduce scheduling noise. Dart SDK and logical processor count are recorded in the timing JSON.

These are local descriptive measurements, not speed targets or cross-library rankings. Five 100 ms samples per case; construction is excluded from first-validation timing. First validation uses 128 fresh schemas in an already running VM. Process-start observations remain in JSON and are not cold-start confidence intervals.

## Lifecycle times (microseconds per operation)

| Workload | JIT build | JIT first | JIT warm | AOT build | AOT first | AOT warm |
|---|---:|---:|---:|---:|---:|---:|
| control.loop | 0.032 | 0.063 | 0.029 | 0.027 | 0.005 | 0.023 |
| object.specialized.valid | 1.692 | 3.420 | 0.166 | 1.898 | 1.828 | 0.173 |
| invalid90.nested | 1.985 | 7.890 | 4.196 | 2.148 | 6.818 | 4.338 |
| invalid90.issues.json | 2.090 | 11.701 | 7.934 | 2.279 | 10.867 | 8.644 |
| issues100.repeated | 0.866 | 307.299 | 285.012 | 0.740 | 307.635 | 336.217 |
| issues1000.repeated | 0.813 | 3384.456 | 3050.338 | 0.697 | 3500.789 | 3261.968 |
| union16.invalid | 4.220 | 16.322 | 18.762 | 3.629 | 17.687 | 17.801 |
| union16.last | 3.932 | 15.674 | 13.719 | 3.521 | 15.461 | 13.525 |
| union128.invalid | 25.975 | 140.058 | 131.884 | 29.987 | 151.379 | 127.908 |
| union128.last | 33.904 | 138.654 | 123.634 | 25.986 | 129.519 | 103.150 |
| transformed100.output | 1.455 | 8.973 | 7.946 | 1.415 | 7.949 | 7.403 |
| live50.independent | 84.910 | 5.338 | 24.146 | 73.272 | 4.323 | 32.867 |
| live50.full | 40.533 | 28.198 | 63.774 | 38.207 | 36.205 | 74.146 |
| async8.completed | 2.350 | 13.021 | 8.259 | 2.283 | 11.933 | 8.402 |
| control.async8.completed | 0.033 | 2.114 | 1.857 | 0.026 | 2.113 | 1.919 |
| async8.microtask | 2.255 | 9.921 | 9.114 | 2.250 | 9.381 | 7.725 |
| control.async8.microtask | 0.035 | 2.297 | 2.249 | 0.026 | 1.699 | 2.018 |
| async8.event | 2.383 | 48.362 | 43.871 | 2.241 | 67.435 | 59.616 |
| control.async8.event | 0.037 | 33.798 | 34.978 | 0.027 | 46.817 | 44.132 |

Warm ranges and all raw samples are in the JSON. Session setup includes initial validation, and live deltas do more work than the full-parse comparator. Zero-delay events measure local scheduling, not network latency.

## Allocation limitations

This SDK implements ClassHeapStats accumulatedSize and instancesAccumulated as heap census values, not cumulative allocation counters. Total bytes/objects allocated cannot be inferred from these snapshots. Allocation totals require an independently verified allocation profiler.

Worker reported no VM service isolate/counters in this product AOT SDK. A matching non-product runtime can expose heap snapshots, but total allocation still requires an independently verified profiler. RSS is not substituted for allocation.

## CPU sampling and executor decision

- invalid90.nested: 252 samples; `AcanthisIssue` (16 exclusive ticks), `_getValueOrData` (14 exclusive ticks), `addAll` (14 exclusive ticks), `[Stub] AllocateObjectParameterized` (13 exclusive ticks), `Map._fromLiteral` (6 exclusive ticks), `List.from` (6 exclusive ticks).
- issues1000.repeated: 164 samples; `List.from` (13 exclusive ticks), `AcanthisIssue` (11 exclusive ticks), `makeFixedListUnmodifiable` (8 exclusive ticks), `[Stub] Subtype4TestCache` (6 exclusive ticks), `addAll` (6 exclusive ticks), `[Stub] AllocateObjectParameterized` (5 exclusive ticks).
- object.specialized.valid: 185 samples; `_getValueOrData` (44 exclusive ticks), `accepts` (37 exclusive ticks), `[Stub] AllocateObjectParameterized` (17 exclusive ticks), `tryParse` (14 exclusive ticks), `[Stub] Subtype2TestCache` (10 exclusive ticks), `tryParseInternal` (10 exclusive ticks).

Profiles are descriptive samples, not total-allocation measurements or proof that another generated executor would help. No speedup target is introduced. Require equivalent acceptance, output, diagnostics and mutation behavior before pursuing optimization.

## Correctness evidence

All 390 tests passed (tests.log), including the presence snapshot with 504 execution observations, native/legacy issue compatibility, and overlapping-union export regression. Root and benchmark analyzers passed with --fatal-infos (analyze-root.log, analyze-benchmark.log). The full suite ran differential seed 730201 with 500 cases per corpus; an additional seed 42 run with 2000 cases per corpus passed all 5 differential tests (differential.log). Library comparison verification passed its 9-workload preflight (verify.log). The overlapping-union test was first observed failing against oneOf, then passed after the anyOf fix. The matrix deliberately records unresolved default/presence/recovery discrepancies; passing characterization is not a claim that those discrepancies are fixed. Selected-field rules are a design only and have not been implemented or benchmarked.
