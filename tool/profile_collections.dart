import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Future<void> main(List<String> args) async {
  final backend = args.first;
  final lazy = args.contains('--lazy');
  final prefix = lazy ? 'lazy-' : '';
  final outputLabel =
      args
          .where((arg) => arg.startsWith('--output-label='))
          .map((arg) => arg.substring('--output-label='.length))
          .firstOrNull ??
      backend;
  final info = File('.dart_tool/profile-$prefix$outputLabel-service.json');
  if (info.existsSync()) info.deleteSync();
  final worker = await Process.start(Platform.resolvedExecutable, [
    '--enable-vm-service=0',
    '--write-service-info=${info.path}',
    '--profiler',
    '--profile-period=100',
    '.dart_tool/object-$prefix$backend.dill',
    '--worker',
  ]);
  final errors = StringBuffer();
  worker.stderr.transform(utf8.decoder).listen(errors.write);
  final lines = StreamIterator(
    worker.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('{')),
  );
  final client = HttpClient();
  try {
    if (!await lines.moveNext()) throw StateError('Worker failed: $errors');
    Map? serviceInfo;
    for (var attempt = 0; serviceInfo == null && attempt < 250; attempt++) {
      if (info.existsSync()) {
        try {
          serviceInfo = jsonDecode(info.readAsStringSync()) as Map;
        } on FormatException {
          /* The VM service can still be publishing it. */
        } on FileSystemException {
          /* Retry a transient Windows sharing lock. */
        }
      }
      if (serviceInfo != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (serviceInfo == null) {
      throw StateError('VM service did not publish its address.');
    }
    final service = Uri.parse(serviceInfo['uri'] as String);
    Future<Map<String, dynamic>> rpc(
      String name, [
      Map<String, String> params = const {},
    ]) async {
      final request = await client.getUrl(
        service.resolve(name).replace(queryParameters: params),
      );
      final response = await request.close();
      final body = jsonDecode(
        await utf8.decoder.bind(response).join(),
      ) as Map<String, dynamic>;
      if (body['error'] != null) throw StateError('$name: ${body['error']}');
      return body['result'] as Map<String, dynamic>;
    }

    final vm = await rpc('getVM');
    final isolate =
        (vm['isolates'] as List).firstWhere(
              (row) => row['name'] == 'main',
            )['id']
            as String;
    Future<void> sample(String name, int ms) async {
      worker.stdin.writeln(
        jsonEncode({'op': 'sample', 'case': name, 'milliseconds': ms}),
      );
      await worker.stdin.flush();
      if (!await lines.moveNext()) throw StateError('Worker failed: $errors');
    }

    Directory('benchmark/object_v2/profiles').createSync(recursive: true);
    File('benchmark/object_v2/profiles/$prefix$outputLabel-metadata.json')
        .writeAsStringSync(
          jsonEncode({
            'sdk': Platform.version,
            'backend': backend,
            'captured_at_utc': DateTime.now().toUtc().toIso8601String(),
            'kernel_sha256': sha256
                .convert(
                  File('.dart_tool/object-$prefix$backend.dill')
                      .readAsBytesSync(),
                )
                .toString(),
            'sample_request_ms': 2000,
            'warmup_ms': 500,
            'allocation_totals': 'not measured',
          }),
        );
    final cases = lazy
        ? ['recursive_24_nodes', 'variant_recursive_24_nodes']
        : [
            'flat_valid',
            'wide_32_valid',
            'nested_valid',
            'construct_and_first_flat',
          ];
    for (final name in cases) {
      await sample(name, 500);
      await rpc('clearCpuSamples', {'isolateId': isolate});
      await sample(name, 2000);
      final profile = await rpc('getCpuSamples', {
        'isolateId': isolate,
        'timeOriginMicros': '0',
        'timeExtentMicros': '9000000000000000',
      });
      File('benchmark/object_v2/profiles/$prefix$outputLabel-$name.json')
          .writeAsStringSync(jsonEncode(profile));
      final functions = (profile['functions'] as List).cast<Map>()
        ..sort(
          (a, b) => (b['exclusiveTicks'] as int).compareTo(
            a['exclusiveTicks'] as int,
          ),
        );
      print('$prefix$backend/$name: ${profile['sampleCount']} samples');
      for (final row in functions.take(8)) {
        print(
          '  ${row['function']['name']}: ${row['exclusiveTicks']} exclusive ticks',
        );
      }
    }
  } finally {
    client.close(force: true);
    worker.stdin.writeln(jsonEncode({'op': 'shutdown'}));
    await worker.stdin.close();
    await worker.exitCode;
    await lines.cancel();
  }
}
