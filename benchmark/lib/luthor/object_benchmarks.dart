import 'package:benchmarks/shared/acanthis_benchmark.dart';
import 'package:luthor/luthor.dart';
import 'package:benchmarks/shared/payloads.dart';

class LuthorNestedObjectValidator extends AcanthisBenchmark {
  LuthorNestedObjectValidator() : super(name: 'LuthorNestedObjectValidator');

  static void main() {
    LuthorNestedObjectValidator().report();
  }

  final validator = l.schema({
    'username': l.string(),
    'password': l.string(),
    'contact': l.schema({'name': l.string(), 'address': l.string()}),
  });

  @override
  void run() {
    validator.validate(Payloads.nestedObjectPayload);
  }
}

class LuthorFlatObjectValidator extends AcanthisBenchmark {
  LuthorFlatObjectValidator() : super(name: 'LuthorFlatObjectValidator');

  static void main() {
    LuthorFlatObjectValidator().report();
  }

  final validator = l.schema({'firstname': l.string(), 'lastname': l.string()});

  @override
  void run() {
    validator.validate(Payloads.flatObjectPayload);
  }
}

class LuthorArrayObjectValidator extends AcanthisBenchmark {
  LuthorArrayObjectValidator() : super(name: 'LuthorArrayObjectValidator');

  static void main() {
    LuthorArrayObjectValidator().report();
  }

  final validator = l.schema({
    'contacts': l.list(l.schema({'type': l.string(), 'value': l.string()})),
  });

  @override
  void run() {
    validator.validate(Payloads.objectArrayPayload);
  }
}
