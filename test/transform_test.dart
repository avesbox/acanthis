import 'support/parse_result.dart';

import 'package:acanthis/acanthis.dart';
import 'package:acanthis/acanthis.dart' as acanthis;
import 'package:test/test.dart';

void main() {
  test(
    'direct transform callbacks work through every parsing entry point',
    () async {
      final schema = acanthis.number().transform((value) => value * 3);
      for (final result in [
        schema.parseResult(4),
        schema.tryParse(4),
        await schema.parseResultAsync(4),
        await schema.tryParseAsync(4),
      ]) {
        expect(result.isValid, isTrue);
        expect(result.value, 12);
      }
    },
  );

  test(
    'callbacks retain fluent types, settings and immutable introspection',
    () {
      var calls = 0;
      final AcanthisInt whole = integer().coerce().withDefault(2).transform((
        value,
      ) {
        calls++;
        return value * 3;
      }).positive();
      final AcanthisDouble decimal = doubleType()
          .transform((value) => value * 3)
          .finite();
      final AcanthisString text = string()
          .trim()
          .transform((value) => '$value!')
          .min(2);
      expect(whole.transformations, hasLength(1));
      expect(calls, 0);
      expect(() => whole.transformations.clear(), throwsUnsupportedError);
      expect(whole.parseResult('4').value, 12);
      expect(whole.parseResult(null).value, 6);
      expect(calls, 2);
      expect(decimal.parseResult(1.5).value, 4.5);
      expect(text.parseResult(' abc ').value, 'abc!');
      final TransformableSchema<num, num> abstraction = number();
      expect(
        abstraction.transform((value) => value * 3).parseResult(4).value,
        12,
      );
    },
  );

  test(
    'checks gate callbacks and later failures recover the transformed value',
    () async {
      var calls = 0;
      final schema = integer()
          .gte(1)
          .transform((value) {
            calls++;
            return value * 3;
          })
          .gte(10);
      for (final result in [
        schema.parseResult(0),
        schema.tryParse(0),
        await schema.parseResultAsync(0),
        await schema.tryParseAsync(0),
      ]) {
        expect(result.isValid, isFalse);
        expect(result.value, 0);
        expect(result.issues.single.parameters['value'], 1);
      }
      expect(calls, 0);
      final result = schema.tryParse(2);
      expect(calls, 1);
      expect(result.value, 6);
      expect(result.issues.single.parameters['value'], 10);
      schema.parseResult('2');
      expect(calls, 1);
    },
  );

  test(
    'callback exceptions propagate through sync and async entry points',
    () async {
      final failure = StateError('transform failed');
      final schema = number().transform((value) => throw failure);
      expect(() => schema.parseResult(1), throwsA(same(failure)));
      expect(() => schema.tryParse(1), throwsA(same(failure)));
      await expectLater(schema.parseResultAsync(1), throwsA(same(failure)));
      await expectLater(schema.tryParseAsync(1), throwsA(same(failure)));
    },
  );

  test(
    'callback and object transformations compose with built-in operations',
    () {
      final schema = integer()
          .refine(onCheck: (value) => value == 1, error: 'Value must be 1')
          .transform((value) => value * 3)
          .withTransform(CallbackTransform<int, int>((value) => value + 1))
          .pow(2);
      expect(schema.parseResult(1).value, 16);
      expect(schema.parseResult(2).issues.single.message, 'Value must be 1');
      expect(
        integer()
            .withTransform(const PowerNumberTransform<int>(-1))
            .parseResult(2)
            .issues
            .single
            .code,
        'transform',
      );
      final encoded = string().transform((value) => '$value!').encode();
      expect(
        string().decode().parseResult(encoded.parseResult('hello').value).value,
        'hello!',
      );
      final TransformableSchema<String, String> abstraction = string();
      expect(
        abstraction
            .withTransform(const UpperCaseStringTransform())
            .parseResult('a')
            .value,
        'A',
      );
    },
  );
}
