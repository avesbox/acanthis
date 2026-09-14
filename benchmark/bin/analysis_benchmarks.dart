import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:acanthis/acanthis.dart';
import 'package:luthor/luthor.dart';
import 'package:vine/vine.dart';

Object? sink;
final cases = <String, Object? Function()>{};

double measure(Object? Function() run, int milliseconds) {
  final watch = Stopwatch()..start();
  var count = 0;
  do {
    for (var i = 0; i < 1000; i++) {
      sink = run();
    }
    count += 1000;
  } while (watch.elapsedMilliseconds < milliseconds);
  watch.stop();
  return watch.elapsedTicks * 1e9 / watch.frequency / count;
}

void main(List<String> args) {
  final bounded = string().min(1).max(5);
  cases['string.cached.parse'] = () => bounded.parse('long');
  cases['string.cached.tryParse.valid'] = () => bounded.tryParse('long');
  cases['string.cached.tryParse.invalid'] = () => bounded.tryParse('too long');
  cases['string.buildAndParse'] = () => string().min(1).max(5).parse('long');
  cases['string.buildOnly'] = () => string().min(1).max(5);
  final flatPayload = <String, dynamic>{'firstname': 'John', 'lastname': 'Doe'};
  final aFlat = object({'firstname': string(), 'lastname': string()});
  final lFlat = l.schema({'firstname': l.string(), 'lastname': l.string()});
  final vFlat = vine.compile(
    vine.object({'firstname': vine.string(), 'lastname': vine.string()}),
  );
  cases['flat.acanthis.parse'] = () => aFlat.parse(flatPayload);
  cases['flat.acanthis.tryParse'] = () => aFlat.tryParse(flatPayload);
  cases['flat.luthor.validate'] = () => lFlat.validateSchema(flatPayload);
  cases['flat.vine.validate'] = () => vFlat.validate(flatPayload);
  final nestedPayload = <String, dynamic>{
    'username': 'John',
    'password': 'secret',
    'contact': <String, dynamic>{'name': 'John', 'address': 'Main St'},
  };
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
  cases['nested.acanthis.parse'] = () => aNested.parse(nestedPayload);
  cases['nested.luthor.validate'] = () => lNested.validateSchema(nestedPayload);
  cases['nested.vine.validate'] = () => vNested.validate(nestedPayload);
  final values = List.generate(100, (i) => 'item$i');
  final items = string().min(1).list();
  cases['list100.parse'] = () => items.parse(values);
  cases['list100.tryParse.valid'] = () => items.tryParse(values);
  final invalid = List.generate(100, (i) => i.isEven ? '' : 'item$i');
  cases['list100.tryParse.halfInvalid'] = () => items.tryParse(invalid);
  final nullable = string().min(1).nullable();
  cases['nullable.parse'] = () => nullable.parse('long');
  final samples = <String, List<double>>{for (final key in cases.keys) key: []};
  for (final run in cases.values) {
    measure(run, 150);
  }
  final random = Random(42);
  for (var round = 0; round < 5; round++) {
    final order = cases.keys.toList()..shuffle(random);
    for (final name in order) {
      samples[name]!.add(measure(cases[name]!, 150));
    }
  }
  final rows = <Map<String, Object>>[];
  for (final entry in samples.entries) {
    final sorted = [...entry.value]..sort();
    final row = <String, Object>{
      'case': entry.key,
      'median_ns': sorted[2],
      'min_ns': sorted.first,
      'max_ns': sorted.last,
      'samples_ns': entry.value,
    };
    rows.add(row);
    print(
      '${entry.key}: ${sorted[2].toStringAsFixed(1)} ns/op [${sorted.first.toStringAsFixed(1)}, ${sorted.last.toStringAsFixed(1)}]',
    );
  }
  final output = {
    'sdk': Platform.version,
    'os': Platform.operatingSystem,
    'mode': args.isEmpty ? 'jit' : args.first,
    'warmup_ms_per_case': 150,
    'sample_ms': 150,
    'rounds': 5,
    'rows': rows,
  };
  File(
    'analysis_benchmarks_${args.isEmpty ? 'jit' : args.first}.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));
  print('Consumed final result: ${sink.runtimeType}');
}
