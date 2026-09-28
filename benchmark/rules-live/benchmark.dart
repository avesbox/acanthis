import 'dart:convert';
import 'dart:io';

import 'package:acanthis/acanthis.dart';

// Run from the repository root. Measures schema construction separately from
// reused-schema evaluation; all timings include outcome/delta allocation.
int sink = 0;
AcanthisMap<dynamic> schema({bool async = false}) {
  final left = AcanthisPath(['field0']);
  final right = AcanthisPath(['field1']);
  final fields = <String, AcanthisType>{
    for (var i = 0; i < 24; i++)
      'field$i': async
          ? string()
                .min(2)
                .refineAsync(
                  onCheck: (v) async => v.length < 64,
                  error: 'length',
                  name: 'length',
                )
          : string().min(2).max(64),
  };
  return object(fields).rule(
    AcanthisRule<void>(
      id: 'match',
      inputs: [left, right],
      outputs: [right],
      check: (v, _) => v.value<String>(left) == v.value<String>(right)
          ? []
          : [
              AcanthisIssue(
                path: right.segments,
                code: 'mismatch',
                message: 'Values differ',
              ),
            ],
    ),
  );
}

Map<String, dynamic> input() => {
  for (var i = 0; i < 24; i++) 'field$i': 'initial',
};

Future<void> main(List<String> args) async {
  final n = args.isEmpty ? 10000 : int.parse(args.first);
  final sync = schema();
  final asyncSchema = schema(async: true);
  final raw = input();
  final live = sync.watch(raw);
  final asyncLive = await asyncSchema.watchAsync(raw);
  final probe = live.set('field0', 'changed');
  if (probe.executedFields.length != 1 ||
      probe.executedRules.length != 1 ||
      probe.issues.length !=
          (sync.tryParse(live.input) as AcanthisInvalid).issues.length) {
    throw StateError('Scheduling preflight failed');
  }
  final results = <String, Object?>{};
  Future<void> measure(String name, Future<void> Function(int) action) async {
    await action(n ~/ 5);
    final samples = <double>[];
    for (var sample = 0; sample < 7; sample++) {
      final watch = Stopwatch()..start();
      await action(n);
      watch.stop();
      samples.add(watch.elapsedMicroseconds / n);
    }
    final sorted = [...samples]..sort();
    results[name] = {'median_us': sorted[3], 'samples_us': samples};
  }

  await measure('construct', (count) async {
    for (var i = 0; i < count; i++) {
      sink += schema().fields.length;
    }
  });
  await measure('sync_full', (count) async {
    for (var i = 0; i < count; i++) {
      raw['field0'] = i.isEven ? 'initial' : 'changed';
      sink += sync.tryParse(raw).value.length;
    }
  });
  await measure('sync_live', (count) async {
    for (var i = 0; i < count; i++) {
      sink += live
          .set('field0', i.isEven ? 'initial' : 'changed')
          .executedFields
          .length;
    }
  });
  await measure('async_full', (count) async {
    for (var i = 0; i < count; i++) {
      raw['field0'] = i.isEven ? 'initial' : 'changed';
      sink += (await asyncSchema.tryParseAsync(raw)).value.length;
    }
  });
  await measure('async_live', (count) async {
    for (var i = 0; i < count; i++) {
      sink += (await asyncLive.set(
        'field0',
        i.isEven ? 'initial' : 'changed',
      )).executedFields.length;
    }
  });
  final output = {
    'dart': Platform.version,
    'os': Platform.operatingSystem,
    'processors': Platform.numberOfProcessors,
    'iterations': n,
    'samples': 7,
    'field_count': 24,
    'live_fields_per_edit': probe.executedFields.length,
    'live_rules_per_edit': probe.executedRules.length,
    'results': results,
    'sink': sink,
  };
  final json = const JsonEncoder.withIndent('  ').convert(output);
  if (args.length > 1) File(args[1]).writeAsStringSync('$json\n');
  print(json);
}
