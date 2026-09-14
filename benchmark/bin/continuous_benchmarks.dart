import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:acanthis/acanthis.dart';

import 'allocation_profile.dart';

Object? sink;

class Workload {
  Workload(
    this.name,
    this.build,
    this.run, {
    this.async = false,
    this.policy = 'collect all',
  });
  final String name;
  int cursor = 0;
  final Object Function() build;
  final Object? Function(Object schema, int index) run;
  final bool async;
  final String policy;
}

List<Workload> workloads() {
  final valid = <String, dynamic>{
    'account': <String, dynamic>{'email': 'ok@example.com', 'name': 'Ada'},
  };
  final invalid = <String, dynamic>{
    'account': <String, dynamic>{'email': 'bad', 'name': ''},
  };
  AcanthisMap account() => object({
    'account': object({'email': string().email(), 'name': string().min(2)}),
  });
  final result = <Workload>[
    Workload(
      'control.loop',
      () => Object(),
      (s, i) => s,
      policy: 'empty harness control',
    ),
    Workload(
      'object.specialized.valid',
      () => object({
        'account': object({'email': string(), 'name': string()}),
      }),
      (s, i) => (s as AcanthisType).tryParse(valid),
    ),
    Workload(
      'invalid90.nested',
      account,
      (s, i) => (s as AcanthisType).tryParse(i % 10 == 0 ? valid : invalid),
    ),
    Workload(
      'invalid90.issues.json',
      account,
      (s, i) => (s as AcanthisType)
          .tryParse(i % 10 == 0 ? valid : invalid)
          .issues
          .formatJson(),
    ),
  ];
  for (final size in [100, 1000]) {
    final input = List<String>.filled(size, 'bad');
    result.add(
      Workload(
        'issues$size.repeated',
        () => string().email().email().email().list(),
        (s, i) => (s as AcanthisType).tryParse(input),
      ),
    );
  }
  for (final size in [16, 128]) {
    Object build() =>
        union<String>(List.generate(size, (i) => literal('branch$i')));
    result.add(
      Workload(
        'union$size.invalid',
        build,
        (s, i) => (s as AcanthisType).tryParse('invalid'),
      ),
    );
    result.add(
      Workload(
        'union$size.last',
        build,
        (s, i) => (s as AcanthisType).tryParse('branch${size - 1}'),
      ),
    );
  }
  final transformInput = <String, dynamic>{
    'a/b': List<String>.filled(100, '  ada  '),
    '~.0': '  email@example.com  ',
    'strip': true,
  };
  result.add(
    Workload(
      'transformed100.output',
      () => object({
        'a/b': string().transform((s) => s.trim().toUpperCase()).list(),
        '~.0': string().transform((s) => s.trim()),
      }),
      (s, i) => (s as AcanthisType).tryParse(transformInput),
    ),
  );
  final initial = <String, dynamic>{
    for (var i = 0; i < 50; i++) 'field$i': 'ok@example.com',
  };
  AcanthisMap form() => object({
    for (var i = 0; i < 50; i++) 'field$i': string().email().email(),
  });
  result.add(
    Workload(
      'live50.independent',
      () => form().watch(initial),
      (s, i) => (s as AcanthisLiveSession).set(
        'field${i % 50}',
        ((i ~/ 50) + i).isEven ? 'bad' : 'ok@example.com',
      ),
      policy: 'session setup includes initial validation; update collects changed issues',
    ),
  );
  result.add(
    Workload('live50.full', () => (form(), Map<String, dynamic>.of(initial)), (
      s,
      i,
    ) {
      final (schema, input) = s as (AcanthisMap, Map<String, dynamic>);
      input['field${i % 50}'] = ((i ~/ 50) + i).isEven
          ? 'bad'
          : 'ok@example.com';
      return schema.tryParse(input);
    }, policy: 'full parse after same field assignment; no delta calculation'),
  );
  for (final scheduling in ['completed', 'microtask', 'event']) {
    Future<bool> callback(String value) => switch (scheduling) {
      'completed' => Future.value(value.length >= 2),
      'microtask' => Future.microtask(() => value.length >= 2),
      _ => Future.delayed(Duration.zero, () => value.length >= 2),
    };
    result.add(
      Workload(
        'async8.$scheduling',
        () {
          AcanthisType<String> schema = string();
          for (var i = 0; i < 8; i++) {
            schema = schema.refineAsync(
              onCheck: callback,
              name: 'length',
              error: 'Too short',
            );
          }
          return schema;
        },
        (s, i) => (s as AcanthisType).tryParseAsync(i % 10 == 0 ? 'ok' : 'x'),
        async: true,
        policy: '8 sequential controlled callbacks; 90% invalid; no network',
      ),
    );
    result.add(
      Workload(
        'control.async8.$scheduling',
        () => Object(),
        (s, i) async {
          for (var n = 0; n < 8; n++) {
            sink = await callback(i % 10 == 0 ? 'ok' : 'x');
          }
          return sink;
        },
        async: true,
        policy: 'callback scheduling control without validation',
      ),
    );
  }
  return result;
}

Future<void> batch(Workload work, Object schema, int count) async {
  if (work.async) {
    for (var i = 0; i < count; i++) {
      sink = await work.run(schema, work.cursor++);
    }
  } else {
    for (var i = 0; i < count; i++) {
      sink = work.run(schema, work.cursor++);
    }
  }
}

Future<double> measure(Workload work, Object schema, int ms) async {
  final clock = Stopwatch()..start();
  var count = 0;
  do {
    await batch(work, schema, 10);
    count += 10;
  } while (clock.elapsedMilliseconds < ms);
  return clock.elapsedTicks * 1e9 / clock.frequency / count;
}

Map<String, Object?> stats(List<double> samples) {
  final sorted = [...samples]..sort();
  return {
    'median_ns': sorted[sorted.length ~/ 2],
    'min_ns': sorted.first,
    'max_ns': sorted.last,
    'samples_ns': samples,
  };
}

Future<void> preflight() async {
  final schema = object({'email': string().email().email()});
  final session = schema.watch({'email': 'ok@example.com'});
  final asyncSession = await schema.watchAsync({'email': 'ok@example.com'});
  for (var i = 0; i < 100; i++) {
    final input = <String, dynamic>{
      'email': i % 10 == 0 ? 'ok@example.com' : 'bad',
    };
    final before = jsonEncode(input);
    final full = schema.tryParse(input);
    session.set('email', input['email']);
    await asyncSession.set('email', input['email']);
    if (full.issues.formatJson() != session.issues.formatJson() ||
        full.issues.formatJson() != asyncSession.issues.formatJson() ||
        before != jsonEncode(input)) {
      throw StateError('Live/input preflight failed at $i');
    }
  }
  for (final work in workloads()) {
    final schema = work.build();
    for (final index in [0, 1, 10, 11]) {
      final result = work.async
          ? await work.run(schema, index)
          : work.run(schema, index);
      if (result is AcanthisParseResult) {
        if (work.name.startsWith('issues')) {
          final size = int.parse(
            RegExp(r'issues(\d+)').firstMatch(work.name)![1]!,
          );
          if (result.issues.length != size * 3)
            throw StateError('Lost duplicate issues: ${work.name}');
        }
        if (work.name.contains('.invalid') && result.success)
          throw StateError('Accepted invalid union');
        if (work.name.endsWith('.last') && !result.success)
          throw StateError('Rejected last union branch');
        if (work.name.startsWith('transformed') &&
            (!result.success || (result.value as Map)['a/b'][0] != 'ADA'))
          throw StateError('Wrong transformed output');
      }
    }
  }
}

Future<void> main(List<String> args) async {
  if (args.contains('--allocation-worker')) {
    final cases = workloads();
    final schemas = [for (final work in cases) work.build()];
    for (var i = 0; i < cases.length; i++) {
      await batch(cases[i], schemas[i], 100);
    }
    var fresh = <Object>[];
    developer.registerExtension('ext.acanthis.batch', (method, params) async {
      final index = int.parse(params['case']!);
      final count = int.parse(params['count']!);
      final phase = params['phase'] ?? 'warm';
      if (phase == 'prepare') {
        fresh = List.generate(count, (_) => cases[index].build());
      } else if (phase == 'first') {
        for (var n = 0; n < count; n++) {
          sink = cases[index].async
              ? await cases[index].run(fresh[n], n)
              : cases[index].run(fresh[n], n);
        }
      } else if (phase == 'construction') {
        for (var n = 0; n < count; n++) {
          sink = cases[index].build();
        }
      } else {
        await batch(cases[index], schemas[index], count);
      }
      return developer.ServiceExtensionResponse.result(
        jsonEncode({'done': count}),
      );
    });
    stdout.writeln(
      jsonEncode({
        'ready': true,
        'isolate': developer.Service.getIsolateId(Isolate.current),
      }),
    );
    ReceivePort().listen((_) {});
    await Completer<void>().future;
    return;
  }
  if (args.contains('--allocations')) {
    await allocationMain(args);
    return;
  }
  final mode = args.contains('aot') ? 'aot' : 'jit';
  final quick = args.contains('--quick');
  final rounds = quick ? 3 : 5;
  final ms = quick ? 25 : 100;
  final firstCount = quick ? 16 : 128;
  final cases = workloads();
  final rows = <Map<String, Object?>>[];
  // Process-first observations precede preflight; do not mix them with warm data.
  final cached = <Object>[];
  for (final work in cases) {
    final buildClock = Stopwatch()..start();
    final schema = work.build();
    buildClock.stop();
    final firstClock = Stopwatch()..start();
    sink = work.async ? await work.run(schema, 1) : work.run(schema, 1);
    firstClock.stop();
    cached.add(schema);
    rows.add({
      'case': work.name,
      'policy': work.policy,
      'process_first_construction_ns':
          buildClock.elapsedTicks * 1e9 / buildClock.frequency,
      'process_first_validation_ns':
          firstClock.elapsedTicks * 1e9 / firstClock.frequency,
    });
  }
  await preflight();
  final warm = [for (final _ in cases) <double>[]];
  final build = [for (final _ in cases) <double>[]];
  final first = [for (final _ in cases) <double>[]];
  for (var i = 0; i < cases.length; i++) {
    await measure(cases[i], cached[i], ms);
  }
  final random = Random(42);
  for (var round = 0; round < rounds; round++) {
    final order = List.generate(cases.length, (i) => i)..shuffle(random);
    for (final i in order) {
      final work = cases[i];
      // Fresh-schema first validation: all construction is outside its clock.
      final fresh = List.generate(firstCount, (_) => work.build());
      final watch = Stopwatch()..start();
      for (var n = 0; n < fresh.length; n++) {
        sink = work.async ? await work.run(fresh[n], n) : work.run(fresh[n], n);
      }
      watch.stop();
      first[i].add(watch.elapsedTicks * 1e9 / watch.frequency / firstCount);
      final construction = Workload(
        'build',
        () => Object(),
        (_, _) => work.build(),
      );
      build[i].add(await measure(construction, cached[i], ms));
      warm[i].add(await measure(work, cached[i], ms));
    }
    stdout.writeln('Extended $mode round ${round + 1}/$rounds');
  }
  for (var i = 0; i < rows.length; i++) {
    rows[i].addAll({
      'construction': stats(build[i]),
      'fresh_schema_first_validation': stats(first[i]),
      'warm_validation': stats(warm[i]),
    });
  }
  final file = File('continuous_$mode.json');
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'sdk': Platform.version,
      'mode': mode,
      'executable': Platform.resolvedExecutable,
      'os': Platform.operatingSystem,
      'processors': Platform.numberOfProcessors,
      'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
      'rounds': rounds,
      'sample_ms': ms,
      'fresh_schemas_per_sample': firstCount,
      'order_seed': 42,
      'allocation':
          'separate --allocations process; not inferred from RSS or timing',
      'preflight': 'passed',
      'rows': rows,
    }),
  );
  stdout.writeln('Wrote ${file.path}; sink=${sink.runtimeType}');
}
