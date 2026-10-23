import 'support/parse_result.dart';

import 'dart:convert';
import 'dart:math';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

final class _Ordinary<T> extends Schema<Object?, T>
    with AsyncSchema<Object?, T>, DefaultSchema<Object?, T> {
  _Ordinary(this.child);
  final Schema<Object?, T> child;
  @override
  bool get isAsync =>
      child is AsyncSchema<Object?, T> &&
      (child as AsyncSchema<Object?, T>).isAsync;
  @override
  T? get defaultValue => child is DefaultSchema<Object?, T>
      ? (child as DefaultSchema<Object?, T>).defaultValue
      : null;
  @override
  T parse(Object? input) => child.parse(input);
  @override
  AcanthisOutcome<T> tryParse(Object? input) => child.tryParse(input);
  @override
  Future<T> parseAsync(Object? input) async => parse(input);
  @override
  Future<AcanthisOutcome<T>> tryParseAsync(Object? input) async =>
      tryParse(input);
}

Object signature(AcanthisOutcome<Object?> result) => {
  'valid': result.isValid,
  'hasValue': result is! AcanthisInvalid || result.hasValue,
  if (result is! AcanthisInvalid || result.hasValue) 'value': result.value,
  'issues': [for (final issue in result.issues) issue.toTransport()],
};

void main() {
  test(
    'typed string batches match ordinary children and collection policies',
    () {
      final native = string().min(2).max(8).email();
      final fast = list(native).min(2).transform((value) => [...value, 'done']);
      final ordinary = list(_Ordinary(native))
          .min(2)
          .transform((value) => [...value, 'done']);
      final random = Random(20261023);
      for (final policy in AcanthisCollectionPolicy.values) {
        AcanthisValidationScope(fieldPolicy: policy).run(() {
          for (var trial = 0; trial < 150; trial++) {
            final input = List<String>.generate(
              random.nextInt(8),
              (_) => ['', 'a', 'much longer', 'a@b.co'][random.nextInt(4)],
            );
            for (final collect in [false, true]) {
              final actual = collect
                  ? fast.tryParse(input)
                  : fast.parseResult(input);
              final expected = collect
                  ? ordinary.tryParse(input)
                  : ordinary.parseResult(input);
              expect(
                signature(actual),
                signature(expected),
                reason: '$policy $input $collect',
              );
            }
          }
        });
      }
      final input = <String>['Ada', 'Rome'];
      expect(fast.parse(['a@b.co', 'b@c.co']), ['a@b.co', 'b@c.co', 'done']);
      final widened = list<Object?>(string().min(1));
      expect(widened.parse(input), same(input));
      expect(list(string().min(1)).parse(input), same(input));
      expect(list(string().min(1)).tryParse(input).value, same(input));
      expect(list(string().min(1)).parse(<Object?>['Ada']), ['Ada']);
      expect(
        list(string().min(1)).tryParse(<Object?>['Ada', 42]).issues.single.path,
        [1],
      );
    },
  );

  test('nested built-in path matches forced ordinary traversal for 1500 seeded inputs', () async {
    ObjectSchema build(bool ordinary) {
      Schema<Object?, T> wrap<T>(Schema<Object?, T> child) =>
          ordinary ? _Ordinary(child) : child;
      final item = object({
        'name': wrap(string().min(1).max(8)),
        'score': wrap(number().gte(0).lte(10)),
      });
      return object({
        'title': wrap(string().min(1)),
        'items': wrap(list(wrap(item))),
        'nested': wrap(item),
      });
    }

    final fast = build(false);
    final ordinary = build(true);
    final random = Random(20261020);
    for (var trial = 0; trial < 1500; trial++) {
      final input = <String, Object?>{
        'title': trial % 9 == 0 ? '' : 'title',
        'items': <Object?>[
          for (var i = 0; i < random.nextInt(5); i++)
            {
              'name': trial % 7 == 0 ? '' : 'item',
              'score': random.nextInt(14) - 2,
            },
        ],
        'nested': {'name': 'nested', 'score': random.nextInt(14) - 2},
        if (random.nextBool()) 'extra': true,
      };
      final snapshot = jsonEncode(input);
      for (final collect in [false, true]) {
        final expected = collect
            ? ordinary.tryParse(input)
            : ordinary.parseResult(input);
        final actual = collect ? fast.tryParse(input) : fast.parseResult(input);
        expect(
          signature(actual),
          signature(expected),
          reason: 'trial=$trial collect=$collect',
        );
        if (trial % 100 == 0) {
          expect(
            signature(await fast.tryParseAsync(input)),
            signature(ordinary.tryParse(input)),
          );
        }
      }
      expect(jsonEncode(input), snapshot);
    }
  });

  test('custom callbacks, transformation boundaries and child recovery retain behavior', () {
    var checks = 0;
    var transforms = 0;
    final schema =
        object({
          'safe': object({'n': number().gte(0)}),
          'callback': number().refine(
            onCheck: (v) {
              checks++;
              return v > 0;
            },
          ),
        }).transform((v) {
          transforms++;
          return v;
        });
    expect(
      schema.tryParse({
        'safe': {'n': 1},
        'callback': 1,
      }).isValid,
      isTrue,
    );
    expect(checks, 1);
    expect(transforms, 1);
    expect(
      schema.parseResult({
        'safe': {'n': -1},
        'callback': 1,
      }).isValid,
      isFalse,
    );
    expect(checks, 1);
    expect(
      schema.tryParse({
        'safe': {'n': -1},
        'callback': 1,
      }).value,
      {
        'safe': {'n': -1},
        'callback': 1,
      },
    );
    expect(checks, 2);
    expect(transforms, 1);
  });

  test('fast composites reuse unchanged maps and correctly typed lists', () {
    final inner = object({'n': integer()});
    final listSchema = list(inner);
    final input = <Map<String, Object?>>[
      {'n': 1},
    ];
    final List<Map<String, Object?>> output = listSchema
        .parseResult(input)
        .value;
    expect(output, same(input));
    expect(output.single, same(input.single));
    output.single['n'] = 2;
    expect(input.single['n'], 2);
    expect(list(integer()).parseResult(<int>[1]).value, isA<List<int>>());
  });
}
