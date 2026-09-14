---
description: Install Acanthis and choose a starting point for validating data in Dart and Flutter.
---

# Validate data with Acanthis {#introduction}

Acanthis is a schema validation library for Dart and Flutter. Describe the data you expect, validate input at runtime, and use the result in your application.

Use it for form fields, API payloads, configuration, or any other data entering your application. Its chainable API is inspired by [Zod](https://zod.dev).

## Installation

<span id="requirements"></span>

::: info Version scope
These docs describe the 2.0 codebase, which requires **Dart 3.13 or later**. Flutter projects need a Flutter SDK with a compatible Dart version. See the [migration guide](/migration-2) when upgrading from 1.x; check [pub.dev](https://pub.dev/packages/acanthis) for published releases.
:::

::: code-group

```sh [Dart]
dart pub add acanthis
```

```sh [Flutter]
flutter pub add acanthis
```

:::

Import the library wherever you define a schema:

```dart
import 'package:acanthis/acanthis.dart';
```

## The core idea

A schema combines a type with checks. Parsing applies those checks to an input and returns a result.

```dart
final email = string().email();
final result = email.tryParse('ada@example.com');

print(result.success); // true
print(result.value); // ada@example.com
```

Schema methods return new instances, so you can reuse a base schema and extend its checks. Successful validation can preserve input identity; it does not guarantee a deep copy. See [input sharing in 2.0](/migration-2#parsed-values-can-share-input-identity).

## Choose your next step

<div class="doc-cards">
<a href="/basic-usage.html"><strong>Start with a complete example →</strong><span>Define an object, validate input, and handle errors.</span></a>
<a href="/defining-schemas.html"><strong>Find a schema →</strong><span>Browse types, built-in checks, and composition methods.</span></a>
<a href="/validation-results.html"><strong>Understand results →</strong><span>Choose a parsing API and work with structured issues.</span></a>
<a href="/live-validation.html"><strong>Validate changing input →</strong><span>Update fields in a live session and inspect validation deltas.</span></a>
</div>

## More than validation

- [Custom rules](/schemas/refinements) for application-specific checks, including async work.
- [Transformations](/schemas/transformations) for converting input into the output you need.
- [JSON Schema](/json-schema) and [OpenAPI](/open-api-schema) exports for supported schemas.
- [Seeded mocking](/seeded-mocking) for reproducible test data within a documented supported subset.
