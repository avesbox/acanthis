import 'package:benchmark_harness/perf_benchmark_harness.dart';

class AcanthisBenchmark extends PerfBenchmarkBase {
  final int iterations;

  AcanthisBenchmark({String name = 'AcanthisBenchmark', this.iterations = 100})
    : super(name, emitter: PrintEmitterV2());

  @override
  void warmpup() {
    // Warm up the benchmark by running it a few times before measuring.
    for (var i = 0; i < 10; i++) {
      try {
        run();
      } catch (_) {
      }
    }
  }

  @override
  void exercise() {
    for (var i = 0; i < iterations; i++) {
      try {
        run();
      } catch (_) {
      }
    }
  }

  @override
  void run() {
    try {
      super.run();
    } catch (e) {
      print('Error in benchmark $name: $e');
    }
  }
}
