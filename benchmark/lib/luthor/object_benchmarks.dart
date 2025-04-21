import 'package:benchmarks/shared/acanthis_benchmark.dart';
import 'package:luthor/luthor.dart';

class LuthorNestedObjectValidator extends AcanthisBenchmark {
  LuthorNestedObjectValidator() : super(name: 'LuthorNestedObjectValidator');

  static void main() {
    LuthorNestedObjectValidator().report();
  }

  @override
  void run() {
    final validator = l.schema({
      'username': l.string(),
      'password': l.string(),
      'contact': l.schema({
        'name': l.string(),
        'address': l.string(),
      }),
    });
    final payload = {
      'username': 'John Doe',
      'password': 'secret',
      'contact': {
        'name': 'John Doe',
        'address': '123 Main St',
      },
    };
    validator.validateSchema(payload);
  }
}

class LuthorFlatObjectValidator extends AcanthisBenchmark {
  LuthorFlatObjectValidator() : super(name: 'LuthorFlatObjectValidator');

  static void main() {
    LuthorFlatObjectValidator().report();
  }

  @override
  void run() {
    final validator = l.schema({
      'firstname': l.string(),
      'lastname': l.string(),
    });

    final payload = {
      'firstname': 'John',
      'lastname': 'Doe',
    };
    validator.validateSchema(payload);
  }
}

class LuthorArrayObjectValidator extends AcanthisBenchmark {
  LuthorArrayObjectValidator() : super(name: 'LuthorArrayObjectValidator');

  static void main() {
    LuthorArrayObjectValidator().report();
  }

  @override
  void run() {
    final validator = l.schema({
      'contacts': l.list(validators: [
        l.schema({
          'type': l.string(),
          'value': l.string(),
        }),
      ]),
    });

    final payload = {
      'contacts': [
        {'type': 'email', 'value': 'foo@bar.com'},
        {'type': 'phone', 'value': '12345678'},
      ],
    };
    validator.validateSchema(payload);
  }
}
