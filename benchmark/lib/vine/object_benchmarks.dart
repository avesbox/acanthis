import 'package:benchmarks/shared/acanthis_benchmark.dart';
import 'package:vine/vine.dart';

class VineNestedObjectValidator extends AcanthisBenchmark {
  VineNestedObjectValidator() : super(name: 'VineNestedObjectValidator');

  static void main() {
    VineNestedObjectValidator().report();
  }

  final validator = vine.compile(
    vine.object({
      'username': vine.string(),
      'password': vine.string(),
      'contact': vine.object({
        'name': vine.string(),
        'address': vine.string().optional(),
      }),
    }),
  );

  @override
  void run() {
    final payload = {
      'username': 'John Doe',
      'password': 'secret',
      'contact': {'name': 'John Doe', 'address': '123 Main St'},
    };
    validator.validate(payload);
  }
}

class VineFlatObjectValidator extends AcanthisBenchmark {
  VineFlatObjectValidator() : super(name: 'VineFlatObjectValidator');

  static void main() {
    VineFlatObjectValidator().report();
  }

  final validator = vine.compile(
    vine.object({'firstname': vine.string(), 'lastname': vine.string()}),
  );

  @override
  void run() {
    final payload = {'firstname': 'John', 'lastname': 'Doe'};
    validator.validate(payload);
  }
}

class VineArrayObjectValidator extends AcanthisBenchmark {
  VineArrayObjectValidator() : super(name: 'VineArrayObjectValidator');

  static void main() {
    VineArrayObjectValidator().report();
  }

  final validator = vine.compile(
    vine.object({
      'contacts': vine.array(
        vine.object({'type': vine.string(), 'value': vine.string().optional()}),
      ),
    }),
  );

  @override
  void run() {
    final payload = {
      'contacts': [
        {'type': 'email', 'value': 'foo@bar.com'},
        {'type': 'phone', 'value': '12345678'},
      ],
    };
    validator.validate(payload);
  }
}
