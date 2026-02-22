import 'package:acanthis/acanthis.dart';

import '../shared/acanthis_benchmark.dart';

class LongStringValidationBenchmark extends AcanthisBenchmark {
  LongStringValidationBenchmark()
    : super(name: 'LongStringValidationBenchmark');

  static void main() {
    LongStringValidationBenchmark().report();
  }

  @override
  void run() {
    string().parse('long' * 256);
  }
}

class FixedLengthStringValidationBenchmark extends AcanthisBenchmark {
  FixedLengthStringValidationBenchmark()
    : super(name: 'FixedLengthStringValidationBenchmark');

  static void main() {
    FixedLengthStringValidationBenchmark().report();
  }

  @override
  void run() {
    string().max(5).min(1).parse('long');
  }
}

class EmptyStringValidationBenchmark extends AcanthisBenchmark {
  EmptyStringValidationBenchmark()
    : super(name: 'EmptyStringValidationBenchmark');

  static void main() {
    EmptyStringValidationBenchmark().report();
  }

  @override
  void run() {
    string().parse('');
  }
}

class EmailStringValidationBenchmark extends AcanthisBenchmark {
  EmailStringValidationBenchmark()
    : super(name: 'EmailStringValidationBenchmark');

  static void main() {
    EmailStringValidationBenchmark().report();
  }

  @override
  void run() {
    string().email().parse('email@example.com');
  }
}

class UuidStringValidationBenchmark extends AcanthisBenchmark {
  UuidStringValidationBenchmark()
    : super(name: 'UuidStringValidationBenchmark');

  static void main() {
    UuidStringValidationBenchmark().report();
  }

  @override
  void run() {
    string().uuid().parse('550e8400-e29b-41d4-a716-446655440000');
  }
}
