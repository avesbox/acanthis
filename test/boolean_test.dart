import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'boolean factories retain typed raw, outcome and boolean APIs',
    () async {
      for (final schema in [
        boolean(),
        AcanthisBoolean(),
        Acanthis.boolean(),
        AcanthisType.boolean(),
      ]) {
        for (final input in [true, false]) {
          final bool parsed = schema.parse(input);
          final bool asyncParsed = await schema.parseAsync(input);
          expect([parsed, asyncParsed], [input, input]);
          expect(schema.tryParse(input).value, input);
          expect(schema.validate(input), isTrue);
          expect(await schema.tryValidateAsync(input), isTrue);
        }
        for (final input in <Object?>[null, 0, 1, 'true', '', [], {}]) {
          expect(schema.validate(input), isFalse);
          expect(() => schema.parse(input), throwsA(isA<ValidationError>()));
          final failure = schema.tryParse(input) as AcanthisInvalid<bool>;
          expect(failure.hasValue, isFalse);
          expect(failure.issues.single.code, 'type');
        }
      }
    },
  );

  test(
    'boolean coercion matches V1 scalar conversions and rejects truthiness',
    () {
      final schema = boolean().coerce();
      for (final value in <Object>[true, 1, 1.0, 'true', ' TRUE ', '1']) {
        expect(schema.parse(value), isTrue);
      }
      for (final value in <Object>[false, 0, -0.0, 'false', ' FALSE ', '0']) {
        expect(schema.parse(value), isFalse);
      }
      for (final value in <Object?>[
        null,
        2,
        -1,
        0.5,
        double.nan,
        double.infinity,
        '',
        'yes',
        'no',
        'on',
        'off',
        [],
        {},
      ]) {
        expect(schema.validate(value), isFalse, reason: '$value');
      }
      expect(boolean().withDefault(false).parse(null), isFalse);
      expect(boolean().coerce().withDefault(true).parse(null), isTrue);
      expect(boolean().isTrue().withDefault(false).validate(null), isFalse);
    },
  );

  test('checks and transformations execute once in order, preserving false recovery', () {
    var transforms = 0;
    final schema = boolean().isTrue().isFalse().isTrue().transform((value) {
      transforms++;
      return !value;
    });
    final failure = schema.tryParse(false) as AcanthisInvalid<bool>;
    expect(failure.value, isFalse);
    expect(failure.issues.map((issue) => issue.code), ['isTrue', 'isTrue']);
    expect(transforms, 0);
    try {
      schema.parse(false);
      fail('Expected failure');
    } on ValidationError catch (error) {
      expect(error.issues, hasLength(1));
    }
    expect(
      boolean().transform((value) => !value).isTrue().parse(false),
      isTrue,
    );
    expect(boolean().isFalse().validate(true), isFalse);
    expect(
      boolean().isTrue().tryParse(false).issues.single.message,
      'Value must be true',
    );
  });

  test(
    'async checks reject sync use before callbacks and keep contexts local',
    () async {
      var calls = 0;
      final schema = boolean()
          .refineAsync(
            CallbackAsyncCheck((value, context) async {
              calls++;
              await Future<void>.delayed(Duration.zero);
              if (!value) context.addIssue('falseValue');
            }),
          )
          .transformAsync(CallbackAsyncTransform((value) async => !value));
      expect(() => schema.parse(true), throwsStateError);
      expect(() => schema.validate(false), throwsStateError);
      expect(calls, 0);
      final results = await Future.wait([
        schema.tryParseAsync(false),
        schema.tryParseAsync(true),
      ]);
      expect(results[0].issues.single.code, 'falseValue');
      expect(results[0].value, isFalse);
      expect(results[1].value, isFalse);
      expect(results[1].isValid, isTrue);
      expect(calls, 2);
    },
  );

  test('definitions, defaults and operation lists are immutable', () {
    final base = boolean();
    final checked = base.isTrue().withDefault(true);
    expect(base.parse(false), isFalse);
    expect(checked.validate(false), isFalse);
    expect(checked.parse(null), isTrue);
    expect(() => checked.checks.clear(), throwsUnsupportedError);
    final error = StateError('callback');
    expect(
      () => base.refine(onCheck: (_) => throw error).parse(true),
      throwsA(same(error)),
    );
  });

  test(
    'boolean native object/list fast paths preserve false and container reuse',
    () {
      for (final count in [1, 3, 4, 32]) {
        final schema = object({
          for (var i = 0; i < count; i++) 'b$i': boolean(),
        });
        final input = <String, Object?>{
          for (var i = 0; i < count; i++) 'b$i': i.isEven,
        };
        expect(schema.parse(input), same(input));
      }
      final input = <bool>[false, true];
      expect(list(boolean()).parse(input), same(input));
      expect(
        object({'b': boolean().isTrue()})
            .tryParse({'b': false})
            .issues
            .single
            .path,
        ['b'],
      );
      expect(boolean().nullable().list().parse(<bool?>[null, false]), [
        null,
        false,
      ]);
    },
  );

  test('long boolean operation chains execute iteratively', () {
    var schema = boolean();
    for (var i = 0; i < 5000; i++) {
      schema = schema.isTrue();
    }
    expect(schema.parse(true), isTrue);
    expect(schema.tryParse(false).issues, hasLength(5000));
  });
}
