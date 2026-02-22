import 'package:benchmark_harness/perf_benchmark_harness.dart';

class AcanthisBenchmark extends PerfBenchmarkBase {
  final int iterations;

  AcanthisBenchmark({String name = 'AcanthisBenchmark', this.iterations = 100})
    : super(name, emitter: PrintEmitterV2());

  @override
  void exercise() {
    for (var i = 0; i < iterations; i++) {
      run();
    }
  }
}
