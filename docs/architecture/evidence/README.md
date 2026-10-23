# Review evidence

Captured 2026-10-13 against package 2.1.0 on Dart 3.13.3 stable, Windows x64, 12 logical processors. This review changed documentation only; temporary compiler/probe sources were used under the existing ignored `.dart_tool` directory and removed after recording their contents.

| Artifact | What it establishes |
| --- | --- |
| [Runtime/compiler probes](runtime-probes.md) | Reduced failures and passing controls, exact runnable source, observed output, and static inference errors |
| [Schema base experiment](schema-base-probe.md) | Later `Schema<I,O>` prototype using archived `v1/lib`, four inherited methods, exact output, alias checks and a Dart covariance counterexample |
| [Source fingerprint](source-fingerprint.md) | SHA-256 of library/tests/harnesses/tools and dependency/configuration inputs in the dirty checkout |
| [Benchmark samples](benchmark-samples.md) | Full raw lifecycle JIT/AOT samples and JIT diagnostics/rules-live measurements, including controls and runtime metadata |

## Verification results

- `dart analyze`: no issues; final exit 0. First sandbox run printed no issues but exited 1 on telemetry file modification; approved retry completed.
- `dart run test --reporter expanded`: **583 passed**, exit 0; default differential seed 730201 and configured case count 500.
- Seed 42, configured case count 2,000: **five differential tests passed**, exit 0. These tests contain randomized loops; five is the runner's test count, not the number of generated inputs.
- `dart run tool/check_schema_registry_types.dart`: expected failures for binding/output/nested-binding fixtures and successful cross-module AOT example all passed.
- Two new compiler probes: expected `num -> int` and `int? -> int` assignment errors. Sandbox telemetry noise was removed by final retries; neither failure was an unrelated package/import error.
- Proposed `OutcomeEvaluator`, generic `mapValid`, and sealed-outcome pattern examples compiled and ran on the current SDK. A valid stage produced `1`; an invalid stage skipped its mapper and returned invalid without recovery.
- `dart run tool/audit_schema_export.dart`: eight Dart corpus tests passed; Python stage failed with `ModuleNotFoundError: No module named 'jsonschema'`. Optional Python validators were not installed; independent JSON/OpenAPI parity is unavailable for this run.

No refactor speedup, allocation total, p95/p99 latency, or universal performance claim follows from these observations. CPU model query and power policy were unavailable/unverified. Benchmark timing workers ran sequentially, without concurrent test/build workers, in an interactive desktop session with uncontrolled background load.

Final QA found no broken local Markdown links or unbalanced fenced code blocks. Rechecking all 202 fingerprinted input files found **zero content mismatches**; library, existing tests, tools, dependency files and benchmark implementations remained unchanged.

## Exact timing commands

From the root:

```powershell
dart run benchmark/error-contract/benchmark.dart .dart_tool/architecture-review-errors-jit.json
dart run benchmark/rules-live/benchmark.dart 10000 .dart_tool/architecture-review-live-jit.json
dart compile exe benchmark/bin/continuous_benchmarks.dart -o .dart_tool/architecture-review-continuous.exe
```

From `.dart_tool` (keeps new runtime output separate from historical measurements):

```powershell
dart run ../benchmark/bin/continuous_benchmarks.dart --extended jit
./architecture-review-continuous.exe --extended aot
```

The lifecycle files were embedded verbatim as JSON data in the Markdown sample artifact rather than replacing historical `benchmark/` files. Five rounds, 100 ms sample windows, 128 fresh schemas per first-use sample, order seed 42, and semantic preflight passed for each mode. JIT and AOT ran in separate sequential processes. The error/live harnesses retain their own seven-sample protocols; those are not interchangeable with the lifecycle protocol.

## Reproduction limits

Use the actual source hashes, not just base commit `517d2a6eb8ff66fcfc6d7932dea0cf7e6b332276`: the checkout already contained extensive changes. A hash manifest identifies files but does not itself archive their content. Preserve the current working tree or a separate snapshot before implementing later phases. No commit or destructive Git operation was performed by this review.

The current allocation profiler explains that VM heap census snapshots cannot establish total allocated bytes/objects, especially across GC; product AOT counters may also be unavailable. That measurement gap remains open rather than being filled with RSS or extrapolated timings. Independent export verification can be rerun in an environment with `tool/schema-export-requirements.txt` already available.
