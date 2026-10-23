import 'package:benchmarks/acanthis/object_benchmarks.dart';
import 'package:benchmarks/ack/object_benchmarks.dart';
import 'package:benchmarks/luthor/object_benchmarks.dart';
import 'package:benchmarks/vine/object_benchmarks.dart';

import 'acanthis/string_benchmarks.dart';
import 'luthor/string_benchmarks.dart';
import 'ack/string_benchmarks.dart';

class StringBenchmarks {
  static void main() {
    print("Running Acanthis String benchmarks");
    LongStringValidationBenchmark.main();
    FixedLengthStringValidationBenchmark.main();
    EmptyStringValidationBenchmark.main();
    EmailStringValidationBenchmark.main();
    UuidStringValidationBenchmark.main();
    print("Running Luthor String benchmarks");
    LongLuthorStringValidationBenchmark.main();
    FixedLuthorLengthStringValidationBenchmark.main();
    EmptyLuthorStringValidationBenchmark.main();
    EmailLuthorStringValidationBenchmark.main();
    UuidLuthorStringValidationBenchmark.main();
    print("Running Ack String benchmarks");
    LongStringAckValidationBenchmark.main();
    FixedLengthStringAckValidationBenchmark.main();
    EmptyStringAckValidationBenchmark.main();
    EmailStringAckValidationBenchmark.main();
    print("String benchmarks complete");
  }
}

class ObjectBenchmarks {
  static void main() {
    print("Running Acanthis Object benchmarks");
    NestedObjectValidator.main();
    FlatObjectValidator.main();
    ArrayObjectValidator.main();
    print("Running Luthor Object benchmarks");
    LuthorNestedObjectValidator.main();
    LuthorFlatObjectValidator.main();
    LuthorArrayObjectValidator.main();
    print("Running Ack Object benchmarks");
    NestedObjectAckValidator.main();
    FlatObjectAckValidator.main();
    ArrayObjectAckValidator.main();
    print("Running Vine Object benchmarks");
    VineNestedObjectValidator.main();
    VineFlatObjectValidator.main();
    VineArrayObjectValidator.main();
    print("Object benchmarks complete");
  }
}
