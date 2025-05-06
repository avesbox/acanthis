# Customizing Errors

In Acanthis you can customize the error messages for each validator. This is done by passing a `message` parameter to the validator or, in some cases, by passing the `messageBuilder` function.

```dart
import 'package:acanthis/acanthis.dart';

void main() {
  final schema = AcanthisObject({
    'name': AcanthisString().required(message: 'Name is required'),
    'age': AcanthisNumber().min(18, messageBuilder: (value) => 'You must be at least $value years old'),
    'email': AcanthisString().email(message: 'Invalid email address'),
  });

  final result = schema.validate({
    'name': '',
    'age': 16,
    'email': 'invalid-email',
  });

  print(result.errors); // [Name is required, You must be at least 18 years old, Invalid email address]
}
```

In the example above, we have customized the error messages for the `name`, `age`, and `email` validators. The `message` parameter is a simple string, while the `messageBuilder` function allows you to create a dynamic message based on the check value passed to the validator.
