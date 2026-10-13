# Acanthis examples

Run these commands from the repository root after `dart pub get`. Use Dart 3.13
or later for the 2.0 codebase.

| Example | What it demonstrates | Command |
| --- | --- | --- |
| [Email validation](lib/example.dart) | A schema and a success/failure outcome | `dart run example/lib/example.dart` |
| [Request validation](request_validation.dart) | JSON decoding, structured errors, domain mapping, and PATCH omission/null handling | `dart run example/request_validation.dart` |

The request example prints valid creation, invalid fields, malformed JSON,
non-object JSON, a null nickname update, and an empty patch. It uses no server or
database. Copy its handler into your application and adapt the response record
to your framework.

For an interactive example, follow the
[Flutter live-form recipe](../.website/flutter-live-form.md). Its complete
`main.dart` belongs in a Flutter project with Acanthis installed; username lookup
and submission use simulated services. See the
[request-validation guide](../.website/request-validation.md) for the Dart
handler walkthrough.
