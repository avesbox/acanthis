# Acanthis

Composable runtime validation for Dart and Flutter. Define a schema, parse untrusted input, and get typed values or structured issues.

```dart
import 'package:acanthis/acanthis.dart';

void main() {
  final account = object({
    'name': string().trim().min(2),
    'email': string().email(),
    'age': integer().gte(18),
  });

  final result = account.tryParse({
    'name': ' Ada ',
    'email': 'ada@example.com',
    'age': 28,
  });

  if (result.isValid) {
    print(result.value['name']); // Ada
  } else {
    print(result.issues.formatFields());
  }
}
```

These docs describe the V2 code in this repository. Dart 3.13+ is required; Flutter projects need a compatible Dart SDK. Check the API version when using a published release.

## Install

```sh
dart pub add acanthis
# Flutter projects:
flutter pub add acanthis
```

## Parse, inspect, or check

| API | Result |
| --- | --- |
| `schema.parse(input)` | Parsed output; throws `ValidationError` on failure |
| `schema.tryParse(input)` | `AcanthisValid<T>` or `AcanthisInvalid<T>` with issues |
| `schema.validate(input)` | Boolean, stopping at the first failure |

Async schemas use the corresponding `parseAsync`, `tryParseAsync`, and `validateAsync` methods. Invalid outcomes may have typed recovery; it still fails validation. Read `.value` on success, or check `AcanthisInvalid.hasValue` before inspecting recovery.

## Compose schemas

```dart
final name = string().min(2);
final names = name.list();
final nullableName = name.nullable();
final scores = record(string(), integer().gte(0));
final age = string().pipe(integer().gte(18), transform: int.parse);
final patch = object({'name': name}).patch();
```

Native fluent methods return new schemas. Object fields are required by default; unknown keys are stripped. Nullability permits null, while `.optionals([...])` permits omission. Defaults replace missing/null input and are validated. `.patch()` preserves omitted fields, including those with defaults.

Parsed maps and lists can share input identity when unchanged. Copy containers if you need independent mutable data.

## Explore the API

- [Quick start](https://acanthis.dev/basic-usage.html) — define, parse, and handle issues.
- [Schema reference](https://acanthis.dev/defining-schemas.html) — primitives, objects, records, collections, instances, and composition.
- [Cross-field rules](https://acanthis.dev/contextual-rules.html) — parsed prerequisites, typed context, and cancellation.
- [Live validation](https://acanthis.dev/live-validation.html) — incremental edits, debouncing, revisions, and issue deltas.
- [Localization](https://acanthis.dev/error-customization.html) — presentation-time messages, English/Italian catalogs, and application overrides.
- [Metadata](https://acanthis.dev/metadata.html) and [registries](https://acanthis.dev/schema-registry.html) — descriptions and typed schema lookup.
- [JSON Schema](https://acanthis.dev/json-schema.html) and [OpenAPI](https://acanthis.dev/open-api-schema.html) — strict export and compiled import of supported JSON contracts.
- [Mock generation](https://acanthis.dev/seeded-mocking.html) — bounded, reproducible samples and custom input generators.
- [Migrating to V2](https://acanthis.dev/migration-2.html) — return types and compatibility changes.

Export and mocking have explicit supported subsets. Unsupported behavior fails with an explanation instead of silently weakening a contract or returning invalid data.

The website sources are in [`.website/`](.website/introduction.md). [V2 reference notes](docs/v2/README.md) describe detailed implementation contracts. [Examples](example/) contain runnable Dart programs.

## Work on the project

From the repository root:

```sh
dart pub get
dart analyze --fatal-infos
dart test --reporter failures-only
```

Build the documentation from `.website/`:

```sh
npm ci
npm run docs:build
```

The [contract guide](docs/v2/contracts.md) documents the independent JSON/OpenAPI export audit. [Benchmarks](benchmark/README.md) compare implementations; archived V1 sources live under `v1/` for those comparisons.

Released changes are recorded in [CHANGELOG.md](CHANGELOG.md). This project uses the [MIT license](LICENSE).
