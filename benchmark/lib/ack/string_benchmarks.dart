import 'package:ack/ack.dart';

import '../shared/acanthis_benchmark.dart';
import '../shared/payloads.dart';


class LongStringAckValidationBenchmark extends AcanthisBenchmark {
  LongStringAckValidationBenchmark()
    : super(name: 'LongStringAckValidationBenchmark');

  static void main() {
    LongStringAckValidationBenchmark().report();
  }

  final validator = Ack.string();

  @override
  void run() {
    validator.parse(Payloads.longStringPayload);
  }
}

class FixedLengthStringAckValidationBenchmark extends AcanthisBenchmark {
  FixedLengthStringAckValidationBenchmark()
    : super(name: 'FixedLengthStringAckValidationBenchmark');

  static void main() {
    FixedLengthStringAckValidationBenchmark().report();
  }

  final validator = Ack.string().maxLength(5).minLength(1);

  @override
  void run() {
    validator.parse(Payloads.fixedLengthStringPayload);
  }
}

class EmptyStringAckValidationBenchmark extends AcanthisBenchmark {
  EmptyStringAckValidationBenchmark()
    : super(name: 'EmptyStringAckValidationBenchmark');

  static void main() {
    EmptyStringAckValidationBenchmark().report();
  }

  final validator = Ack.string();

  @override
  void run() {
    validator.parse(Payloads.emptyStringPayload);
  }
}

class EmailStringAckValidationBenchmark extends AcanthisBenchmark {
  EmailStringAckValidationBenchmark()
    : super(name: 'EmailStringAckValidationBenchmark');

  static void main() {
    EmailStringAckValidationBenchmark().report();
  }

  final validator = Ack.string().email();

  @override
  void run() {
    validator.parse(Payloads.emailStringPayload);
  }
}

class UuidStringAckValidationBenchmark extends AcanthisBenchmark {
  UuidStringAckValidationBenchmark()
    : super(name: 'UuidStringAckValidationBenchmark');

  static void main() {
    UuidStringAckValidationBenchmark().report();
  }

  @override
  void run() {
    throw UnimplementedError('Ack does not support UUID validation');
  }
}
