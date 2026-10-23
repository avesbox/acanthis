import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'parse returns statically typed raw values after transforms and defaults',
    () {
      final String text = string().trim().parse(' Ada ');
      final num amount = number().coerce().parse('2.5');
      final int count = integer().withDefault(3).parse(null);
      final double ratio = doubleType().coerce().parse('0.5');
      final List<int> items = list(integer().coerce()).parse(['1', 2]);
      final Map<String, Object?> user = object({'name': string()})
          .parse({'name': text});
      final Map<String, int> counts = record(
        string().trim(),
        integer().coerce(),
      ).parse({' a ': '2'});
      expect(
        [text, amount, count, ratio, items, user, counts],
        [
          'Ada',
          2.5,
          3,
          0.5,
          [1, 2],
          {'name': 'Ada'},
          {'a': 2},
        ],
      );
    },
  );

  final cases =
      <
        ({
          String name,
          Schema<Object?, Object?> schema,
          Object? valid,
          Object? invalid,
        })
      >[
        (name: 'string', schema: string().min(2), valid: 'ok', invalid: ''),
        (name: 'number', schema: number().lt(5), valid: 1, invalid: 9),
        (name: 'integer', schema: integer().positive(), valid: 1, invalid: -1),
        (name: 'boolean', schema: boolean(), valid: false, invalid: 1),
        (
          name: 'nullable',
          schema: string().nullable(),
          valid: null,
          invalid: 1,
        ),
        (name: 'literal', schema: literal('ok'), valid: 'ok', invalid: 'bad'),
        (
          name: 'double',
          schema: doubleType().finite(),
          valid: 1.5,
          invalid: double.nan,
        ),
        (
          name: 'list',
          schema: list(integer().positive()),
          valid: <int>[1],
          invalid: [-1, -2],
        ),
        (
          name: 'object',
          schema: object({'name': string().min(2)}),
          valid: {'name': 'ok'},
          invalid: {'name': ''},
        ),
        (
          name: 'record',
          schema: record(string().min(2), integer().positive()),
          valid: <String, int>{'ok': 1},
          invalid: {'a': -1},
        ),
        (
          name: 'JSON contract',
          schema: fromJsonSchema({
            'enum': ['ok'],
          }),
          valid: 'ok',
          invalid: false,
        ),
      ];
  for (final item in cases) {
    test(
      '${item.name} raw sync/async parses throw and validation stays boolean',
      () async {
        final schema = item.schema;
        final asyncSchema = schema as AsyncSchema<Object?, Object?>;
        final checks = schema as ValidationSchema<Object?, Object?>;
        expect(schema.parse(item.valid), item.valid);
        expect(await asyncSchema.parseAsync(item.valid), item.valid);
        expect(schema.parse(item.valid), isNot(isA<AcanthisOutcome>()));
        final failure = isA<ValidationError>().having(
          (error) => error.issues.length,
          'first issue only',
          1,
        );
        expect(() => schema.parse(item.invalid), throwsA(failure));
        await expectLater(
          asyncSchema.parseAsync(item.invalid),
          throwsA(failure),
        );
        expect(checks.validate(item.valid), isTrue);
        expect(checks.validate(item.invalid), isFalse);
        expect(checks.tryValidate(item.invalid), isFalse);
        expect(schema.tryParse(item.invalid), isA<AcanthisInvalid>());
        expect(
          await asyncSchema.tryParseAsync(item.invalid),
          isA<AcanthisInvalid>(),
        );
      },
    );
  }

  test('an invalid outcome with recovery still throws instead of returning recovery', () {
    final schema = integer().positive();
    expect((schema.tryParse(-1) as AcanthisInvalid<int>).value, -1);
    expect(
      () => schema.parse(-1),
      throwsA(
        isA<ValidationError>()
            .having(
              (error) => error.failure.hasValue,
              'recovery retained',
              isTrue,
            )
            .having((error) => error.failure.value, 'recovery value', -1),
      ),
    );
    expect(
      () => schema.parse('bad'),
      throwsA(
        isA<ValidationError>().having(
          (error) => error.failure.hasValue,
          'no typed recovery',
          isFalse,
        ),
      ),
    );
  });

  test(
    'throwing nested failures expose immutable issues with complete paths',
    () {
      final schema = object({
        'items': list(object({'n': integer().positive()})),
      });
      try {
        schema.parse({
          'items': [
            {'n': -1},
          ],
        });
        fail('An invalid parse returned a value');
      } on ValidationError catch (error) {
        expect(error.issue!.path, ['items', 0, 'n']);
        expect(error.issue!.code, 'positive');
        expect(error.message, isNotEmpty);
        expect(error.toString(), startsWith('ValidationError: '));
        expect(() => error.issues.clear(), throwsUnsupportedError);
      }
    },
  );

  test('successful throwing parses retain input map and list reuse', () async {
    final input = <String, Object?>{'n': 1};
    final schema = object({'n': integer()});
    expect(schema.parse(input), same(input));
    expect(await schema.parseAsync(input), same(input));
    final values = <Map<String, Object?>>[input];
    expect(list(schema).parse(values), same(values));
  });

  test(
    'imported contracts can return null and false as valid raw values',
    () async {
      final schema = fromJsonSchema(true);
      expect(schema.parse(null), isNull);
      expect(await schema.parseAsync(null), isNull);
      expect(schema.parse(false), isFalse);
      expect(schema.validate(null), isTrue);
      expect(await schema.validateAsync(null), isTrue);
      expect(await fromJsonSchema(false).validateAsync(null), isFalse);
    },
  );

  test(
    'lazy public entry points and recursive raw parsing preserve failures',
    () async {
      final parent = object({});
      final entry = lazy((_) => integer().positive());
      final int parsed = entry.parse(2, parent);
      final int asyncParsed = await entry.parseAsync(2, parent);
      expect([parsed, asyncParsed], [2, 2]);
      expect(entry.validate(-1, parent), isFalse);
      expect(await entry.validateAsync(-1, parent), isFalse);
      expect(() => entry.parse(-1, parent), throwsA(isA<ValidationError>()));
      final tree = object({
        'n': integer().positive(),
        'children': lazy((parent) => parent.list()),
      });
      final input = <String, Object?>{
        'n': 1,
        'children': <Map<String, Object?>>[],
      };
      expect(tree.parse(input), same(input));
    },
  );

  test('fail-fast raw parsing skips callbacks and tryParse still collects', () {
    var calls = 0;
    final schema = object({
      'first': integer().positive(),
      'later': integer().refine(
        onCheck: (_) {
          calls++;
          return false;
        },
      ),
    });
    expect(
      () => schema.parse({'first': -1, 'later': 1}),
      throwsA(isA<ValidationError>()),
    );
    expect(calls, 0);
    expect(schema.validate({'first': -1, 'later': 1}), isFalse);
    expect(calls, 0);
    expect(schema.tryParse({'first': -1, 'later': 1}).issues, hasLength(2));
    expect(calls, 1);
  });

  test(
    'callback errors propagate unchanged, including callback ValidationErrors',
    () async {
      for (final error in [
        StateError('callback'),
        ValidationError(
          AcanthisInvalid.withoutValue([
            AcanthisIssue(path: [], code: 'callback'),
          ]),
        ),
      ]) {
        final schema = object({'n': integer().transform((_) => throw error)});
        expect(() => schema.parse({'n': 1}), throwsA(same(error)));
        expect(() => schema.validate({'n': 1}), throwsA(same(error)));
        expect(() => schema.tryParse({'n': 1}), throwsA(same(error)));
        final asyncSchema = integer().refineAsync(
          CallbackAsyncCheck((_, _) async => throw error),
        );
        await expectLater(asyncSchema.parseAsync(1), throwsA(same(error)));
        await expectLater(asyncSchema.validateAsync(1), throwsA(same(error)));
      }
    },
  );
}
