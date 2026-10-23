import 'package:benchmarks/shared/acanthis_benchmark.dart';
import 'package:vine/vine.dart';
import 'package:benchmarks/shared/payloads.dart';

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
    validator.validate(Payloads.nestedObjectPayload);
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
    validator.validate(Payloads.flatObjectPayload);
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
    validator.validate(Payloads.objectArrayPayload);
  }
}
