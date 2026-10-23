@Tags(['memory'])
library;

import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';

import 'package:acanthis_analyzer_plugin/src/rules.dart';
import 'package:test/test.dart';
import 'package:vm_service/vm_service_io.dart';

import 'support/harness.dart';

void main() {
  test(
    '1000 resolved units plateau after request/context disposal',
    () async {
      final info = await developer.Service.getInfo();
      final uri = info.serverUri;
      expect(
        uri,
        isNotNull,
        reason: 'Run with dart --enable-vm-service=0 test ...',
      );
      final service = await vmServiceConnectUri(
        uri!.replace(scheme: 'ws', path: '${uri.path}ws').toString(),
      );
      final isolate = developer.Service.getIsolateId(Isolate.current)!;
      // Keep one rule alive throughout: request registries and contexts must die.
      final rule = AcanthisRules();
      final heap = <int>[];
      final rss = <int>[];
      try {
        for (var batch = 0; batch < 10; batch++) {
          await _batch(rule, batch);
          final profile = await service.getAllocationProfile(isolate, gc: true);
          heap.add(
            profile.memoryUsage!.heapUsage! +
                profile.memoryUsage!.externalUsage!,
          );
          rss.add(ProcessInfo.currentRss);
          print(
            'units=${(batch + 1) * 100} postGcHeap=${heap.last} rss=${rss.last}',
          );
        }
        // Allow VM/JIT/allocator warmup. Compare late post-GC samples, not peaks.
        const mib = 1024 * 1024;
        expect(heap.last - heap[4], lessThan(24 * mib));
        expect(rss.last - rss[4], lessThan(128 * mib));
        for (var i = 5; i < heap.length; i++) {
          expect(heap[i] - heap[4], lessThan(32 * mib));
        }
      } finally {
        await service.dispose();
      }
    },
    skip: Platform.environment['RUN_MEMORY_BENCHMARK'] != '1',
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

Future<void> _batch(AcanthisRules rule, int batch) async {
  final harness = Harness.create();
  try {
    for (var i = 0; i < 100; i++) {
      final iteration = batch * 100 + i;
      final path = harness.write('unit_$iteration', stressSource(iteration));
      final result = await harness.resolve(path);
      expect(runRules(result, rule), hasLength(3));
    }
  } finally {
    await harness.dispose();
  }
}
