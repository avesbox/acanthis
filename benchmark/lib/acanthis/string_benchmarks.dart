import 'package:acanthis/acanthis.dart';

import '../shared/acanthis_benchmark.dart';
import '../shared/payloads.dart';

class LongStringValidationBenchmark extends AcanthisBenchmark {
  LongStringValidationBenchmark()
    : super(name: 'LongStringValidationBenchmark');

  static void main() {
    LongStringValidationBenchmark().report();
  }

  final validator = string();

  @override
  void run() {
    validator.parse(Payloads.longStringPayload);
  }
}

class FixedLengthStringValidationBenchmark extends AcanthisBenchmark {
  FixedLengthStringValidationBenchmark()
    : super(name: 'FixedLengthStringValidationBenchmark');

  static void main() {
    FixedLengthStringValidationBenchmark().report();
  }

  final validator = string().max(5).min(1);

  @override
  void run() {
    validator.parse(Payloads.fixedLengthStringPayload);
  }
}

class EmptyStringValidationBenchmark extends AcanthisBenchmark {
  EmptyStringValidationBenchmark()
    : super(name: 'EmptyStringValidationBenchmark');

  static void main() {
    EmptyStringValidationBenchmark().report();
  }

  final validator = string();

  @override
  void run() {
    validator.parse(Payloads.emptyStringPayload);
  }
}

class EmailStringValidationBenchmark extends AcanthisBenchmark {
  EmailStringValidationBenchmark()
    : super(name: 'EmailStringValidationBenchmark');

  static void main() {
    EmailStringValidationBenchmark().report();
  }

  final validator = string().email();

  @override
  void run() {
    validator.parse(Payloads.emailStringPayload);
  }
}

class UuidStringValidationBenchmark extends AcanthisBenchmark {
  UuidStringValidationBenchmark()
    : super(name: 'UuidStringValidationBenchmark');

  static void main() {
    UuidStringValidationBenchmark().report();
  }

  final validator = string().uuid();

  @override
  void run() {
    validator.parse(Payloads.uuidStringPayload);
  }
}
