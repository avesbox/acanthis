import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:acanthis/acanthis.dart';
import 'package:luthor/luthor.dart';
import 'package:vine/vine.dart';

import 'analysis_benchmarks.dart' as timing;
import 'continuous_benchmarks.dart' as continuous;

Future<void> main(List<String> args) async {
  if (args.contains('--extended') ||
      args.contains('--allocation-worker') ||
      args.contains('--allocations')) {
    await continuous.main(args);
    return;
  }
  final mode = args.isEmpty ? 'jit' : args.single;
  final cases = <String, Object? Function()>{};
  final preflight = <String>[];

  void add(
    String name,
    AcanthisMap a,
    Object? Function(Map<String, dynamic>) lValidate,
    bool Function(Map<String, dynamic>) lAccepts,
    Object? Function(Map<String, dynamic>) vValidate,
    Map<String, dynamic> payload,
    Map<String, dynamic> invalid,
  ) {
    final original = jsonEncode(payload);
    if (!a.tryParse(payload).success || !lAccepts(payload)) {
      throw StateError('$name: a library rejected the valid payload');
    }
    a.parse(payload);
    vValidate(payload);
    if (mode == 'verify' &&
        (a.tryParse(invalid).success || lAccepts(invalid))) {
      throw StateError('$name: a library accepted the invalid payload');
    }
    if (mode == 'verify') {
      var vineRejected = false;
      try {
        vValidate(invalid);
      } catch (_) {
        vineRejected = true;
      }
      if (!vineRejected) throw StateError('$name: Vine accepted invalid input');
    }
    if (original != jsonEncode(payload)) {
      throw StateError('$name: validation mutated the valid payload');
    }
    preflight.add(name);
    cases['$name.acanthis.parse'] = () => a.parse(payload);
    cases['$name.acanthis.tryParse'] = () => a.tryParse(payload);
    cases['$name.luthor.validateSchema'] = () => lValidate(payload);
    cases['$name.vine.validate'] = () => vValidate(payload);
  }

  void addString(
    String name,
    AcanthisType aString,
    dynamic lString,
    dynamic vString,
    String value,
    dynamic bad,
  ) {
    final a = object({'value': aString});
    final ls = l.schema({'value': lString});
    final vs = vine.compile(vine.object({'value': vString}));
    add(
      name,
      a,
      ls.validateSchema,
      (v) => ls.validateSchema(v).isValid,
      vs.validate,
      {'value': value},
      {'value': bad},
    );
  }

  addString(
    'string.long',
    string(),
    l.string(),
    vine.string(),
    'long' * 256,
    42,
  );
  addString('string.empty', string(), l.string(), vine.string(), '', 42);
  addString(
    'string.bounded',
    string().min(1).max(5),
    l.string().min(1).max(5),
    vine.string().minLength(1).maxLength(5),
    'long',
    'too long',
  );
  addString(
    'string.email',
    string().email(),
    l.string().email(),
    vine.string().email(),
    'email@example.com',
    'invalid',
  );
  addString(
    'string.uuid',
    string().uuid(),
    l.string().uuid(),
    vine.string().uuid(),
    '550e8400-e29b-41d4-a716-446655440000',
    'invalid',
  );

  final aFlat = object({'firstname': string(), 'lastname': string()});
  final lFlat = l.schema({'firstname': l.string(), 'lastname': l.string()});
  final vFlat = vine.compile(
    vine.object({'firstname': vine.string(), 'lastname': vine.string()}),
  );
  add(
    'object.flat',
    aFlat,
    lFlat.validateSchema,
    (v) => lFlat.validateSchema(v).isValid,
    vFlat.validate,
    {'firstname': 'John', 'lastname': 'Doe'},
    {'firstname': 42, 'lastname': 'Doe'},
  );

  final aNested = object({
    'username': string(),
    'password': string(),
    'contact': object({'name': string(), 'address': string()}),
  });
  final lNested = l.schema({
    'username': l.string(),
    'password': l.string(),
    'contact': l.schema({'name': l.string(), 'address': l.string()}),
  });
  final vNested = vine.compile(
    vine.object({
      'username': vine.string(),
      'password': vine.string(),
      'contact': vine.object({'name': vine.string(), 'address': vine.string()}),
    }),
  );
  add(
    'object.nested',
    aNested,
    lNested.validateSchema,
    (v) => lNested.validateSchema(v).isValid,
    vNested.validate,
    {
      'username': 'John Doe',
      'password': 'secret',
      'contact': {'name': 'John Doe', 'address': '123 Main St'},
    },
    {
      'username': 'John Doe',
      'password': 'secret',
      'contact': {'name': 42, 'address': '123 Main St'},
    },
  );

  final aArray = object({
    'contacts': object({'type': string(), 'value': string()}).list(),
  });
  final lArray = l.schema({
    'contacts': l.list(
      validators: [
        l.schema({'type': l.string(), 'value': l.string()}),
      ],
    ),
  });
  final vArray = vine.compile(
    vine.object({
      'contacts': vine.array(
        vine.object({'type': vine.string(), 'value': vine.string()}),
      ),
    }),
  );
  add(
    'object.array',
    aArray,
    lArray.validateSchema,
    (v) => lArray.validateSchema(v).isValid,
    vArray.validate,
    {
      'contacts': [
        {'type': 'email', 'value': 'foo@bar.com'},
        {'type': 'phone', 'value': '12345678'},
      ],
    },
    {
      'contacts': [
        {'type': 'email', 'value': 42},
      ],
    },
  );

  final aList = object({'items': string().min(1).list()});
  final lList = l.schema({
    'items': l.list(validators: [l.string().min(1)]),
  });
  final vList = vine.compile(
    vine.object({'items': vine.array(vine.string().minLength(1))}),
  );
  add(
    'list100',
    aList,
    lList.validateSchema,
    (v) => lList.validateSchema(v).isValid,
    vList.validate,
    {'items': List.generate(100, (i) => 'item$i')},
    {
      'items': ['ok', ''],
    },
  );

  print('Preflight passed for ${preflight.length} workloads. Starting $mode.');
  // Vine 1.8.0 retains failure diagnostics on its compiled validator. Verify
  // invalid inputs in a separate process so timing starts with fresh schemas.
  if (mode == 'verify') return;
  final samples = {for (final key in cases.keys) key: <double>[]};
  for (final run in cases.values) {
    timing.measure(run, 150);
  }
  final random = Random(42);
  for (var round = 0; round < 5; round++) {
    final order = cases.keys.toList()..shuffle(random);
    for (final name in order) {
      samples[name]!.add(timing.measure(cases[name]!, 150));
    }
    print('Completed round ${round + 1}/5');
  }
  final rows = [
    for (final entry in samples.entries)
      (() {
        final sorted = [...entry.value]..sort();
        print('${entry.key}: ${sorted[2].toStringAsFixed(1)} ns/op');
        return {
          'case': entry.key,
          'median_ns': sorted[2],
          'min_ns': sorted.first,
          'max_ns': sorted.last,
          'samples_ns': entry.value,
        };
      })(),
  ];
  File('library_comparison_$mode.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'sdk': Platform.version,
      'os': Platform.operatingSystem,
      'processors': Platform.numberOfProcessors,
      'mode': mode,
      'libraries': {
        'acanthis': 'workspace',
        'luthor': '0.17.0',
        'vine': '1.8.0',
      },
      'warmup_ms_per_case': 150,
      'sample_ms': 150,
      'rounds': 5,
      'schema_setup': 'cached outside timing',
      'payload_setup':
          'cached outside timing; strings and lists wrapped in objects',
      'preflight_passed': preflight,
      'rows': rows,
    }),
  );
  print('Consumed final result: ${timing.sink.runtimeType}');
}
