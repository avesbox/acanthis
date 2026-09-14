import 'dart:io';
import 'package:acanthis/acanthis.dart';

Future<void> main() async {
  final lines = <String>[];
  Future<void> probe(String name, dynamic Function() action) async {
    try {
      lines.add('$name: ${await action()}');
    } catch (e) {
      lines.add('$name: THREW ${e.runtimeType}: $e');
    }
  }

  final choice = union<String>([literal('a'), literal('b')]);
  await probe('union standalone invalid', () => choice.tryParse('c'));
  await probe(
    'union nested invalid',
    () => object({'x': choice}).tryParse({'x': 'c'}),
  );
  await probe(
    'tuple nested invalid',
    () =>
        object({
          'x': tuple([string()]),
        }).tryParse({
          'x': [42, 43],
        }),
  );
  final nullableTransform = string().transform((s) => '${s}x').nullable();
  await probe('nullable transform sync', () => nullableTransform.parse('a'));
  await probe(
    'nullable transform async',
    () => nullableTransform.parseAsync('a'),
  );
  await probe('literal async invalid', () => literal('a').tryParseAsync('b'));
  await probe('object wrong type', () => object({'x': string()}).tryParse(42));
  await probe('list wrong type', () => string().list().tryParse(42));
  final asyncChild = string().refineAsync(
    onCheck: (_) async => false,
    error: 'no',
    name: 'remote',
  );
  await probe(
    'nested async sync call',
    () => object({'x': asyncChild}).tryParse({'x': 'a'}),
  );
  final flat = object({'x': string()});
  await probe('unknown keys sync', () => flat.parse({'x': 'a', 'extra': true}));
  await probe(
    'unknown keys async',
    () => flat.parseAsync({'x': 'a', 'extra': true}),
  );
  final refined = union<String>([
    string(),
  ]).refine(onCheck: (_) => false, error: 'no', name: 'own');
  await probe('union parse failing refinement', () => refined.parse('a'));
  final asyncUnion = union<String>([literal('a'), literal('b')]);
  await probe('union async later match', () => asyncUnion.tryParseAsync('b'));
  final builder = classSchema<String, String>()
      .input(string())
      .map((s) => '${s}1');
  final built = builder.build();
  builder.map((s) => '${s}2');
  await probe('builder mutated after build', () => built.parse('a'));
  stdout.writeln(lines.join('\n'));
  File('analysis_probe_results.txt').writeAsStringSync('${lines.join('\n')}\n');
}
