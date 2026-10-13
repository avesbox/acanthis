![Acanthis Banner](https://github.com/avesbox/acanthis/raw/main/assets/github-header.png)

# Acanthis

Acanthis is a simple and easy to use validation library for Dart. It is inspired by [Zod](https://github.com/colinhacks/zod) although it is not a port of it. Acanthis is tailored to the Dart language and its features and is type-safe and composable.

[Get Started](https://acanthis.dev/introduction.html) | [Pub.dev](https://pub.dev/packages/acanthis)

## Why Acanthis?

Acanthis provides validation for most of the Dart built-in types and allows you to create custom validators.

But that's not all! Acanthis is designed to be composable, so you can create complex validators by combining simpler ones.

## Quick start

The 2.0 codebase requires Dart 3.13 or later, including a compatible Dart SDK in
Flutter projects. See [pub.dev](https://pub.dev/packages/acanthis) for published
versions and the [migration guide](https://acanthis.dev/migration-2.html) for 1.x upgrades.

```sh
dart pub add acanthis
```

```dart
import 'package:acanthis/acanthis.dart';

void main() {
  final account = object({
    'name': string().min(2),
    'email': string().email(),
  });
  final result = account.tryParse({
    'name': 'Ada',
    'email': 'ada@example.com',
  });
  if (result.isValid) {
    print(result.value);
  } else {
    for (final issue in result.issues) {
      print('${issue.jsonPointer}: ${issue.message}');
    }
  }
}
```

Use `parse()` when validation failure should throw, or `validate()` for a nullable
field-error message. An invalid `tryParse()` result contains best-effort output;
check `isValid` before using its value. Explore the
[examples](example/README.md) and [full documentation](https://acanthis.dev/introduction.html).

## Contributions

Contributions are welcome! If you want to contribute to Acanthis, you can open a pull request on the [GitHub repository](https://github.com/avesbox/acanthis/pulls)

## License

Acanthis is licensed under the MIT License. You can read the [MIT license](https://github.com/avesbox/acanthis/blob/main/LICENSE)

## Credits

Acanthis is developed and maintained by [Avesbox](https://avesbox.com)
