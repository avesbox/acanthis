# Error-contract and Standard Schema integration checks

These are separate example packages; Acanthis core gains no framework or Standard
Schema dependency. Run commands from the indicated directory.

## Flutter field

In `flutter_error_contract`: `flutter pub get`, `flutter analyze`, `flutter test`.
Verified on Flutter 3.47.2 (revision `d3b14c8769`), Dart 3.13.2, Windows x64.
The widget test validates once, switches English/Italian locale, and renders the
same `minLength` code at `/email` without revalidation. The lockfile pins resolved
dependencies; Flutter itself must be selected at the version above to reproduce.

## Serinus endpoint, JavaScript consumer, and Standard Schema probes

In `error_contract`:

```console
dart pub get
dart run tool/prepare_serinus.dart
dart pub get
dart analyze --fatal-infos
dart run test --reporter expanded
```

Direct packages are pinned to Serinus 2.1.12, `standard_schema` 0.0.1, and
`enhanced_standard_schema` 1.1.0. Verified with Dart 3.13.3 and Node 22.20.0 on Windows.
The endpoint returns HTTP 422 with the version-1 envelope. The Node consumer
asserts the code, parameters and pointer and independently renders both languages.

**Upstream limitation:** unmodified Serinus 2.1.12 fails compilation on this Dart
SDK in `route_execution_context.dart`: nullable `executionContext` is not promoted
across `await`. Versions 2.1.11, 2.1.0 and 2.0.0 showed the same failure. The retained
preparation script copies the exact resolved 2.1.12 source into `.dart_tool`, adds
explicit null assertions at the affected uses, and generates an ignored local
override. It does not modify the pub cache or another checkout. The endpoint test
passes with that documented compatibility patch; unmodified upstream verification
remains blocked. Remove the override and rerun resolution when upstream fixes it.

The Standard Schema probes need no Serinus patch when run alone:
`dart run test test/standard_adapters_test.dart`. They exercise typed sync/async
success, data paths, enhanced metadata, defensive copying, and audited JSON Schema
target rejection. `lib/standard_adapters.dart` is a feasibility example, not a
supported adapter package; vendor options are deliberately not interpreted.
