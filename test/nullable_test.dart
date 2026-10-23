import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

final class _Composed extends Schema<String, String>
    with NullableSchema<String, String>, ListableSchema<String, String> {
  @override
  String parse(Object? input) => tryParse(input).valueOrThrow;
  @override
  AcanthisOutcome<String> tryParse(Object? input) => input is String
      ? AcanthisValid(input)
      : AcanthisInvalid<String>.withoutValue([
          AcanthisIssue(path: [], code: 'type'),
        ]);
}

final class _ReverseComposed extends Schema<String, String>
    with ListableSchema<String, String>, NullableSchema<String, String> {
  @override
  String parse(Object? input) => input as String;
  @override
  AcanthisOutcome<String> tryParse(Object? input) =>
      AcanthisValid(parse(input));
}

void main() {
  test(
    'nullable is a composable mixin, with both list/nullable nesting orders',
    () {
      for (final schema in <Schema<String, String>>[
        _Composed(),
        _ReverseComposed(),
      ]) {
        final AcanthisNullable<String> wrapped = schema.nullable();
        final String? value = wrapped.parse(null);
        expect(value, isNull);
        expect(wrapped.unwrap(), same(schema));
        final List<String?> values = wrapped.list().parse(<String?>[
          'ok',
          null,
        ]);
        expect(values, ['ok', null]);
        final List<String>? nullableList = schema.list().nullable().parse(null);
        expect(nullableList, isNull);
        expect(schema.nullable().list().nullable().parse(<String?>[null]), [
          null,
        ]);
      }
      expect(_Composed().nullable().parse('ok'), 'ok');
      expect(_Composed().list().parse(['ok']), ['ok']);
      expect(_ReverseComposed().nullable().parse(null), isNull);
    },
  );

  test(
    'factories, facade and static Schema composition retain output types',
    () async {
      final element = integer().positive();
      for (final schema in [
        nullable(element),
        AcanthisNullable(element),
        Acanthis.nullable(element),
        AcanthisType.nullable(element),
        element.nullable(),
      ]) {
        final int? value = schema.parse(1);
        final int? asyncValue = await schema.parseAsync(null);
        expect(value, 1);
        expect(asyncValue, isNull);
        expect(schema.validate(null), isTrue);
        expect(schema.validate(-1), isFalse);
        expect(schema.tryParse(-1).value, -1);
        expect(
          (schema.tryParse('1') as AcanthisInvalid<int?>).hasValue,
          isFalse,
        );
      }
      expect(fromJsonSchema({'type': 'string'}).nullable().parse(null), isNull);
    },
  );

  test(
    'null skips child checks but still executes wrapper operations in order',
    () {
      var children = 0;
      final seen = <Object?>[];
      final schema = string()
          .refine(
            onCheck: (_) {
              children++;
              return true;
            },
          )
          .nullable()
          .refine(
            onCheck: (value) {
              seen.add(value);
              return true;
            },
          )
          .transform((value) => value ?? 'fallback');
      expect(schema.parse(null), 'fallback');
      expect(children, 0);
      expect(seen, [null]);
      expect(schema.parse('ok'), 'ok');
      expect(children, 1);
      expect(seen, [null, 'ok']);
    },
  );

  test('inherited defaults and explicit null override remain distinct', () {
    final base = string().withDefault('child');
    expect(base.nullable().parse(null), 'child');
    expect(base.nullable(defaultValue: 'wrapper').parse(null), 'wrapper');
    final explicit = base.nullable().withDefault(null);
    expect(explicit.hasDefault, isTrue);
    expect(explicit.defaultValue, isNull);
    expect(explicit.parse(null), isNull);
    expect(explicit.refine(onCheck: (_) => true).parse(null), isNull);
    expect(explicit.unwrap(), same(base));
    expect(string().min(3).nullable(defaultValue: 'x').validate(null), isFalse);
    final noDefault = string().nullable();
    expect(noDefault.hasDefault, isFalse);
    expect(noDefault.defaultValue, isNull);
  });

  test(
    'nullable fields still require presence; defaults fill and partial omits',
    () {
      final schema = object({'n': integer().nullable()});
      expect(schema.validate({}), isFalse);
      expect(schema.tryParse({}).issues.single.code, 'required');
      expect(schema.parse({'n': null}), {'n': null});
      expect(schema.optionals(['n']).parse({}), isEmpty);
      final defaulted = object({'n': integer().nullable().withDefault(null)});
      expect(defaulted.parse({}), {'n': null});
      expect(defaulted.partial().parse({}), isEmpty);
      expect(object({'n': integer().withDefault(1).nullable()}).parse({}), {
        'n': 1,
      });
    },
  );

  test('nullable enumeration snapshots its values and always admits null', () {
    final values = <num?>[1, 2];
    final schema = number().nullable().enumerated(values);
    values.clear();
    expect(schema.parse(null), isNull);
    expect(schema.parse(1), 1);
    expect(schema.validate(3), isFalse);
    expect(schema.tryParse(3).issues.single.code, 'enumerated');
    expect(
      schema.tryParse(3).issues.single.parameters['values'],
      containsAll([1, 2, null]),
    );
    expect(
      () => (schema.checks.single as EnumeratedNullableCheck).values.clear(),
      throwsUnsupportedError,
    );
    expect(number().nullable().enumerated([]).validate(1), isFalse);
  });

  test(
    'failed children preserve typed recovery and block later transformations',
    () {
      var transformed = 0;
      final schema = integer()
          .positive()
          .nullable()
          .refine(onCheck: (_) => false)
          .transform((value) {
            transformed++;
            return value;
          });
      final failed = schema.tryParse(-1) as AcanthisInvalid<int?>;
      expect(failed.value, -1);
      expect(failed.issues.map((issue) => issue.code), ['positive', 'custom']);
      expect(transformed, 0);
      expect(
        () => schema.parse(-1),
        throwsA(
          isA<ValidationError>().having(
            (error) => error.issues.map((issue) => issue.code).toList(),
            'fail fast',
            ['positive'],
          ),
        ),
      );
      expect(
        (schema.tryParse('bad') as AcanthisInvalid<int?>).hasValue,
        isFalse,
      );
      expect(transformed, 0);
    },
  );

  test(
    'async child eligibility is preserved even when the input is null',
    () async {
      var calls = 0;
      final schema = string()
          .refineAsync(
            CallbackAsyncCheck((_, _) async {
              calls++;
            }),
          )
          .nullable();
      expect(() => schema.parse(null), throwsStateError);
      expect(() => schema.validate(null), throwsStateError);
      expect(calls, 0);
      expect(await schema.parseAsync(null), isNull);
      expect(calls, 0);
      expect(await schema.parseAsync('ok'), 'ok');
      expect(calls, 1);
      expect(await schema.validateAsync(null), isTrue);
    },
  );

  test(
    'async wrapper operations run on null and retain callback failures',
    () async {
      final seen = <String?>[];
      final schema = string()
          .nullable()
          .refineAsync(
            CallbackAsyncCheck((value, context) async {
              seen.add(value);
              if (value == 'bad') context.addIssue('bad');
            }),
          )
          .transformAsync(
            CallbackAsyncTransform((value) async => value ?? 'default'),
          );
      expect(await schema.parseAsync(null), 'default');
      expect((await schema.tryParseAsync('bad')).value, 'bad');
      expect(seen, [null, 'bad']);
      final error = StateError('callback');
      expect(
        () =>
            string().nullable().refine(onCheck: (_) => throw error).parse(null),
        throwsA(same(error)),
      );
      final asyncError = schema.refineAsync(
        CallbackAsyncCheck((_, _) async => throw error),
      );
      await expectLater(asyncError.parseAsync(null), throwsA(same(error)));
    },
  );

  test(
    'container identity is reused and nested paths still identify failures',
    () {
      final child = object({'n': integer()});
      final schema = child.nullable();
      final input = <String, Object?>{'n': 1};
      expect(schema.parse(input), same(input));
      final values = <Map<String, Object?>?>[null, input];
      expect(schema.list().parse(values), same(values));
      final parent = object({'child': child.nullable()});
      final raw = <String, Object?>{'child': null};
      expect(parent.parse(raw), same(raw));
      expect(
        parent
            .tryParse({
              'child': {'n': 'bad'},
            })
            .issues
            .single
            .path,
        ['child', 'n'],
      );
      expect(
        record(string(), integer().nullable()).parse(<String, int?>{'a': null}),
        {'a': null},
      );
    },
  );

  test(
    'recursive nullable lazy fields resolve without hiding async descendants',
    () async {
      var resolutions = 0;
      final schema = object({
        'n': integer(),
        'next': lazy((parent) {
          resolutions++;
          return parent.nullable();
        }),
      });
      final input = <String, Object?>{
        'n': 1,
        'next': <String, Object?>{'n': 2, 'next': null},
      };
      expect(schema.parse(input), same(input));
      expect(schema.parse(input), same(input));
      expect(resolutions, 1);
      final asyncSchema = object({
        'n': integer().refineAsync(CallbackAsyncCheck((_, _) async {})),
        'next': lazy((parent) => parent.nullable()),
      });
      expect(() => asyncSchema.parse({'n': 1, 'next': null}), throwsStateError);
      expect(await asyncSchema.parseAsync({'n': 1, 'next': null}), {
        'n': 1,
        'next': null,
      });
    },
  );

  test('nullable-only lazy alias cycles fail during resolution', () {
    late LazyEntry<Object?> entry;
    entry = lazy((parent) => entry.call(parent).nullable());
    final schema = object({'value': entry});
    expect(() => schema.parse({'value': 1}), throwsStateError);
  });
}
