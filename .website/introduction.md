---
description: Define reusable schemas for Dart and Flutter. Parse input, transform values, and report structured issues.
---

# Introduction {#introduction}

Acanthis validates data at runtime. Define a schema, pass it an input, and get a typed value or issues that describe what failed.

```dart
import 'package:acanthis/acanthis.dart';

void main() {
  final email = string().trim().email();

  final String address = email.parse(' ada@example.com ');
  print(address); // ada@example.com
  print(email.validate('invalid')); // false
}
```

Schemas compose: use the same email schema in an object, a list, or a nullable field. Fluent methods return new schemas, so adding a check leaves the original reusable.

## Installation

These docs describe the V2 API in this repository. Use Dart **3.13 or later**, or a Flutter SDK that includes a compatible Dart version. When using a published package, check that its version exposes this API.

::: code-group

```sh [Dart]
dart pub add acanthis
```

```sh [Flutter]
flutter pub add acanthis
```

:::

All public APIs are available from one import:

```dart
import 'package:acanthis/acanthis.dart';
```

## Choose your next step

| You want to… | Read |
| --- | --- |
| Define and parse your first object | [Quick start](/basic-usage) |
| Find a type or a check | [Schema reference](/defining-schemas) |
| Show useful errors | [Results and issues](/validation-results) |
| Validate a form as it changes | [Live validation](/live-validation) |
| Share a JSON contract | [JSON Schema](/json-schema) |
| Upgrade an existing project | [Migrating to V2](/migration-2) |

Acanthis does not require code generation. Objects produce maps; use a [class schema](/schemas/instances#class-schemas) when you want a Dart class as output.
