import 'package:luthor/luthor.dart';

import '../shared/acanthis_benchmark.dart';
import '../shared/payloads.dart';

class LongLuthorStringValidationBenchmark extends AcanthisBenchmark {
  LongLuthorStringValidationBenchmark()
    : super(name: 'LongLuthorStringValidationBenchmark');

  static void main() {
    LongLuthorStringValidationBenchmark().report();
  }

  final validator = l.string();

  @override
  void run() {
    validator.validate(Payloads.longStringPayload);
  }
}

class FixedLuthorLengthStringValidationBenchmark extends AcanthisBenchmark {
  FixedLuthorLengthStringValidationBenchmark()
    : super(name: 'FixedLuthorLengthStringValidationBenchmark');

  static void main() {
    FixedLuthorLengthStringValidationBenchmark().report();
  }

  final validator = l.string().max(5).min(1);

  @override
  void run() {
    validator.validate(Payloads.fixedLengthStringPayload);
  }
}

class EmptyLuthorStringValidationBenchmark extends AcanthisBenchmark {
  EmptyLuthorStringValidationBenchmark()
    : super(name: 'EmptyLuthorStringValidationBenchmark');

  static void main() {
    EmptyLuthorStringValidationBenchmark().report();
  }

  final validator = l.string();

  @override
  void run() {
    validator.validate(Payloads.emptyStringPayload);
  }
}

class EmailLuthorStringValidationBenchmark extends AcanthisBenchmark {
  EmailLuthorStringValidationBenchmark()
    : super(name: 'EmailLuthorStringValidationBenchmark');

  static void main() {
    EmailLuthorStringValidationBenchmark().report();
  }

  final validator = l.string().email();

  @override
  void run() {
    validator.validate(Payloads.emailStringPayload);
  }
}

class UuidLuthorStringValidationBenchmark extends AcanthisBenchmark {
  UuidLuthorStringValidationBenchmark()
    : super(name: 'UuidLuthorStringValidationBenchmark');

  static void main() {
    UuidLuthorStringValidationBenchmark().report();
  }

  final validator = l.string().uuid();

  @override
  void run() {
    validator.validate(Payloads.uuidStringPayload);
  }
}
