# Selected rules and live editing benchmark

Recorded 2026-09-28 on Windows x64, Dart 3.13.3, 12 logical processors.
Raw samples and runtime metadata are in `jit.json` and `aot.json`.

| Operation | JIT median µs/op | AOT median µs/op |
| --- | ---: | ---: |
| Construct 24 fields and one rule | 10.060 | 11.503 |
| Synchronous full validation | 9.824 | 9.880 |
| Synchronous live edit + delta | 14.744 | 14.784 |
| Asynchronous full validation | 26.183 | 24.434 |
| Asynchronous live edit + delta | 21.314 | 21.486 |

Each scenario warms up for 2,000 operations, then records seven samples of
10,000 operations. Construction is separate from reused-schema evaluation.
Inputs alternate valid and invalid password-style comparisons. Every field has
cheap string checks; async fields add an immediately completing Future, without
network latency or artificial sleep. The sink consumes results to retain work.

A semantic preflight verifies that a live edit runs one field and one dependent
rule out of 24 fields and matches full-validation issue count. Behavioral tests
provide stronger output/ordered-issue parity checks, including nested collection
edits and asynchronous revisions.

Async live editing reduces elapsed time by 18.6% in this JIT run and 12.1% in AOT.
Synchronous live editing is about 50% slower than full validation of these cheap
fields: copying snapshots, tracking dependencies, and constructing deltas cost
more than the checks saved. The benefit demonstrated here is reducing field
execution from 24 to one, not a universal throughput improvement. Expensive
validators may benefit more; that is not quantified by this workload. These
numbers are same-version full-versus-live comparisons, not release comparisons
or allocation measurements.

Run from the repository root:

```powershell
dart run benchmark/rules-live/benchmark.dart 10000 benchmark/rules-live/jit.json
dart compile exe benchmark/rules-live/benchmark.dart -o benchmark/rules-live/benchmark.exe
./benchmark/rules-live/benchmark.exe 10000 benchmark/rules-live/aot.json
```

Verification for this implementation:

- `dart run test --reporter expanded`: 459 tests pass, including the existing
  500-case seeded differential corpus and 200 sync/async nested edit revisions.
- `dart analyze --fatal-infos`: no issues.
- `npm run docs:build` in `.website`: production build passes.

Focused test files: `selected_field_rules_test.dart`,
`collection_policy_test.dart`, `live_editing_test.dart`,
`live_dependency_test.dart`, and `async_live_test.dart`.
