import 'package:acanthis/acanthis.dart';
import 'package:benchmarks/shared/acanthis_benchmark.dart';
import 'package:benchmarks/shared/payloads.dart';

class NestedObjectValidator extends AcanthisBenchmark {
  NestedObjectValidator() : super(name: 'NestedObjectValidator');

  static void main() {
    NestedObjectValidator().report();
  }

  final validator = object({
    'username': string(),
    'password': string(),
    'contact': object({'name': string(), 'address': string().nullable()}),
  });

  @override
  void run() {
    validator.parse(Payloads.nestedObjectPayload);
  }
}

class FlatObjectValidator extends AcanthisBenchmark {
  FlatObjectValidator() : super(name: 'FlatObjectValidator');

  static void main() {
    FlatObjectValidator().report();
  }

  final validator = object({'firstname': string(), 'lastname': string()});

  @override
  void run() {
    validator.parse(Payloads.flatObjectPayload);
  }
}

class ArrayObjectValidator extends AcanthisBenchmark {
  ArrayObjectValidator() : super(name: 'ArrayObjectValidator');

  static void main() {
    ArrayObjectValidator().report();
  }

  final validator = object({
    'contacts': object({'type': string(), 'value': string()}).list(),
  });

  @override
  void run() {
    validator.parse(Payloads.objectArrayPayload);
  }
}
