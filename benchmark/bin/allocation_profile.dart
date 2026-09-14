import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'continuous_benchmarks.dart' show workloads;

/// External service client: its JSON/HTTP allocations are outside the worker.
Future<void> allocationMain(List<String> args) async {
  final mode = args.contains('aot') ? 'aot' : 'jit';
  final output = File('continuous_allocations_$mode.json');
  final info = File('.dart_tool/continuous_service_$mode.json');
  if (info.existsSync()) info.deleteSync();
  final runtime = args
      .where((s) => s.startsWith('--aot-runtime='))
      .firstOrNull
      ?.split('=')
      .skip(1)
      .join('=');
  final executable = mode == 'aot' && runtime == null
      ? File('.dart_tool/library_comparison.exe').absolute.path
      : runtime ?? Platform.resolvedExecutable;
  final worker = await Process.start(executable, [
    '--enable-vm-service=0',
    '--write-service-info=${info.path}',
    '--profiler',
    if (mode == 'aot' && runtime != null) '.dart_tool/library_comparison.aot',
    if (mode == 'jit') ...['run', 'bin/library_comparison.dart'],
    '--allocation-worker',
  ]);
  final ready = Completer<String?>();
  final errors = StringBuffer();
  final stderrSubscription = worker.stderr
      .transform(utf8.decoder)
      .listen(errors.write);
  final stdoutSubscription = worker.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        if (line.startsWith('{')) {
          final data = jsonDecode(line);
          if (data['ready'] == true && !ready.isCompleted)
            ready.complete(data['isolate'] as String?);
        }
      });
  worker.exitCode.then((code) {
    if (!ready.isCompleted)
      ready.completeError(StateError('Worker exited $code: $errors'));
  });
  final client = HttpClient();
  try {
    final isolate = await ready.future.timeout(const Duration(seconds: 60));
    if (isolate == null || !info.existsSync()) {
      output.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'mode': mode,
          'status': 'unavailable',
          'sdk': Platform.version,
          'reason': 'Worker reported no VM service isolate/counters in this product AOT SDK. A matching non-product runtime can expose heap snapshots, but total allocation still requires an independently verified profiler. RSS is not substituted for allocation.',
          'worker': executable,
        }),
      );
      stdout.writeln(
        'Worker has no allocation counters; recorded unavailable.',
      );
      return;
    }
    final service = Uri.parse(
      (jsonDecode(info.readAsStringSync()) as Map)['uri'] as String,
    );
    Future<Map<String, dynamic>> rpc(
      String method, [
      Map<String, String> params = const {},
    ]) async {
      final request = await client.getUrl(
        service
            .resolve(method)
            .replace(queryParameters: {'isolateId': isolate, ...params}),
      );
      final response = await request.close();
      final body = jsonDecode(
        await utf8.decoder.bind(response).join(),
      ) as Map<String, dynamic>;
      if (body['error'] != null) throw StateError('$method: ${body['error']}');
      return (body['result'] ?? body) as Map<String, dynamic>;
    }

    final cases = workloads();
    final rows = <Map<String, Object?>>[];
    for (var i = 0; i < cases.length; i++) {
      for (final phase in ['construction', 'first', 'warm']) {
        final count = phase == 'first' ? 128 : 1000;
        if (phase == 'first')
          await rpc('ext.acanthis.batch', {
            'case': '$i',
            'count': '$count',
            'phase': 'prepare',
          });
        final before = await rpc('getAllocationProfile', {
          'reset': 'true',
          'gc': 'true',
        });
        await rpc('ext.acanthis.batch', {
          'case': '$i',
          'count': '$count',
          'phase': phase,
        });
        final after = await rpc('getAllocationProfile');
        int sum(Map<String, dynamic> profile, String key) =>
            (profile['members'] as List).fold<int>(
              0,
              (total, row) => total + ((row[key] as num?)?.toInt() ?? 0),
            );
        rows.add({
          'case': cases[i].name,
          'phase': phase,
          'operations': count,
          'heap_bytes_before': sum(before, 'bytesCurrent'),
          'heap_bytes_after': sum(after, 'bytesCurrent'),
          'heap_objects_before': sum(before, 'instancesCurrent'),
          'heap_objects_after': sum(after, 'instancesCurrent'),
          'status': 'heap_census_only',
          'includes': 'worker service-extension dispatch overhead; compare control.loop; client lives in a different process',
        });
      }
      stdout.writeln(
        'Heap census $mode ${i + 1}/${cases.length}: ${cases[i].name}',
      );
    }
    if (args.contains('--profile')) {
      for (final name in [
        'object.specialized.valid',
        'invalid90.nested',
        'issues1000.repeated',
      ]) {
        final i = cases.indexWhere((c) => c.name == name);
        await rpc('clearCpuSamples');
        await rpc('ext.acanthis.batch', {
          'case': '$i',
          'count': name.startsWith('issues')
              ? '1000'
              : name.startsWith('object')
              ? '20000000'
              : '1000000',
        });
        final profile = await rpc('getCpuSamples', {
          'timeOriginMicros': '0',
          'timeExtentMicros': '9000000000000000',
        });
        File('.dart_tool/continuous_profile_$name.json')
            .writeAsStringSync(jsonEncode(profile));
      }
    }
    output.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'mode': mode,
        'sdk': Platform.version,
        'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
        'status': 'allocation_unavailable',
        'reason': 'This SDK implements ClassHeapStats accumulatedSize and instancesAccumulated as heap census values, not cumulative allocation counters. Total bytes/objects allocated cannot be inferred from these snapshots. Allocation totals require an independently verified allocation profiler.',
        'method': 'External worker heap census before (after GC) and after each batch (without forced GC). Intervening GC may reclaim objects; snapshots are neither allocation totals nor per-operation allocation estimates.',
        'rows': rows,
      }),
    );
  } finally {
    client.close(force: true);
    worker.kill();
    await worker.exitCode;
    await stdoutSubscription.cancel();
    await stderrSubscription.cancel();
  }
}
