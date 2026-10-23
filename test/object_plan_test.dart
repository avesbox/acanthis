import 'support/parse_result.dart';

import 'dart:math';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

// A behavior-preserving third-party wrapper forces the ordinary child path.
final class _Ordinary extends Schema<Object?, Object?>
    with AsyncSchema<Object?, Object?>, DefaultSchema<Object?, Object?> {
  _Ordinary(this.child);
  final Schema<Object?, Object?> child;
  @override
  bool get isAsync =>
      child is AsyncSchema<Object?, Object?> &&
      (child as AsyncSchema<Object?, Object?>).isAsync;
  @override
  Object? get defaultValue => child is DefaultSchema<Object?, Object?>
      ? (child as DefaultSchema<Object?, Object?>).defaultValue
      : null;
  @override
  Object? parse(Object? input) => child.parse(input);
  @override
  AcanthisOutcome<Object?> tryParse(Object? input) => child.tryParse(input);
  @override
  Future<Object?> parseAsync(Object? input) async => parse(input);
  @override
  Future<AcanthisOutcome<Object?>> tryParseAsync(Object? input) async =>
      tryParse(input);
}

Object signature(AcanthisOutcome<Map<String, Object?>> result) => {
  'valid': result.isValid,
  'hasValue':
      result is! AcanthisInvalid || (result as AcanthisInvalid).hasValue,
  if (result is! AcanthisInvalid || (result as AcanthisInvalid).hasValue)
    'value': result.value,
  'issues': [for (final issue in result.issues) issue.toTransport()],
};

void main() {
  test(
    'small typed primitive objects preserve order and reuse unchanged inputs',
    () {
      final fields = <String, Schema<Object?, Object?>>{
        'name': string(),
        'count': integer(),
        'score': number(),
      };
      final values = <String, Object?>{'name': 'Ada', 'count': 2, 'score': 3.5};
      for (var size = 0; size <= 3; size++) {
        final shape = Map<String, Schema<Object?, Object?>>.fromEntries(
          fields.entries.take(size),
        );
        final input = Map<String, Object?>.fromEntries(
          values.entries.take(size),
        );
        for (final policy in AcanthisUnknownKeys.values) {
          final fast = object(shape).unknownKeys(policy);
          final ordinary = object(
            shape.map((key, child) => MapEntry(key, _Ordinary(child))),
          ).unknownKeys(policy);
          final inputs = <Map<String, Object?>>[
            input,
            Map.fromEntries(input.entries.toList().reversed),
            {...input, 'extra': true},
            if (size > 0) {...input, 'name': null},
            if (size > 0) {...input, 'name': 1},
            if (size > 0) {...input}..remove(shape.keys.last),
          ];
          for (final raw in inputs) {
            for (final collect in [false, true]) {
              final expected = collect
                  ? ordinary.tryParse(raw)
                  : ordinary.parseResult(raw);
              final actual = collect
                  ? fast.tryParse(raw)
                  : fast.parseResult(raw);
              expect(signature(actual), signature(expected));
              if (actual.isValid) {
                expect(actual.value.keys, expected.value.keys);
                expect(
                  identical(actual.value, raw),
                  actual.value.length == raw.length,
                );
              }
            }
          }
        }
      }
    },
  );
  test(
    'unchanged inputs retain order and stripped outputs use schema order',
    () {
      final schema = object({'a': string(), 'b': integer()});
      for (final input in [
        <String, Object?>{'a': 'x', 'b': 1},
        <String, Object?>{'b': 1, 'a': 'x'},
        <String, Object?>{'extra': 2, 'b': 1, 'a': 'x'},
        <String, Object?>{'a': 'x', 'b': 1, 'extra': 2},
      ]) {
        for (final policy in [
          AcanthisUnknownKeys.strip,
          AcanthisUnknownKeys.preserve,
        ]) {
          final result = schema.unknownKeys(policy).parseResult(input);
          expect(result.isValid, isTrue);
          final reused =
              policy == AcanthisUnknownKeys.preserve ||
              !input.containsKey('extra');
          expect(result.value.keys, reused ? input.keys : ['a', 'b']);
          expect(identical(result.value, input), reused);
        }
      }
    },
  );
  test('primitive plan matches ordinary traversal across presence, policy and type cases', () async {
    final random = Random(20261019);
    final values = <Object?>[null, '', 'ok', 0, 1, -1, 1.0, 1.5, true, [], {}];
    final fields = <String, Schema<Object?, Object?>>{
      'a.b': string(),
      'int': integer(),
      'double': doubleType(),
      'num': number(),
    };
    for (final policy in AcanthisUnknownKeys.values) {
      for (final shape in ['required', 'optional', 'partial']) {
        ObjectSchema configure(ObjectSchema schema) => (switch (shape) {
          'optional' => schema.optionals(['int', 'num']),
          'partial' => schema.partial(),
          _ => schema,
        }).unknownKeys(policy);
        final optimized = configure(object(fields));
        final ordinary = configure(
          object(fields.map((k, v) => MapEntry(k, _Ordinary(v)))),
        );
        for (var trial = 0; trial < 300; trial++) {
          final input = <Object?, Object?>{
            for (final key in fields.keys)
              if (random.nextInt(4) != 0)
                key: values[random.nextInt(values.length)],
            if (random.nextBool()) 'extra': 1,
            if (random.nextInt(20) == 0) 1: 'non-string key',
          };
          for (final collect in [false, true]) {
            final expected = collect
                ? ordinary.tryParse(input)
                : ordinary.parseResult(input);
            final actual = collect
                ? optimized.tryParse(input)
                : optimized.parseResult(input);
            expect(
              signature(actual),
              signature(expected),
              reason: '$policy/$shape/$trial/$collect',
            );
            if (trial % 30 == 0) {
              final asyncResult = await (collect
                  ? optimized.tryParseAsync(input)
                  : optimized.parseResultAsync(input));
              expect(signature(asyncResult), signature(expected));
            }
          }
        }
      }
    }
  });

  test('pure plans reuse input while checks, coercion and defaults retain behavior', () {
    final raw = <String, Object?>{'name': 'Ada', 'n': 1};
    final schema = object({'name': string(), 'n': integer()});
    final output = schema.parseResult(raw).value;
    expect(output, raw);
    expect(output, same(raw));
    output['n'] = 2;
    expect(raw['n'], 2);
    expect(
      object({'n': integer().positive()}).parseResult({'n': -1}).isValid,
      isFalse,
    );
    expect(object({'n': integer().coerce()}).parseResult({'n': '1'}).value, {
      'n': 1,
    });
    expect(object({'n': integer().withDefault(2)}).parseResult({}).value, {
      'n': 2,
    });
    expect(
      schema.refine(onCheck: (_) => false).parseResult(raw).isValid,
      isFalse,
    );
  });
}
