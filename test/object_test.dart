import 'support/parse_result.dart';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

// A third-party schema with a valid nullable output, but no default capability.
final class _NullableText extends Schema<Object?, String?> {
  @override
  String? parse(Object? input) => tryParse(input).valueOrThrow;
  @override
  AcanthisOutcome<String?> tryParse(Object? input) =>
      input == null || input is String
      ? AcanthisValid(input as String?)
      : AcanthisInvalid.withoutValue([AcanthisIssue(path: [], code: 'type')]);
}

void main() {
  test('object factories parse heterogeneous named fields through all entry points', () async {
    for (final schema in [
      ObjectSchema({'name': string().trim(), 'age': integer().coerce()}),
      object({'name': string().trim(), 'age': integer().coerce()}),
      Acanthis.object({'name': string().trim(), 'age': integer().coerce()}),
      AcanthisType.object({'name': string().trim(), 'age': integer().coerce()}),
    ]) {
      final input = {'name': ' Ada ', 'age': '42', 'extra': true};
      for (final result in [
        schema.parseResult(input),
        schema.tryParse(input),
        await schema.parseResultAsync(input),
        await schema.tryParseAsync(input),
      ]) {
        final Map<String, Object?> output = result.value;
        expect(result.isValid, isTrue);
        expect(output, {'name': 'Ada', 'age': 42});
      }
      expect(input, {'name': ' Ada ', 'age': '42', 'extra': true});
      expect(schema.validate(input), isTrue);
      expect(schema.tryValidate(input), isTrue);
      expect(await schema.validateAsync(input), isTrue);
      expect(await schema.tryValidateAsync(input), isTrue);
    }
    expect(object({}).parseResult({}).value, isEmpty);
    expect(
      object({'a': integer()}).parseResult(<Object?, Object?>{'a': 1}).value,
      {'a': 1},
    );
  });

  test(
    'objects reject non-maps and non-string keys without recovery',
    () async {
      final schema = object({});
      for (final input in [
        null,
        [],
        1,
        'map',
        {1: 'a'},
      ]) {
        for (final result in [
          schema.parseResult(input),
          await schema.tryParseAsync(input),
        ]) {
          expect(result.isValid, isFalse);
          expect(
            (result as AcanthisInvalid<Map<String, Object?>>).hasValue,
            isFalse,
          );
          expect(result.issues.single.code, 'type');
          expect(result.issues.single.path, isEmpty);
          expect(() => result.value, throwsStateError);
        }
      }
    },
  );

  test('missing required fields are distinct from explicit null and optional omission', () {
    final schema = object({'text': _NullableText(), 'count': integer()});
    final missing = schema.tryParse({'count': 1});
    expect(missing.issues.single.code, 'required');
    expect(missing.issues.single.path, ['text']);
    expect(
      (missing as AcanthisInvalid<Map<String, Object?>>).hasValue,
      isFalse,
    );
    expect(schema.parseResult({'text': null, 'count': 1}).value, {
      'text': null,
      'count': 1,
    });
    final optional = schema.optionals(['text', 'count']);
    expect(optional.parseResult({}).value, isEmpty);
    expect(optional.parseResult({'count': null}).issues.single.code, 'type');
    expect(schema.optionalFields, isEmpty);
    expect(() => schema.optionals(['typo']), throwsArgumentError);
  });

  test(
    'child defaults are validated and partial input preserves omission',
    () async {
      final schema = object({
        'name': string().trim().withDefault(' Ada '),
        'tags': list(integer()).withDefault([1]),
        'nested': object({'count': integer()}).withDefault({'count': 2}),
        'record': record(string(), integer()).withDefault({'a': 3}),
      });
      expect(schema.parseResult({}).value, {
        'name': 'Ada',
        'tags': [1],
        'nested': {'count': 2},
        'record': {'a': 3},
      });
      expect(schema.optionals(['name']).parseResult({}).value['name'], 'Ada');
      expect(schema.partial().parseResult({}).value, isEmpty);
      expect(schema.partial().parseResult({'name': null}).value, {
        'name': 'Ada',
      });
      expect(schema.partial().isOptionalField('name'), isTrue);
      expect(schema.isOptionalField('name'), isFalse);
      final invalid = object({'n': integer().positive().withDefault(-1)});
      expect(invalid.parseResult({}).issues.single.path, ['n']);
      expect(invalid.parseResult({}).issues.single.code, 'positive');
      expect((await invalid.tryParseAsync({})).issues.single.code, 'positive');
    },
  );

  test(
    'unknown keys strip, preserve or reject under both execution modes',
    () async {
      final base = object({'n': integer()});
      final input = {'n': 1, 'x': false, 'y': null};
      expect(base.parseResult(input).value, {'n': 1});
      expect(
        base.unknownKeys(AcanthisUnknownKeys.preserve).parseResult(input).value,
        input,
      );
      final strict = base.unknownKeys(AcanthisUnknownKeys.reject);
      expect(strict.parseResult(input).issues.map((i) => i.path), [
        ['x'],
      ]);
      expect(strict.tryParse(input).issues.map((i) => i.path), [
        ['x'],
        ['y'],
      ]);
      expect((await strict.tryParseAsync(input)).issues.map((i) => i.code), [
        'unknownKey',
        'unknownKey',
      ]);
      expect(
        strict
            .unknownKeys(AcanthisUnknownKeys.strip)
            .parseResult(input)
            .isValid,
        isTrue,
      );
      expect(input, {'n': 1, 'x': false, 'y': null});
    },
  );

  test(
    'object shape and configuration collections are immutable snapshots',
    () {
      final fields = <String, Schema<Object?, Object?>>{'n': integer()};
      final optional = <String>['n'];
      final defaults = <String, Object?>{'n': 1};
      final schema = object(fields)
          .optionals(optional)
          .withDefault(defaults)
          .unknownKeys(AcanthisUnknownKeys.reject)
          .refine(onCheck: (_) => true);
      fields.clear();
      optional.clear();
      defaults.clear();
      expect(schema.fields.keys, ['n']);
      expect(schema.optionalFields, {'n'});
      expect(schema.defaultValue, {'n': 1});
      expect(schema.parseResult(null).value, {'n': 1});
      expect(schema.parseResult({}).value, isEmpty);
      expect(schema.parseResult({'x': 1}).issues.single.code, 'unknownKey');
      expect(() => schema.fields.clear(), throwsUnsupportedError);
      expect(() => schema.optionalFields.clear(), throwsUnsupportedError);
      expect(() => schema.defaultValue!.clear(), throwsUnsupportedError);
      expect(() => schema.checks.clear(), throwsUnsupportedError);
    },
  );

  test('fail-fast skips later children; collecting propagates recovery and nested paths', () {
    var calls = 0;
    final schema = object({
      'a': integer().positive(),
      'b': list(object({'name': string().min(2)})),
      'c': integer().transform((v) {
        calls++;
        return v;
      }),
    });
    final input = {
      'a': -1,
      'b': [
        {'name': 'x'},
      ],
      'c': 3,
    };
    final first = schema.parseResult(input);
    expect(first.issues.single.path, ['a']);
    expect(calls, 0);
    expect((first as AcanthisInvalid<Map<String, Object?>>).hasValue, isFalse);
    final all = schema.tryParse(input) as AcanthisInvalid<Map<String, Object?>>;
    expect(calls, 1);
    expect(all.hasValue, isTrue);
    expect(all.value, input);
    expect(all.issues.map((i) => i.path), [
      ['a'],
      ['b', 0, 'name'],
    ]);
    final noRecovery = schema.tryParse({
      'a': 'bad',
      'b': [],
      'c': 3,
    }) as AcanthisInvalid<Map<String, Object?>>;
    expect(noRecovery.hasValue, isFalse);
    expect(() => noRecovery.value, throwsStateError);
  });

  test('object operations use parsed values and stop at failed transformation boundaries', () async {
    final seen = <Object?>[];
    final base = object({'n': integer().coerce()});
    final schema = base
        .transform((v) => {...v, 'extra': 2})
        .withCheck(
          CallbackCheck((v, _) {
            seen.add(v['n']);
          }),
        )
        .refine(onCheck: (v) => v.length == 2);
    expect(schema.parseResult({'n': '1'}).value, {'n': 1, 'extra': 2});
    expect(seen, [1]);
    expect(base.checks, isEmpty);
    expect(base.transformations, isEmpty);
    expect(() => schema.transformations.clear(), throwsUnsupportedError);
    var transformed = false;
    final failing = base
        .refine(onCheck: (_) => false, name: 'one')
        .refine(onCheck: (_) => false, name: 'two')
        .transform((v) {
          transformed = true;
          return v;
        });
    expect(failing.parseResult({'n': 1}).issues.map((i) => i.code), ['one']);
    expect(failing.tryParse({'n': 1}).issues.map((i) => i.code), [
      'one',
      'two',
    ]);
    expect((await failing.tryParseAsync({'n': 1})).issues.map((i) => i.code), [
      'one',
      'two',
    ]);
    expect(transformed, isFalse);
    var checked = false;
    final childFailure = object({'n': integer().positive()})
        .refine(
          onCheck: (_) {
            checked = true;
            return false;
          },
          name: 'parent',
        )
        .transform((v) {
          transformed = true;
          return v;
        });
    expect(childFailure.tryParse({'n': -1}).issues.map((i) => i.code), [
      'positive',
      'parent',
    ]);
    expect(checked, isTrue);
    expect(transformed, isFalse);
    checked = false;
    expect(childFailure.tryParse({'n': 'bad'}).isValid, isFalse);
    expect(checked, isFalse);
  });

  test('async fields, checks and transforms run sequentially with per-invocation state', () async {
    final calls = <String>[];
    final schema =
        object({
              'a': integer().transformAsync(
                CallbackAsyncTransform((v) async {
                  await Future<void>.value();
                  calls.add('a');
                  return v + 1;
                }),
              ),
              'b': integer().transform((v) {
                calls.add('b');
                return v;
              }),
            })
            .refineAsync(
              CallbackAsyncCheck((v, context) async {
                await Future<void>.value();
                calls.add('check');
                if ((v['a'] as int) < 0) {
                  context.addIssue('remote', path: ['a']);
                }
              }),
            )
            .transform((v) {
              calls.add('sync');
              return v;
            })
            .transformAsync(
              CallbackAsyncTransform((v) async {
                calls.add('transform');
                return {...v, 'done': true};
              }),
            )
            .refine(onCheck: (v) => v['done'] == true);
    expect(schema.isAsync, isTrue);
    expect(() => schema.parseResult({'a': 1, 'b': 2}), throwsStateError);
    expect(() => schema.tryParse({}), throwsStateError);
    for (final collect in [false, true]) {
      calls.clear();
      final result = await (collect
          ? schema.tryParseAsync({'a': 1, 'b': 2})
          : schema.parseResultAsync({'a': 1, 'b': 2}));
      expect(result.isValid, isTrue);
      expect(result.value, {'a': 2, 'b': 2, 'done': true});
      expect(calls, ['a', 'b', 'check', 'sync', 'transform']);
    }
    final results = await Future.wait([
      schema.tryParseAsync({'a': -3, 'b': 2}),
      schema.tryParseAsync({'a': 1, 'b': 2}),
    ]);
    expect(results.first.issues.single.path, ['a']);
    expect(results.first.value, {'a': -2, 'b': 2});
    expect(results.last.isValid, isTrue);
    final missing = await schema.tryParseAsync({'a': 'bad', 'b': 2});
    expect(
      (missing as AcanthisInvalid<Map<String, Object?>>).hasValue,
      isFalse,
    );
    expect(missing.issues.single.path, ['a']);
  });

  test(
    'async omission and unknown-key policy match synchronous semantics',
    () async {
      final child = integer()
          .withDefault(2)
          .refineAsync(CallbackAsyncCheck((_, _) async {}));
      final schema = object({'n': child, 'text': _NullableText()})
          .optionals(['text'])
          .unknownKeys(AcanthisUnknownKeys.reject);
      expect((await schema.parseResultAsync({})).value, {'n': 2});
      expect((await schema.partial().parseResultAsync({})).value, isEmpty);
      expect(
        (await schema.parseResultAsync({'x': 1})).issues.single.code,
        'unknownKey',
      );
      expect(
        (await schema.tryParseAsync({'n': 'bad', 'x': 1})).issues
            .map((i) => i.path),
        [
          ['n'],
          ['x'],
        ],
      );
      expect((await schema.parseResultAsync([])).issues.single.code, 'type');
    },
  );
}
