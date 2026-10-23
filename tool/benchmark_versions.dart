import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:acanthis/acanthis.dart';
import 'package:crypto/crypto.dart';

Object? sink;
final cases = <String, Object? Function()>{};
final signatures = <String, Object?>{};

final class User {
  User(this.age);
  final int age;
}

Object? canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: canonical(value[key])};
  }
  if (value is List) return value.map(canonical).toList();
  return value;
}

void add(
  String name,
  Object? Function() run, {
  Object? Function(Object?)? signature,
}) {
  cases[name] = run;
  signatures[name] = canonical(signature == null ? run() : signature(run()));
}

Object diagnostics(Object? result) {
  final outcome = result as dynamic;
  return {
    'valid': outcome.isValid,
    'issues': [
      for (final issue in outcome.issues) [issue.path, issue.code],
    ],
    if (outcome.isValid) 'value': outcome.value,
  };
}

void workloads() {
  final bounded = string().min(1).max(20);
  add('string.parse', () => bounded.parse('Ada'));
  add('string.buildAndParse', () => string().min(1).max(20).parse('Ada'));
  add('string.invalid', () => bounded.tryParse(''), signature: diagnostics);
  final age = integer().gte(18).lte(80);
  add('integer.parse', () => age.parse(42));
  final flag = boolean().isTrue();
  add('boolean.parse', () => flag.parse(true));
  final maybe = string().nullable();
  add('nullable.parse', () => maybe.parse(null));

  final flatInput = <String, dynamic>{'name': 'Ada', 'city': 'Rome'};
  final flat = object({'name': string(), 'city': string()});
  final wideInput = <String, dynamic>{
    for (var i = 0; i < 32; i++) 'f$i': 'Ada',
  };
  final wide = object({for (var i = 0; i < 32; i++) 'f$i': string()});
  final nestedInput = <String, dynamic>{'account': flatInput, 'age': 42};
  final nested = object({'account': flat, 'age': integer()});
  final contactsInput = <String, dynamic>{
    'contacts': List.generate(
      100,
      (_) => <String, dynamic>{'name': 'Ada', 'city': 'Rome'},
    ),
  };
  final contacts = object({'contacts': flat.list()});
  final transformedInput = <String, dynamic>{'name': ' Ada ', 'city': ' Rome '};
  final transformed = object({
    'name': string().transform((s) => s.trim()),
    'city': string().transform((s) => s.trim()),
  });
  // Inferred closures keep static dispatch identical across the two public APIs.
  add(
    'object.flat.build',
    () => object({'name': string(), 'city': string()}),
    signature: (_) => true,
  );
  add(
    'object.flat.buildAndParse',
    () => object({'name': string(), 'city': string()}).parse(flatInput),
  );
  add('object.flat.parse', () => flat.parse(flatInput));
  add(
    'object.flat.tryParse',
    () => flat.tryParse(flatInput),
    signature: diagnostics,
  );
  add(
    'object.flat.invalid',
    () => flat.tryParse({'name': 42, 'city': 'Rome'}),
    signature: diagnostics,
  );
  add('object.wide32.parse', () => wide.parse(wideInput));
  add(
    'object.wide32.tryParse',
    () => wide.tryParse(wideInput),
    signature: diagnostics,
  );
  add('object.nested.parse', () => nested.parse(nestedInput));
  add(
    'object.nested.tryParse',
    () => nested.tryParse(nestedInput),
    signature: diagnostics,
  );
  add(
    'object.nested.invalid',
    () => nested.tryParse({
      'account': {'name': 42, 'city': false},
      'age': 'bad',
    }),
    signature: diagnostics,
  );
  add('object.contacts100.parse', () => contacts.parse(contactsInput));
  add(
    'object.contacts100.tryParse',
    () => contacts.tryParse(contactsInput),
    signature: diagnostics,
  );
  add('object.strip.parse', () => flat.parse({...flatInput, 'extra': true}));
  add('object.transformed.parse', () => transformed.parse(transformedInput));
  final items = string().min(1).list();
  final validItems = List.filled(100, 'Ada');
  final invalidItems = List.generate(100, (i) => i.isEven ? '' : 'Ada');
  add('list100.parse', () => items.parse(validItems));
  add(
    'list100.halfInvalid',
    () => items.tryParse(invalidItems),
    signature: diagnostics,
  );

  final tree = object({
    'name': string(),
    'children': LazyEntry((parent) => parent.list()),
  });
  Map<String, dynamic> node(int depth) => {
    'name': 'Ada',
    'children': depth == 0
        ? <Map<String, dynamic>>[]
        : [node(depth - 1), node(depth - 1)],
  };
  final treeInput = node(3);
  add('lazy.tree15.parse', () => tree.parse(treeInput));
  add(
    'lazy.tree15.tryParse',
    () => tree.tryParse(treeInput),
    signature: diagnostics,
  );
  final pipeline = string().pipe(integer().gte(18), transform: int.parse);
  add('pipeline.parse', () => pipeline.parse('42'));
  add(
    'pipeline.tryParse',
    () => pipeline.tryParse('42'),
    signature: diagnostics,
  );
  final user = classSchema<int, User>()
      .input(integer().gte(18).lte(80))
      .map(User.new)
      .validateWith(
        instance<User>().field('age', (u) => u.age, integer().gte(18)),
      )
      .build();
  add('class.parse', () => user.parse(42), signature: (u) => (u as User).age);
  add(
    'class.mock',
    () => user.mock(42),
    signature: (u) {
      final age = (u as User).age;
      if (age < 18 || age > 80) throw StateError('Invalid class mock');
      return true;
    },
  );
  add(
    'mockSeeded.integer',
    () => age.mockSeeded(seed: 42),
    signature: (v) {
      if (v is! int || v < 18 || v > 80) {
        throw StateError('Invalid seeded mock');
      }
      return true;
    },
  );
  final exportable = object({'account': flat, 'name': string()});
  add(
    'export.json.nested',
    () => exportable.exportJsonSchema(mode: AcanthisSchemaMode.input),
  );
  add(
    'export.openapi.nested',
    () => exportable.exportOpenApiSchema(mode: AcanthisSchemaMode.input),
  );
  add(
    'export.pretty.nested',
    () => exportable.toPrettyJsonSchema(),
    signature: (schema) => (jsonDecode(schema as String) as Map)['type'],
  );
  if (signatures['string.parse'] != 'Ada' ||
      signatures['integer.parse'] != 42 ||
      signatures['pipeline.parse'] != 42 ||
      (signatures['export.json.nested'] as Map)['type'] != 'object' ||
      jsonEncode(signatures['object.transformed.parse']) !=
          jsonEncode(canonical(flatInput))) {
    throw StateError('Workload correctness gate failed');
  }
}

double measure(Object? Function() run, int milliseconds) {
  final watch = Stopwatch()..start();
  var count = 0;
  do {
    for (var i = 0; i < 100; i++) {
      sink = run();
    }
    count += 100;
  } while (watch.elapsedMilliseconds < milliseconds);
  return watch.elapsedTicks * 1e9 / watch.frequency / count;
}

Future<void> command(String executable, List<String> args) async {
  final process = await Process.start(executable, args);
  await Future.wait([
    stdout.addStream(process.stdout),
    stderr.addStream(process.stderr),
  ]);
  final code = await process.exitCode;
  if (code != 0) throw StateError('$executable failed: $code');
}

Map<String, String> hashes() {
  final files = [
    for (final root in ['lib', 'v1/lib'])
      ...Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
    File('tool/benchmark_versions.dart'),
    File('pubspec.lock'),
  ]..sort((a, b) => a.path.compareTo(b.path));
  return {
    for (final f in files)
      f.path.replaceAll('\\', '/'): sha256
          .convert(f.readAsBytesSync())
          .toString(),
  };
}

Future<void> main(List<String> args) async {
  if (args.firstOrNull == '--worker') {
    workloads();
    if (args.contains('--verify')) {
      print(jsonEncode(signatures));
      return;
    }
    final samples = {for (final name in cases.keys) name: <double>[]};
    for (final run in cases.values) {
      measure(run, 200);
    }
    final random = Random(42);
    for (var round = 0; round < 5; round++) {
      final order = cases.keys.toList()..shuffle(random);
      for (final name in order) {
        samples[name]!.add(measure(cases[name]!, 100));
      }
    }
    File(args[1]).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'sdk': Platform.version, 'os': Platform.operatingSystem, 'processor': Platform.environment['PROCESSOR_IDENTIFIER'], 'warmup_ms': 200, 'sample_ms': 100, 'rounds': 5, 'signatures': signatures, 'samples_ns': samples, 'sink_type': sink.runtimeType.toString()})}\n',
    );
    print('Saved ${cases.length} cases to ${args[1]}');
    return;
  }
  final output = args.firstOrNull ?? 'benchmark/version-comparison/2026-10-23';
  final before = args
      .where((arg) => arg.startsWith('--before='))
      .map((arg) => arg.substring('--before='.length))
      .firstOrNull;
  final backends = ['v1', if (before != null) 'before', 'current'];
  String snapshot(String backend, String extension) => backend == 'before'
      ? '$before/current.$extension'
      : '$output/$backend.$extension';
  if (Directory(output).existsSync()) {
    throw StateError('Output already exists: $output');
  }
  Directory(output).createSync(recursive: true);
  final sourceHashes = hashes();
  final configFile = File('.dart_tool/package_config.json');
  final config = jsonDecode(configFile.readAsStringSync()) as Map;
  for (final package in config['packages'] as List) {
    package['rootUri'] = package['name'] == 'acanthis'
        ? Directory('v1').absolute.uri.toString()
        : configFile.absolute.uri
              .resolve(package['rootUri'] as String)
              .toString();
  }
  final alternate = '$output/v1-packages.json';
  File(alternate).writeAsStringSync(jsonEncode(config));
  for (final backend in ['v1', 'current']) {
    final packages = [
      '--packages=${backend == 'v1' ? alternate : configFile.path}',
    ];
    for (final format in ['kernel', 'exe']) {
      await command(Platform.resolvedExecutable, [
        'compile',
        format,
        ...packages,
        'tool/benchmark_versions.dart',
        '-o',
        '$output/$backend.${format == 'kernel' ? 'dill' : 'exe'}',
      ]);
    }
  }
  if (jsonEncode(sourceHashes) != jsonEncode(hashes())) {
    throw StateError('Sources changed during compilation');
  }
  File('$output/source-hashes.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(sourceHashes)}\n',
  );
  final programs = <String, String>{};
  for (final mode in ['jit', 'aot']) {
    for (final backend in backends) {
      final executable = mode == 'jit'
          ? Platform.resolvedExecutable
          : snapshot(backend, 'exe');
      final prefix = mode == 'jit' ? [snapshot(backend, 'dill')] : <String>[];
      final verified = await Process.run(executable, [
        ...prefix,
        '--worker',
        '--verify',
      ]);
      if (verified.exitCode != 0) throw StateError('${verified.stderr}');
      programs['$backend-$mode'] = verified.stdout.toString().trim();
    }
  }
  if (programs.values.toSet().length != 1) {
    File('$output/preflight-mismatch.json')
        .writeAsStringSync(jsonEncode(programs));
    throw StateError(
      'Cross-version workload signatures differ; timings cancelled',
    );
  }
  print(
    'All ${programs.length} preflight signatures match; starting sequential JIT/AOT samples.',
  );
  for (final mode in ['jit', 'aot']) {
    for (var pass = 1; pass <= 2; pass++) {
      for (final backend in pass == 1 ? backends : backends.reversed) {
        print('Running $backend $mode pass $pass');
        await command(
          mode == 'jit'
              ? Platform.resolvedExecutable
              : snapshot(backend, 'exe'),
          [
            if (mode == 'jit') snapshot(backend, 'dill'),
            '--worker',
            '$output/$backend-$mode-$pass.json',
          ],
        );
      }
    }
  }
  final summary = <String, Object?>{};
  for (final mode in ['jit', 'aot']) {
    final samples = <String, Map>{};
    for (final backend in backends) {
      for (var pass = 1; pass <= 2; pass++) {
        final data = jsonDecode(
          File('$output/$backend-$mode-$pass.json').readAsStringSync(),
        ) as Map;
        samples['$backend-$pass'] = data['samples_ns'] as Map;
      }
    }
    final rows = <Object?>[];
    for (final name in samples.values.first.keys) {
      final stats = <String, Map<String, num>>{};
      for (final backend in backends) {
        final values = <num>[
          ...samples['$backend-1']![name] as List,
          ...samples['$backend-2']![name] as List,
        ]..sort();
        stats[backend] = {
          'median_ns': (values[4] + values[5]) / 2,
          'min_ns': values.first,
          'max_ns': values.last,
        };
      }
      rows.add({
        'case': name,
        ...stats,
        'current_over_v1':
            stats['current']!['median_ns']! / stats['v1']!['median_ns']!,
        if (before != null)
          'current_over_before':
              stats['current']!['median_ns']! / stats['before']!['median_ns']!,
      });
    }
    summary[mode] = rows;
  }
  File('$output/summary.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(summary)}\n',
  );
  print('Comparison complete: $output/summary.json');
}
