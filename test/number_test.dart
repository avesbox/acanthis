import 'support/parse_result.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:acanthis/acanthis.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import 'support/number_cases.dart';

void predicateTests<T extends num>(
  String baseline,
  String kind,
  AcanthisNumeric<T> Function() create,
  T lower,
  T upper,
) {
  final oracle = jsonDecode(
    File('test/fixtures/number_${baseline}_reference.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final corpus = numericCorpus(
    seed: oracle['seed'] as int,
    samples: oracle['samples'] as int,
  );
  final inputs = corpus.whereType<T>().toList();
  for (final check in numberChecks) {
    test(
      '$kind matches $baseline $check reference through all entry points',
      () async {
        final schema = numericCase(create(), check, lower, upper);
        final bits =
            (oracle['cases'] as Map<String, dynamic>)['$kind/$check'] as String;
        expect(bits.length, inputs.length);
        for (var i = 0; i < inputs.length; i++) {
          final value = inputs[i];
          for (final result in [
            schema.parseResult(value),
            schema.tryParse(value),
            await schema.parseResultAsync(value),
            await schema.tryParseAsync(value),
          ]) {
            expect(
              result.isValid,
              bits[i] == '1',
              reason: '$kind/$check sample $i: $value',
            );
            if (value.isNaN) {
              expect(result.value.isNaN, isTrue);
            } else {
              expect(result.value, value);
            }
            if (!result.isValid) {
              expect((result as AcanthisInvalid<T>).hasValue, isTrue);
              expect(result.issues.single.path, isEmpty);
              expect(
                result.issues.single.message,
                isNot(result.issues.single.code),
              );
            }
          }
        }
      },
    );
  }
}

void executionTests<T extends num>(
  AcanthisNumeric<T> Function() create,
  T value,
  T larger,
) {
  test('$T fluent operations retain their type and execute in order', () async {
    final seen = <T>[];
    final AcanthisNumeric<T> schema = create()
        .positive()
        .finite()
        .withTransform(
          CallbackTransform<T, T>((v) {
            seen.add(v);
            return larger;
          }),
        )
        .exact(larger)
        .withDefault(value)
        .coerce();
    final AcanthisOutcome<T> result = schema.parseResult(null);
    final T output = result.value;
    expect(output, larger);
    expect(seen, [value]);
    expect((await schema.tryParseAsync(value)).value, larger);
    expect(seen, [value, value]);
    expect(schema.checks, hasLength(3));
    expect(schema.transformations, hasLength(1));
    expect(() => schema.checks.clear(), throwsUnsupportedError);
    expect(() => schema.transformations.clear(), throwsUnsupportedError);
  });

  test(
    '$T fail-fast, collection and transformation gating match string schemas',
    () async {
      var transformations = 0;
      final schema = create()
          .gt(larger)
          .lt(value)
          .withTransform(
            CallbackTransform<T, T>((v) {
              transformations++;
              return v;
            }),
          );
      expect(schema.parseResult(value).issues.map((i) => i.code), ['gt']);
      expect(schema.tryParse(value).issues.map((i) => i.code), ['gt', 'lt']);
      expect((await schema.tryParseAsync(value)).issues, hasLength(2));
      expect(transformations, 0);
      expect(schema.validate(value), isFalse);
      expect(schema.tryValidate(value), isFalse);
      expect(await schema.validateAsync(value), isFalse);
      expect(await schema.tryValidateAsync(value), isFalse);
      expect(create().validate(value), isTrue);
    },
  );

  test(
    '$T async steps are sequential and contexts isolated across calls',
    () async {
      final calls = <String>[];
      final schema = create()
          .refineAsync(
            CallbackAsyncCheck<T>((v, context) async {
              calls.add('check');
              await Future<void>.value();
              calls.add('checked');
              if (v == value) context.addIssue('app.value', path: ['field']);
            }),
          )
          .transformAsync(
            CallbackAsyncTransform<T, T>((v) async {
              calls.add('transform');
              return v;
            }),
          );
      expect(schema.isAsync, isTrue);
      expect(() => schema.parseResult(value), throwsStateError);
      expect(() => schema.tryParse(value), throwsStateError);
      expect(() => schema.tryValidate(value), throwsStateError);
      expect(calls, isEmpty);
      final invalid = await schema.tryParseAsync(value);
      expect(invalid.issues.single.path, ['field']);
      expect(calls, ['check', 'checked']);
      calls.clear();
      expect((await schema.parseResultAsync(larger)).value, larger);
      expect(calls, ['check', 'checked', 'transform']);
      expect(invalid.issues.single.code, 'app.value');
    },
  );

  test(
    '$T callback exceptions propagate and bad inputs skip callbacks',
    () async {
      var calls = 0;
      final failure = StateError('callback failure');
      final check = create().withCheck(
        PredicateCheck<T>((v) {
          calls++;
          throw failure;
        }),
      );
      final transform = create().withTransform(
        CallbackTransform<T, T>((v) => throw failure),
      );
      expect(check.tryParse('bad').isValid, isFalse);
      expect(calls, 0);
      for (final schema in [check, transform]) {
        expect(() => schema.parseResult(value), throwsA(same(failure)));
        expect(() => schema.tryParse(value), throwsA(same(failure)));
        await expectLater(schema.tryParseAsync(value), throwsA(same(failure)));
      }
      final asyncFailure = create().refineAsync(
        CallbackAsyncCheck<T>((v, context) async {
          throw failure;
        }),
      );
      await expectLater(
        asyncFailure.parseResultAsync(value),
        throwsA(same(failure)),
      );
    },
  );
}

void main() {
  test(
    'integer conversion agrees with exact arithmetic across IEEE bit patterns',
    () {
      final schema = integer().coerce();
      final random = Random(20261015);
      final data = ByteData(8);
      final values = <double>[
        9007199254740991.0,
        9007199254740992.0,
        1e16,
        9223372036854774784.0,
        9223372036854775808.0,
        9223372036854777856.0,
        -9223372036854774784.0,
        -9223372036854775808.0,
        -9223372036854777856.0,
        double.maxFinite,
        -double.maxFinite,
        double.minPositive,
        -double.minPositive,
        double.nan,
        double.infinity,
        double.negativeInfinity,
        -0.0,
        0.0,
        for (var i = 0; i < 10000; i++)
          (() {
            data.setUint32(
              0,
              random.nextInt(0x10000) * 0x10000 + random.nextInt(0x10000),
            );
            data.setUint32(
              4,
              random.nextInt(0x10000) * 0x10000 + random.nextInt(0x10000),
            );
            return data.getFloat64(0);
          })(),
      ];
      for (final value in values) {
        int? expected;
        if (value.isFinite && value == value.truncateToDouble()) {
          final exact = BigInt.from(value);
          final candidate = exact.toInt();
          if (BigInt.from(candidate) == exact) expected = candidate;
        }
        final result = schema.tryParse(value);
        expect(result.isValid, expected != null, reason: '$value');
        if (expected != null) expect(result.value, expected);
      }
    },
  );

  test('built-in check chains preserve ordered failures and recovery in both policies', () async {
    final schema = integer().gte(10).lte(1).between(20, 30);
    expect(schema.parseResult(5).issues.map((i) => i.code), ['gte']);
    final result = schema.tryParse(5);
    expect(result.value, 5);
    expect(result.issues.map((i) => i.code), ['gte', 'lte', 'between']);
    expect((await schema.tryParseAsync(5)).issues, result.issues);
    expect(schema.checks, hasLength(3));
    expect(() => schema.checks.clear(), throwsUnsupportedError);
    expect(result.issues, hasLength(3));
  });

  test(
    'a custom check in a built-in chain executes once and retains its position',
    () {
      var calls = 0;
      final schema = integer()
          .gte(10)
          .withCheck(
            CallbackCheck((value, context) {
              calls++;
              context.addIssue('app.check', path: ['custom']);
            }),
          )
          .lte(1);
      expect(schema.checks, hasLength(3));
      expect(calls, 0);
      final result = schema.tryParse(5);
      expect(calls, 1);
      expect(result.issues.map((i) => i.code), ['gte', 'app.check', 'lte']);
      expect(result.issues[1].path, ['custom']);
      schema.parseResult(5);
      expect(calls, 1);
    },
  );

  for (final baseline in ['v1', 'v2']) {
    predicateTests<num>(baseline, 'num', number, 1, 4);
    predicateTests<int>(baseline, 'int', integer, 1, 4);
    predicateTests<double>(baseline, 'double', doubleType, 1.0, 4.0);

    test('$baseline numeric reference corpus matches its captured fingerprint', () {
      final reference = jsonDecode(
        File('test/fixtures/number_${baseline}_reference.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final corpus = numericCorpus(
        seed: reference['seed'] as int,
        samples: reference['samples'] as int,
      );
      expect(corpus.length, reference['corpus_size']);
      expect(
        sha256
            .convert(utf8.encode(jsonEncode(numericCorpusTokens(corpus))))
            .toString(),
        reference['corpus_sha256'],
      );
      expect((reference['cases'] as Map).length, numberChecks.length * 3);
      if (baseline == 'v2') expect(reference['implementation'], 'v2');
    });
  }
  executionTests<num>(number, 2, 4);
  executionTests<int>(integer, 2, 4);
  executionTests<double>(doubleType, 2.0, 4.0);

  test('number, integer and double strict boundaries never widen through fluent methods', () {
    final AcanthisNumber n = number()
        .positive()
        .nonNegative()
        .notNaN()
        .finite()
        .multipleOf(1)
        .integer()
        .double();
    final AcanthisInt i = integer()
        .positive()
        .finite()
        .multipleOf(1)
        .pow(2)
        .withDefault(1);
    final AcanthisDouble d = doubleType()
        .positive()
        .finite()
        .pow(2)
        .withDefault(1.0);
    expect(n, isA<Schema<num, num>>());
    expect(i.tryParse(2.0).isValid, isFalse);
    expect(d.tryParse(2).isValid, isFalse);
    final int intValue = i.parseResult(2).value;
    final double doubleValue = d.parseResult(2.0).value;
    expect(intValue, 4);
    expect(doubleValue, 4.0);
    expect(number().integer().parseResult(2.0).isValid, isFalse);
    expect(number().double().parseResult(2).isValid, isFalse);
    for (final schema in <Schema<num, num>>[
      number(),
      integer(),
      doubleType(),
    ]) {
      for (final input in <Object?>[null, '2', false, [], {}]) {
        final result = schema.tryParse(input) as AcanthisInvalid<num>;
        expect(result.hasValue, isFalse);
        expect(result.issues.single.code, 'type');
        expect(() => result.value, throwsStateError);
      }
    }
  });

  test('numeric factories are available through both public facades', () {
    expect(Acanthis.number().parseResult(2).value, 2);
    expect(Acanthis.integer().parseResult(2).value, 2);
    expect(Acanthis.doubleType().parseResult(2.0).value, 2.0);
    expect(AcanthisType.integer().parseResult(2).value, 2);
    expect(AcanthisInt().parseResult(2).value, 2);
    expect(AcanthisDouble().parseResult(2.0).value, 2.0);
  });

  test('integer coercion accepts integral values and rejects truncation or saturation', () {
    final schema = integer().coerce();
    for (final input in <Object>[
      2,
      2.0,
      '2',
      ' 2 ',
      '2.0',
      '2e0',
      '+2',
      '0x2',
    ]) {
      final int value = schema.parseResult(input).value;
      expect(value, 2);
    }
    for (final input in <Object?>[
      null,
      true,
      '',
      'bad',
      2.5,
      '2.5',
      double.nan,
      double.infinity,
      'NaN',
      'Infinity',
      1e40,
      -1e40,
      9223372036854775808.0,
      '9223372036854775808',
      '-9223372036854775809',
    ]) {
      final result = schema.tryParse(input);
      expect(result.isValid, isFalse, reason: '$input');
      expect((result as AcanthisInvalid<int>).hasValue, isFalse);
    }
    expect(
      schema.parseResult('9223372036854775807').value,
      9223372036854775807,
    );
    expect(
      schema.parseResult('-9223372036854775808').value,
      -9223372036854775808,
    );
  });

  test('number and double coercion preserve their V1 non-finite policies', () {
    final n = number().coerce();
    final d = doubleType().coerce();
    expect(n.parseResult('2').value, isA<int>());
    expect(n.parseResult('2.5').value, 2.5);
    expect(n.parseResult('NaN').value.isNaN, isTrue);
    expect(n.parseResult('Infinity').value.isInfinite, isTrue);
    expect(d.parseResult(2).value, isA<double>());
    expect(d.parseResult(' 2.5 ').value, 2.5);
    expect(d.parseResult(double.nan).value.isNaN, isTrue);
    expect(d.parseResult(double.infinity).value.isInfinite, isTrue);
    for (final input in <Object?>[
      'NaN',
      'Infinity',
      '',
      'bad',
      false,
      {},
      null,
    ]) {
      expect(d.tryParse(input).isValid, isFalse, reason: '$input');
    }
    expect(d.finite().tryParse(double.infinity).isValid, isFalse);
  });

  test(
    'defaults validate normally and survive coercion and operation copies',
    () {
      final original = integer().coerce().withDefault(3);
      final stricter = original.gte(4).pow(2);
      expect(original.parseResult(null).value, 3);
      expect(stricter.tryParse(null).issues.single.code, 'gte');
      expect(stricter.tryParse(null).value, 3);
      expect(stricter.parseResult('4').value, 16);
      expect(
        doubleType().withDefault(double.nan).notNaN().tryParse(null).isValid,
        isFalse,
      );
    },
  );

  test(
    'pow keeps the output type and reports incompatible integer results',
    () async {
      final int square = integer().pow(2).parseResult(3).value;
      final double reciprocal = doubleType().pow(-1).parseResult(2.0).value;
      final num generic = number().pow(-1).parseResult(2).value;
      expect(square, 9);
      expect(reciprocal, 0.5);
      expect(generic, 0.5);
      for (final input in [0, 2, -2]) {
        final result = integer().pow(-1).tryParse(input);
        expect(result.isValid, isFalse);
        expect(result.value, input);
        expect(result.issues.single.code, 'transform');
        expect(result.issues.single.parameters, {
          'operation': 'pow',
          'exponent': -1,
        });
      }
      expect(integer().pow(-1).parseResult(1).value, 1);
      expect(integer().pow(-3).parseResult(-1).value, -1);
      expect((await integer().pow(0).parseResultAsync(0)).value, 1);
      expect(doubleType().pow(2).finite().tryParse(1e308).isValid, isFalse);
      final trulyAsync = integer()
          .refineAsync(CallbackAsyncCheck((v, c) async {}))
          .pow(-1);
      expect(
        (await trulyAsync.tryParseAsync(2)).issues.single.code,
        'transform',
      );
    },
  );

  test('definitions and numeric metadata are immutable with IEEE equality', () {
    final values = <num>[1, 4, double.nan];
    final schema = number().enumerated(values);
    values
      ..clear()
      ..add(2);
    expect(schema.parseResult(1.0).isValid, isTrue);
    expect(schema.parseResult(2).isValid, isFalse);
    expect(schema.parseResult(double.nan).isValid, isFalse);
    expect(number().exact(double.nan).parseResult(double.nan).isValid, isFalse);
    expect(number().enumerated([-0.0]).parseResult(0).isValid, isTrue);
    expect(() => integer().enumerated([]), throwsArgumentError);
    expect(() => number().multipleOf(0), throwsArgumentError);
    expect(integer().multipleOf(-2).parseResult(4).isValid, isTrue);
    expect(number().between(4, 1).parseResult(2).isValid, isFalse);
    final diagnostic = schema.tryParse(2).issues.single;
    expect(
      () => (diagnostic.parameters['values'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(() => jsonEncode(diagnostic.toJson()), returnsNormally);
  });

  test(
    'numeric issue codes can be localized with frozen constraint parameters',
    () {
      final issue = number().between(1, 4).parseResult(5).issues.single;
      final catalog = AcanthisMessageCatalog({
        'between': (p) => 'Tra ${p['min']} e ${p['max']}',
      });
      expect(issue.formatMessage(catalog: catalog), 'Tra 1 e 4');
      expect(issue.parameters, {'min': 1, 'max': 4});
    },
  );

  test(
    'concurrent numeric async parses collect independent failures',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var calls = 0;
      final schema = integer().refineAsync(
        CallbackAsyncCheck((v, context) async {
          if (++calls == 2) entered.complete();
          await release.future;
          context.addIssue('app.value', parameters: {'expected': v});
        }),
      );
      final a = schema.tryParseAsync(1);
      final b = schema.tryParseAsync(2);
      await entered.future;
      release.complete();
      expect((await a).issues.single.parameters, {'expected': 1});
      expect((await b).issues.single.parameters, {'expected': 2});
    },
  );

  test(
    'long numeric fluent chains materialize and execute without recursion',
    () {
      var schema = integer();
      for (var i = 0; i < 5000; i++) {
        schema = schema.gte(1);
      }
      expect(schema.parseResult(1).value, 1);
      expect(schema.tryParse(0).issues, hasLength(5000));
    },
  );
}
