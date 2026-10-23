import 'support/parse_result.dart';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test('factories preserve element and output types', () async {
    final element = integer();
    for (final schema in [
      list(element),
      element.list(),
      Acanthis.list(element),
      AcanthisType.list(element),
    ]) {
      final input = <int>[1, 2];
      expect(schema.unwrap(), same(element));
      for (final result in [
        schema.parseResult(input),
        schema.tryParse(input),
        await schema.parseResultAsync(input),
        await schema.tryParseAsync(input),
      ]) {
        final List<int> value = result.value;
        expect(result.isValid, isTrue);
        expect(value, same(input));
      }
      expect(schema.parseResult(<Object?>[1, 2]).value, <int>[1, 2]);
      expect(schema.parseResult([]).value, isEmpty);
      expect(schema.validate(input), isTrue);
      expect(schema.tryValidate(input), isTrue);
      expect(await schema.validateAsync(input), isTrue);
      expect(await schema.tryValidateAsync(input), isTrue);
    }
  });

  test('wrong input has a type issue and no fabricated recovery', () async {
    final schema = list(integer());
    for (final input in [
      null,
      'list',
      1,
      {},
      {1, 2},
    ]) {
      for (final result in [
        schema.parseResult(input),
        schema.tryParse(input),
        await schema.parseResultAsync(input),
        await schema.tryParseAsync(input),
      ]) {
        expect(result, isA<AcanthisInvalid<List<int>>>());
        expect((result as AcanthisInvalid<List<int>>).hasValue, isFalse);
        expect(() => result.value, throwsStateError);
        expect(result.issues.single.code, 'type');
        expect(result.issues.single.path, isEmpty);
        expect(result.issues.single.parameters, {'expected': 'List'});
      }
    }
  });

  test(
    'children transform without mutating the input, including nested lists',
    () {
      final input = <String>[' a ', ' b '];
      final output = list(string().trim()).parseResult(input).value;
      expect(output, ['a', 'b']);
      expect(output, isNot(same(input)));
      expect(input, [' a ', ' b ']);
      expect(list(integer().coerce()).parseResult(<Object?>['1', 2]).value, [
        1,
        2,
      ]);
      final result = list(list(string().min(2))).tryParse([
        ['a'],
      ]);
      expect(result.isValid, isFalse);
      expect(result.issues.single.path, [0, 0]);
      expect(result.issues.single.code, 'minLength');
    },
  );

  test(
    'fail-fast and collection retain ordered child issues and typed recovery',
    () {
      final seen = <int>[];
      final schema = list(
        integer().refine(
          onCheck: (v) {
            seen.add(v);
            return v > 0;
          },
          name: 'positiveChild',
        ),
      );
      final input = <int>[-1, -2, 3];
      final first = schema.parseResult(input) as AcanthisInvalid<List<int>>;
      expect(seen, [-1]);
      expect(first.hasValue, isTrue);
      expect(first.value, same(input));
      expect(first.issues.single.path, [0]);
      seen.clear();
      final all = schema.tryParse(input) as AcanthisInvalid<List<int>>;
      expect(seen, [-1, -2, 3]);
      expect(all.value, same(input));
      expect(all.issues.map((i) => i.path), [
        [0],
        [1],
      ]);
      final missing = schema.tryParse(<Object?>[
        -1,
        'bad',
        -2,
      ]) as AcanthisInvalid<List<int>>;
      expect(missing.hasValue, isFalse);
      expect(missing.issues.map((i) => i.path), [
        [0],
        [1],
        [2],
      ]);
      expect(() => missing.value, throwsStateError);
      final partial =
          schema.parseResult(<Object?>[-1, 3]) as AcanthisInvalid<List<int>>;
      expect(partial.hasValue, isFalse);
    },
  );

  test('native list constraints preserve V1 membership semantics', () async {
    final cases =
        <
          (
            AcanthisList<int>,
            List<int>,
            List<int>,
            String,
            Map<String, Object?>,
          )
        >[
          (list(integer()).min(2), [1, 2], [1], 'minItems', {'minItems': 2}),
          (list(integer()).max(1), [1], [1, 2], 'maxItems', {'maxItems': 1}),
          (list(integer()).length(2), [1, 2], [1], 'length', {'length': 2}),
          (list(integer()).unique(), [1, 2], [1, 1], 'uniqueItems', {}),
          (
            list(integer()).contains(2),
            [1, 2],
            [1],
            'containsItem',
            {'item': 2},
          ),
          (
            list(integer()).anyOf([2, 3]),
            [2],
            [1],
            'anyOf',
            {
              'items': [2, 3],
            },
          ),
          (
            list(integer()).everyOf([2, 3]),
            [2],
            [1, 2],
            'everyOf',
            {
              'items': [2, 3],
            },
          ),
        ];
    for (final (schema, valid, invalid, code, parameters) in cases) {
      expect(schema.parseResult(valid).isValid, isTrue);
      for (final result in [
        schema.parseResult(invalid),
        schema.tryParse(invalid),
        await schema.parseResultAsync(invalid),
        await schema.tryParseAsync(invalid),
      ]) {
        expect(result.isValid, isFalse);
        expect(result.value, invalid);
        expect(result.issues.single.code, code);
        expect(result.issues.single.parameters, parameters);
        expect(result.issues.single.message, isNot(code));
      }
    }
    expect(list(integer()).everyOf([1, 2]).parseResult([]).isValid, isTrue);
    expect(list(integer()).anyOf([1, 2]).parseResult([]).isValid, isFalse);
  });

  test(
    'defaults and constraint collections are snapshots on immutable branches',
    () {
      final defaults = <int>[1];
      final allowed = <int>[1, 2];
      final base = list(integer());
      final schema = base.withDefault(defaults).everyOf(allowed).min(2);
      defaults.add(2);
      allowed.clear();
      expect(base.defaultValue, isNull);
      expect(base.checks, isEmpty);
      expect(schema.defaultValue, [1]);
      expect(schema.parseResult(null).issues.single.code, 'minItems');
      expect(schema.tryParse([1, 2]).isValid, isTrue);
      expect(() => schema.defaultValue!.clear(), throwsUnsupportedError);
      expect(() => schema.checks.clear(), throwsUnsupportedError);
      expect(
        () => (schema.checks.first as EveryOfListCheck<int>).items.clear(),
        throwsUnsupportedError,
      );
      expect(
        list(integer().positive())
            .withDefault([-1])
            .parseResult(null)
            .issues
            .single
            .path,
        [0],
      );
    },
  );

  test('operations execute in declaration order and stop at failed transform boundaries', () {
    final seen = <List<int>>[];
    final schema = list(integer())
        .transform((v) => [...v, 2])
        .refine(
          onCheck: (v) {
            seen.add(v);
            return v.length == 2;
          },
        )
        .length(2);
    expect(schema.parseResult([1]).value, [1, 2]);
    expect(seen, [
      [1, 2],
    ]);
    expect(schema.transformations, hasLength(1));
    expect(() => schema.transformations.clear(), throwsUnsupportedError);
    var transformed = false;
    final failing = list(integer()).min(3).max(0).transform((v) {
      transformed = true;
      return v;
    });
    expect(failing.parseResult([1]).issues.map((i) => i.code), ['minItems']);
    expect(failing.tryParse([1]).issues.map((i) => i.code), [
      'minItems',
      'maxItems',
    ]);
    final childFailure = list(integer().positive())
        .length(2)
        .transform((v) {
          transformed = true;
          return v;
        })
        .tryParse([-1]);
    expect(childFailure.issues.map((i) => i.code), ['positive', 'length']);
    expect(transformed, isFalse);
  });

  test(
    'async checks and transforms use non-null values across every step',
    () async {
      final calls = <String>[];
      final schema = list(integer())
          .withCheck(
            CallbackCheck((v, _) {
              calls.add('sync:$v');
            }),
          )
          .refineAsync(
            CallbackAsyncCheck((v, _) async {
              await Future<void>.value();
              calls.add('async:$v');
            }),
          )
          .transform((v) => [...v, 2])
          .transformAsync(
            CallbackAsyncTransform((v) async {
              await Future<void>.value();
              calls.add('transform:$v');
              return [...v, 3];
            }),
          )
          .length(3);
      expect(schema.isAsync, isTrue);
      expect(() => schema.parseResult([1]), throwsStateError);
      expect(() => schema.tryParse([1]), throwsStateError);
      for (final collect in [false, true]) {
        calls.clear();
        final result = await (collect
            ? schema.tryParseAsync([1])
            : schema.parseResultAsync([1]));
        final List<int> output = result.value;
        expect(result.isValid, isTrue);
        expect(output, [1, 2, 3]);
        expect(calls, ['sync:[1]', 'async:[1]', 'transform:[1, 2]']);
      }
      expect(await schema.validateAsync([1]), isTrue);
      expect(await schema.tryValidateAsync([1]), isTrue);
    },
  );

  test('async children run sequentially and propagate nested failures and missing recovery', () async {
    final seen = <int>[];
    final schema = list(
      integer().refineAsync(
        CallbackAsyncCheck((v, context) async {
          await Future<void>.value();
          seen.add(v);
          if (v < 0) context.addIssue('remote', path: ['child']);
        }),
      ),
    ).length(3);
    expect(schema.isAsync, isTrue);
    expect(() => schema.parseResult([1]), throwsStateError);
    final first = await schema.parseResultAsync([-1, -2, 3]);
    expect(seen, [-1]);
    expect(first.issues.single.path, [0, 'child']);
    seen.clear();
    final all = await schema.tryParseAsync([-1, -2, 3]);
    expect(seen, [-1, -2, 3]);
    expect(all.issues.map((i) => i.path), [
      [0, 'child'],
      [1, 'child'],
    ]);
    final missing = await schema.tryParseAsync(<Object?>[
      -1,
      'bad',
      3,
    ]) as AcanthisInvalid<List<int>>;
    expect(missing.hasValue, isFalse);
    expect(missing.issues.map((i) => i.path), [
      [0, 'child'],
      [1],
    ]);
  });

  test('concurrent async invocations isolate contexts and gate transforms after failures', () async {
    var transforms = 0;
    final schema = list(integer())
        .refineAsync(
          CallbackAsyncCheck((v, context) async {
            await Future<void>.value();
            if (v.first < 0) context.addIssue('remote', path: [0]);
          }),
        )
        .min(2)
        .transformAsync(
          CallbackAsyncTransform((v) async {
            transforms++;
            return [...v, 3];
          }),
        );
    final results = await Future.wait([
      schema.tryParseAsync([-1]),
      schema.tryParseAsync([1, 2]),
    ]);
    expect(results.first.issues.map((i) => i.code), ['remote', 'minItems']);
    expect(results.first.issues.first.path, [0]);
    expect(results.first.value, [-1]);
    expect(results.last.isValid, isTrue);
    expect(results.last.value, [1, 2, 3]);
    expect(transforms, 1);
  });

  test(
    'callback programming errors propagate and wrong inputs skip callbacks',
    () async {
      final error = StateError('callback');
      final schema = list(integer()).transform((_) => throw error);
      expect(() => schema.parseResult([1]), throwsA(same(error)));
      expect(schema.tryParse('bad').isValid, isFalse);
      final asyncSchema = list(integer())
          .transformAsync(CallbackAsyncTransform((_) async => throw error));
      await expectLater(
        asyncSchema.parseResultAsync([1]),
        throwsA(same(error)),
      );
      expect((await asyncSchema.tryParseAsync('bad')).isValid, isFalse);
    },
  );
}
