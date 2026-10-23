import 'package:benchmarks/shared/acanthis_benchmark.dart';
import 'package:ack/ack.dart';
import 'package:benchmarks/shared/payloads.dart';

class NestedObjectAckValidator extends AcanthisBenchmark {
  NestedObjectAckValidator() : super(name: 'NestedObjectAckValidator');

  static void main() {
    NestedObjectAckValidator().report();
  }

  final validator = Ack.object({
    'username': Ack.string(),
    'password': Ack.string(),
    'contact': Ack.object({'name': Ack.string(), 'address': Ack.string().nullable()}),
  });

  @override
  void run() {
    validator.parse(Payloads.nestedObjectPayload);
  }
}

class FlatObjectAckValidator extends AcanthisBenchmark {
  FlatObjectAckValidator() : super(name: 'FlatObjectAckValidator');

  static void main() {
    FlatObjectAckValidator().report();
  }

  final validator = Ack.object({'firstname': Ack.string(), 'lastname': Ack.string()});

  @override
  void run() {
    validator.parse(Payloads.flatObjectPayload);
  }
}

class ArrayObjectAckValidator extends AcanthisBenchmark {
  ArrayObjectAckValidator() : super(name: 'ArrayObjectAckValidator');

  static void main() {
    ArrayObjectAckValidator().report();
  }

  final validator = Ack.object({
    'contacts': Ack.list(Ack.object({'type': Ack.string(), 'value': Ack.string()})),
  });

  @override
  void run() {
    validator.parse(Payloads.objectArrayPayload);
  }
}
