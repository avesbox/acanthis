import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'literal factories preserve their exact output type, including null',
    () async {
      final String text = literal('ok').parse('ok');
      final int count = Acanthis.literal(1).parse(1);
      final bool flag = AcanthisType.literal(false).parse(false);
      final Null nothing = literal(null).parse(null);
      expect([text, count, flag, nothing], ['ok', 1, false, null]);
      expect(await AcanthisLiteral('ok').parseAsync('ok'), 'ok');
      expect(literal(null).validate(null), isTrue);
      expect(literal(null).validate('null'), isFalse);
      expect(literal(1).validate(1.0), isFalse);
      expect(literal<num>(1).parse(1.0), 1.0);
      expect(literal<double>(1.0).validate(1), isFalse);
    },
  );

  test('literal mismatch has typed recovery while wrong types do not', () {
    final schema = literal('ok');
    final mismatch = schema.tryParse('other') as AcanthisInvalid<String>;
    expect(mismatch.hasValue, isTrue);
    expect(mismatch.value, 'other');
    expect(mismatch.issues.single.code, 'literal');
    expect(mismatch.issues.single.parameters, {'expected': 'ok'});
    expect((schema.tryParse(1) as AcanthisInvalid<String>).hasValue, isFalse);
    expect(() => schema.parse('other'), throwsA(isA<ValidationError>()));
  });

  test(
    'Dart equality and identity are preserved without structural coercion',
    () {
      final value = <int>[1];
      final schema = literal(value);
      expect(schema.parse(value), same(value));
      expect(schema.validate(<int>[1]), isFalse);
      expect(literal(double.nan).validate(double.nan), isFalse);
    },
  );

  test(
    'literal checks and transformations work consistently sync and async',
    () async {
      var calls = 0;
      final schema = literal('ok')
          .transform((value) {
            calls++;
            return value.toUpperCase();
          })
          .refine(onCheck: (value) => value == 'OK');
      expect(schema.parse('ok'), 'OK');
      expect(await schema.parseAsync('ok'), 'OK');
      expect(calls, 2);
      expect(() => schema.checks.clear(), throwsUnsupportedError);
      final asyncSchema = literal('ok')
          .refineAsync(CallbackAsyncCheck((_, _) async {}))
          .transformAsync(CallbackAsyncTransform((value) async => '$value!'));
      expect(() => asyncSchema.parse('ok'), throwsStateError);
      expect(await asyncSchema.parseAsync('ok'), 'ok!');
      expect((await asyncSchema.tryParseAsync('no')).isValid, isFalse);
    },
  );

  test(
    'defaults are validated and explicit null defaults materialize fields',
    () {
      expect(literal('ok').withDefault('ok').parse(null), 'ok');
      expect(literal('ok').withDefault('bad').validate(null), isFalse);
      final schema = object({'n': literal(null)});
      expect(schema.validate({}), isFalse);
      expect(schema.parse({'n': null}), {'n': null});
      expect(object({'n': literal(null).withDefault(null)}).parse({}), {
        'n': null,
      });
      final input = <String>['ok'];
      expect(literal('ok').list().parse(input), same(input));
      expect(literal('ok').nullable().parse(null), isNull);
    },
  );
}
