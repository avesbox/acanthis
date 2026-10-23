import 'support/parse_result.dart';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'record factories validate shared key and value schemas with typed output',
    () async {
      for (final schema in [
        RecordSchema(string().trim(), integer().coerce()),
        record(string().trim(), integer().coerce()),
        Acanthis.record(string().trim(), integer().coerce()),
        AcanthisType.record(string().trim(), integer().coerce()),
      ]) {
        final input = <Object?, Object?>{' a ': '1', 'b': 2};
        for (final result in [
          schema.parseResult(input),
          schema.tryParse(input),
          await schema.parseResultAsync(input),
          await schema.tryParseAsync(input),
        ]) {
          final Map<String, int> output = result.value;
          expect(result.isValid, isTrue);
          expect(output, {'a': 1, 'b': 2});
        }
        expect(input, {' a ': '1', 'b': 2});
        expect(schema.parseResult({}).value, isEmpty);
        expect(schema.validate(input), isTrue);
        expect(schema.tryValidate(input), isTrue);
        expect(await schema.validateAsync(input), isTrue);
        expect(await schema.tryValidateAsync(input), isTrue);
      }
    },
  );

  test('records support non-string output keys and nested values', () {
    final schema = record(integer().coerce(), list(object({'n': integer()})));
    final result = schema.parseResult({
      '1': [
        {'n': 2},
      ],
    });
    final Map<int, List<Map<String, Object?>>> output = result.value;
    expect(result.isValid, isTrue);
    expect(output, {
      1: [
        {'n': 2},
      ],
    });
    expect(
      schema
          .tryParse({
            '1': [
              {'n': 'bad'},
            ],
          })
          .issues
          .single
          .path,
      ['1', 0, 'n'],
    );
    expect(
      record(string(), record(string(), integer()))
          .tryParse({
            'outer': {'inner': 'bad'},
          })
          .issues
          .single
          .path,
      ['outer', 'inner'],
    );
  });

  test('non-map input fails without fabricating a typed dictionary', () async {
    final schema = record(string(), integer());
    for (final input in [null, [], 'map', 1]) {
      for (final result in [
        schema.parseResult(input),
        await schema.tryParseAsync(input),
      ]) {
        expect(result.isValid, isFalse);
        expect((result as AcanthisInvalid<Map<String, int>>).hasValue, isFalse);
        expect(result.issues.single.code, 'type');
        expect(result.issues.single.path, isEmpty);
        expect(() => result.value, throwsStateError);
      }
    }
  });

  test('fail-fast key failure skips value and remaining entries; collecting validates both', () {
    final seen = <int>[];
    final schema = record(
      string().min(2),
      integer().refine(
        onCheck: (v) {
          seen.add(v);
          return v > 0;
        },
        name: 'positiveValue',
      ),
    );
    final input = {'a': -1, 'b': -2};
    final first = schema.parseResult(input);
    expect(seen, isEmpty);
    expect(first.issues.single.code, 'minLength');
    expect(first.issues.single.path, ['a']);
    expect((first as AcanthisInvalid<Map<String, int>>).hasValue, isFalse);
    final all = schema.tryParse(input) as AcanthisInvalid<Map<String, int>>;
    expect(seen, [-1, -2]);
    expect(all.hasValue, isTrue);
    expect(all.value, input);
    expect(all.issues.map((i) => i.code), [
      'minLength',
      'positiveValue',
      'minLength',
      'positiveValue',
    ]);
    expect(all.issues.map((i) => i.path), [
      ['a'],
      ['a'],
      ['b'],
      ['b'],
    ]);
    seen.clear();
    final valueFailure = record(
      string(),
      integer().refine(
        onCheck: (v) {
          seen.add(v);
          return v > 0;
        },
      ),
    ).parseResult(input);
    expect(valueFailure.isValid, isFalse);
    expect(seen, [-1]);
  });

  test(
    'missing key or value recovery cannot produce a partial typed dictionary',
    () {
      final schema = record(string(), integer());
      for (final input in [
        <Object?, Object?>{1: 1, 'a': 2},
        <Object?, Object?>{'a': 'bad', 'b': 2},
      ]) {
        final result =
            schema.tryParse(input) as AcanthisInvalid<Map<String, int>>;
        expect(result.hasValue, isFalse);
        expect(() => result.value, throwsStateError);
        expect(result.issues.single.code, 'type');
      }
    },
  );

  test(
    'transformed key collisions fail explicitly instead of overwriting entries',
    () async {
      final schema = record(string().trim(), integer());
      for (final result in [
        schema.parseResult({'a': 1, ' a ': 2}),
        schema.tryParse({'a': 1, ' a ': 2}),
        await schema.parseResultAsync({'a': 1, ' a ': 2}),
        await schema.tryParseAsync({'a': 1, ' a ': 2}),
      ]) {
        expect(result.isValid, isFalse);
        expect((result as AcanthisInvalid<Map<String, int>>).hasValue, isFalse);
        expect(result.issues.single.code, 'duplicateKey');
        expect(result.issues.single.path, [' a ']);
        expect(
          result.issues.single.message,
          'Multiple entries produce the same key',
        );
      }
      expect(
        schema
            .tryParse({'a': 1, ' a ': 2, 'bad': 'x'})
            .issues
            .map((i) => i.code),
        ['duplicateKey', 'type'],
      );
      final numeric = record(integer().coerce(), integer());
      expect(
        numeric.tryParse(<Object?, Object?>{1: 1, '1': 2}).issues.single.code,
        'duplicateKey',
      );
    },
  );

  test(
    'issue paths use original keys or entry indices for other Dart key types',
    () {
      final schema = record(string(), integer());
      final result = schema.tryParse(<Object?, Object?>{
        10: 'bad',
        true: 'bad',
        null: 'bad',
      });
      expect(result.issues.map((i) => i.path), [
        [10],
        [10],
        [1],
        [1],
        [2],
        [2],
      ]);
    },
  );

  test(
    'defaults are snapshots, validate children and survive fluent operations',
    () {
      final defaults = {'a': 1};
      final base = record(string(), integer());
      final schema = base
          .withDefault(defaults)
          .refine(onCheck: (v) => v.length == 1)
          .transform((v) => {...v, 'b': 2});
      defaults.clear();
      expect(base.defaultValue, isNull);
      expect(base.checks, isEmpty);
      expect(schema.parseResult(null).value, {'a': 1, 'b': 2});
      expect(() => schema.defaultValue!.clear(), throwsUnsupportedError);
      expect(() => schema.checks.clear(), throwsUnsupportedError);
      expect(() => schema.transformations.clear(), throwsUnsupportedError);
      expect(
        record(
          string(),
          integer().positive(),
        ).withDefault({'a': -1}).parseResult(null).issues.single.path,
        ['a'],
      );
    },
  );

  test('record operations collect checks but gate transforms on child and parent failures', () {
    var transformed = false;
    final schema = record(string(), integer().positive())
        .refine(onCheck: (_) => false, name: 'parent')
        .refine(onCheck: (_) => false, name: 'other')
        .transform((v) {
          transformed = true;
          return v;
        });
    expect(schema.tryParse({'a': -1}).issues.map((i) => i.code), [
      'positive',
      'parent',
      'other',
    ]);
    expect(schema.parseResult({'a': -1}).issues.map((i) => i.code), [
      'positive',
    ]);
    expect(schema.parseResult({'a': 1}).issues.map((i) => i.code), ['parent']);
    expect(transformed, isFalse);
  });

  test(
    'async key, value and parent steps are sequential and preserve ordering',
    () async {
      final calls = <String>[];
      final schema =
          record(
                string().transformAsync(
                  CallbackAsyncTransform((v) async {
                    await Future<void>.value();
                    calls.add('key:$v');
                    return v.trim();
                  }),
                ),
                integer().transformAsync(
                  CallbackAsyncTransform((v) async {
                    await Future<void>.value();
                    calls.add('value:$v');
                    return v + 1;
                  }),
                ),
              )
              .withCheck(
                CallbackCheck((_, _) {
                  calls.add('sync');
                }),
              )
              .refineAsync(
                CallbackAsyncCheck((_, _) async {
                  calls.add('async');
                }),
              )
              .transform((v) {
                calls.add('transform');
                return v;
              })
              .transformAsync(
                CallbackAsyncTransform((v) async {
                  calls.add('asyncTransform');
                  return {...v, 'c': 3};
                }),
              )
              .refine(onCheck: (v) => v.length == 3);
      expect(schema.isAsync, isTrue);
      expect(() => schema.parseResult({}), throwsStateError);
      expect(() => schema.tryParse({}), throwsStateError);
      for (final collect in [false, true]) {
        calls.clear();
        final result = await (collect
            ? schema.tryParseAsync({' a ': 1, 'b': 2})
            : schema.parseResultAsync({' a ': 1, 'b': 2}));
        expect(result.isValid, isTrue);
        expect(result.value, {'a': 2, 'b': 3, 'c': 3});
        expect(calls, [
          'key: a ',
          'value:1',
          'key:b',
          'value:2',
          'sync',
          'async',
          'transform',
          'asyncTransform',
        ]);
      }
    },
  );

  test('async fail-fast, collection, collisions and missing recovery match sync behavior', () async {
    var valueCalls = 0;
    final schema = record(
      string().trim().min(2).refineAsync(CallbackAsyncCheck((_, _) async {})),
      integer().refineAsync(
        CallbackAsyncCheck((v, context) async {
          valueCalls++;
          if (v < 0) context.addIssue('remote');
        }),
      ),
    );
    expect(
      (await schema.parseResultAsync({'a': -1, 'b': -2})).issues.single.code,
      'minLength',
    );
    expect(valueCalls, 0);
    final all = await schema.tryParseAsync({'a': -1, 'b': -2});
    expect(valueCalls, 2);
    expect(all.issues.map((i) => i.code), [
      'minLength',
      'remote',
      'minLength',
      'remote',
    ]);
    expect(all.value, {'a': -1, 'b': -2});
    final missing = await schema.tryParseAsync(<Object?, Object?>{
      1: 'bad',
      'ok': 1,
    }) as AcanthisInvalid<Map<String, int>>;
    expect(missing.hasValue, isFalse);
    expect(missing.issues.map((i) => i.code), ['type', 'type']);
    expect(
      (await schema.tryParseAsync({'ok': 1, ' ok ': 2})).issues.single.code,
      'duplicateKey',
    );
    expect(
      (await schema.parseResultAsync({'ok': 1, ' ok ': 2})).issues.single.code,
      'duplicateKey',
    );
    expect((await schema.parseResultAsync([])).issues.single.code, 'type');
  });

  test('async parent failure gates transforms and concurrent contexts are isolated', () async {
    var transformed = 0;
    final schema = record(string(), integer())
        .refineAsync(
          CallbackAsyncCheck((v, context) async {
            await Future<void>.value();
            if (v.values.any((n) => n < 0)) context.addIssue('remote');
          }),
        )
        .refine(onCheck: (v) => v.isNotEmpty, name: 'notEmpty')
        .transformAsync(
          CallbackAsyncTransform((v) async {
            transformed++;
            return {...v, 'done': 1};
          }),
        );
    final results = await Future.wait([
      schema.tryParseAsync({'a': -1}),
      schema.tryParseAsync({'a': 1}),
    ]);
    expect(results.first.issues.single.code, 'remote');
    expect(results.first.value, {'a': -1});
    expect(results.last.value, {'a': 1, 'done': 1});
    expect(transformed, 1);
    final empty = await schema.tryParseAsync({});
    expect(empty.issues.single.code, 'notEmpty');
    expect(transformed, 1);
  });

  test(
    'callback exceptions propagate from map children and parent operations',
    () async {
      final error = StateError('callback');
      expect(
        () =>
            object({'n': integer().transform((_) => throw error)})
                .parseResult({'n': 1}),
        throwsA(same(error)),
      );
      expect(
        () => record(
          string().transform((_) => throw error),
          integer(),
        ).parseResult({'a': 1}),
        throwsA(same(error)),
      );
      expect(
        () => object({}).transform((_) => throw error).parseResult({}),
        throwsA(same(error)),
      );
      await expectLater(
        record(string(), integer())
            .transformAsync(CallbackAsyncTransform((_) async => throw error))
            .parseResultAsync({}),
        throwsA(same(error)),
      );
    },
  );
}
