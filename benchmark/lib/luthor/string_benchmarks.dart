import 'package:luthor/luthor.dart';

import '../shared/acanthis_benchmark.dart';

class LongLuthorStringValidationBenchmark extends AcanthisBenchmark {
  LongLuthorStringValidationBenchmark()
    : super(name: 'LongLuthorStringValidationBenchmark');

  static void main() {
    LongLuthorStringValidationBenchmark().report();
  }

  @override
  void run() {
    l.string().validateValue('long' * 256);
  }
}

class FixedLuthorLengthStringValidationBenchmark extends AcanthisBenchmark {
  FixedLuthorLengthStringValidationBenchmark()
    : super(name: 'FixedLuthorLengthStringValidationBenchmark');

  static void main() {
    FixedLuthorLengthStringValidationBenchmark().report();
  }

  @override
  void run() {
    l.string().max(5).min(1).validateValue('long');
  }
}

class EmptyLuthorStringValidationBenchmark extends AcanthisBenchmark {
  EmptyLuthorStringValidationBenchmark()
    : super(name: 'EmptyLuthorStringValidationBenchmark');

  static void main() {
    EmptyLuthorStringValidationBenchmark().report();
  }

  @override
  void run() {
    l.string().validateValue('');
  }
}

class EmailLuthorStringValidationBenchmark extends AcanthisBenchmark {
  EmailLuthorStringValidationBenchmark()
    : super(name: 'EmailLuthorStringValidationBenchmark');

  static void main() {
    EmailLuthorStringValidationBenchmark().report();
  }

  @override
  void run() {
    l.string().email().validateValue('email@example.com');
  }
}

class UuidLuthorStringValidationBenchmark extends AcanthisBenchmark {
  UuidLuthorStringValidationBenchmark()
    : super(name: 'UuidLuthorStringValidationBenchmark');

  static void main() {
    UuidLuthorStringValidationBenchmark().report();
  }

  @override
  void run() {
    l.string().uuid().validateValue('550e8400-e29b-41d4-a716-446655440000');
  }
}
