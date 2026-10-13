# Error-contract JIT/AOT evidence

Recorded 2026-10-12 on Windows x64, Dart 3.13.3, 12 logical processors. Raw
seven-sample results and runtime metadata are retained beside this document.
Each new workload warms for 5,000 operations then measures seven samples of
20,000 operations. Schemas and input are reused; a sink consumes the results.

| Workload | JIT median µs/op | AOT median µs/op |
| --- | ---: | ---: |
| Collect two field failures | 0.494 | 0.568 |
| JSON with fallback messages | 2.028 | 2.774 |
| JSON with English catalog | 2.421 | 3.210 |
| JSON with Italian catalog | 2.408 | 3.116 |
| Versioned transport JSON | 2.067 | 2.478 |
| Fail-fast validate, fallback | 4.655 | 4.332 |
| Fail-fast validate, Italian | 4.535 | 4.548 |

Catalog JSON formatting cost about 19% more in JIT and 12–16% more in AOT than
fallback formatting in this run. Transport omits messages, but adds an envelope;
it is a semantic API, not a guaranteed speed optimization. The small JIT
fail-fast difference is within run noise and is not evidence localization is
faster. No allocation measurement or universal throughput claim is made.

## Existing baseline comparison

The unchanged [rules/live workload](../rules-live/README.md) was also rerun with
its original 2,000 warmup / seven samples / 10,000 operations. This is a historical
same-workload comparison, not a controlled checkout-to-checkout experiment.
Machine load and all intervening working-tree changes can affect differences.

| Workload | Previous JIT | Current JIT | Previous AOT | Current AOT |
| --- | ---: | ---: | ---: | ---: |
| Construct | 10.060 | 12.127 | 11.503 | 11.924 |
| Sync full | 9.824 | 10.344 | 9.880 | 9.217 |
| Sync live | 14.744 | 14.323 | 14.784 | 14.573 |
| Async full | 26.183 | 23.954 | 24.434 | 24.407 |
| Async live | 21.314 | 20.408 | 21.486 | 21.487 |

All values are median µs/op. JIT construction was about 21% slower in this run;
the AOT construction difference was about 4%. These observations warrant profiling
before attributing a regression to diagnostics. Settled live preflight still
executes one field and one rule out of 24. Existing raw baselines were preserved.

## Reproduce from the repository root

```powershell
dart run benchmark/error-contract/benchmark.dart benchmark/error-contract/jit.json
dart compile exe benchmark/error-contract/benchmark.dart -o .dart_tool/error-contract-benchmark.exe
./.dart_tool/error-contract-benchmark.exe benchmark/error-contract/aot.json
dart run benchmark/rules-live/benchmark.dart 10000 benchmark/error-contract/rules-live-jit.json
dart compile exe benchmark/rules-live/benchmark.dart -o .dart_tool/error-contract-rules.exe
./.dart_tool/error-contract-rules.exe 10000 benchmark/error-contract/rules-live-aot.json
```

Run measurements without concurrent test/build processes. The package analyzer
excludes benchmarks, so analyze this benchmark explicitly as part of verification.
