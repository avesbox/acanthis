import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  group('validateAsync', () {
    test(
      'returns nullable messages for synchronous and async schemas',
      () async {
        expect(await string().validateAsync('Ada'), isNull);
        expect(await string().nullable().validateAsync(null), isNull);
        expect(
          await string().min(3, message: 'Too short').validateAsync('x'),
          'Too short',
        );
        var calls = 0;
        final schema = string()
            .transform((value) => value.trim())
            .refineAsync(
              onCheck: (value) async {
                calls++;
                return value == 'Ada';
              },
              name: 'available',
              error: 'Unavailable',
            );
        final Future<String?> valid = schema.validateAsync(' Ada ');
        expect(await valid, isNull);
        expect(await schema.validateAsync('Bob'), 'Unavailable');
        expect(calls, 2);
      },
    );

    test('stops after the first failure and returns child messages', () async {
      var calls = 0;
      final schema = string()
          .min(3, message: 'Too short')
          .refineAsync(
            onCheck: (_) async {
              calls++;
              return false;
            },
            name: 'remote',
            error: 'Unavailable',
          );
      expect(
        await object({'name': schema}).validateAsync({'name': 'x'}),
        'Too short',
      );
      expect(calls, 0);
      expect(await schema.list().validateAsync(['Ada']), 'Unavailable');
      expect(calls, 1);
    });

    test(
      'propagates uncaught exceptions, including through async unions',
      () async {
        final error = StateError('Transformation failed');
        final schema = string()
            .refineAsync(onCheck: (_) async => true, name: 'pass', error: '')
            .transform((_) => throw error);
        await expectLater(schema.validateAsync('Ada'), throwsA(same(error)));
        await expectLater(
          union<String>([schema]).validateAsync('Ada'),
          throwsA(same(error)),
        );
        await expectLater(
          string().validateAsync(null),
          throwsA(isA<TypeError>()),
        );
      },
    );
  });

  group('validate', () {
    test('returns null for valid scalar and composite input', () {
      expect(string().validate(''), isNull);
      expect(string().email().validate('ada@example.com'), isNull);
      expect(integer().gte(18).validate(18), isNull);
      expect(object({'name': string()}).validate({'name': 'Ada'}), isNull);
      expect(string().list().validate(['Ada']), isNull);
    });

    test('returns the first message and stops subsequent operations', () {
      var calls = 0;
      final schema = string()
          .min(3, message: 'Too short')
          .refine(
            onCheck: (_) {
              calls++;
              return false;
            },
            name: 'later',
            error: 'Later failure',
          );
      expect(schema.validate('a'), 'Too short');
      expect(calls, 0);
      expect(schema.validate('abc'), 'Later failure');
      expect(calls, 1);
    });

    test('preserves default, custom, and generated messages', () {
      final schema = string().email();
      expect(
        schema.validate('bad'),
        schema.tryParse('bad').issues.single.message,
      );
      expect(
        string().email(message: 'Invalid email').validate('bad'),
        'Invalid email',
      );
      expect(
        string().min(3, messageBuilder: (n) => 'At least $n').validate('x'),
        'At least 3',
      );
    });

    test('supports the nullable Flutter validator callback signature', () {
      final schema = string()
          .notEmpty(message: 'Enter your email')
          .email(message: 'Invalid email');
      final String? Function(String?) direct = schema.validate;
      String? validator(String? value) => schema.validate(value ?? '');
      expect(direct('ada@example.com'), isNull);
      expect(validator(null), 'Enter your email');
      expect(validator(''), 'Enter your email');
      expect(validator('bad'), 'Invalid email');
      expect(validator('ada@example.com'), isNull);
    });

    test('respects nullability and validates defaults', () {
      expect(string().nullable().validate(null), isNull);
      expect(string().min(3).withDefault('Ada').validate(null), isNull);
      expect(
        string().min(3, message: 'Too short').withDefault('x').validate(null),
        'Too short',
      );
    });

    test('runs coercion and transformations before downstream checks', () {
      expect(string().coerce().min(2).validate(42), isNull);
      final schema = string()
          .transform((value) => value.trim())
          .refine(
            onCheck: (value) => value == 'Ada',
            name: 'name',
            error: 'Unknown name',
          );
      expect(schema.validate(' Ada '), isNull);
      expect(schema.validate(' Bob '), 'Unknown name');
    });

    test('returns nested object and list validation messages', () {
      final email = string().email(message: 'Invalid email');
      expect(
        object({'email': email}).validate({'email': 'bad'}),
        'Invalid email',
      );
      expect(
        email.list().validate(['ada@example.com', 'bad']),
        'Invalid email',
      );
    });

    test('does not retain errors between calls', () {
      final schema = string().email(message: 'Invalid email');
      expect(schema.validate('bad'), 'Invalid email');
      expect(schema.validate('ada@example.com'), isNull);
      expect(schema.validate('bad'), 'Invalid email');
    });

    test('propagates type errors for incompatible non-nullable inputs', () {
      expect(() => string().validate(null), throwsA(isA<TypeError>()));
      expect(() => string().validate(42), throwsA(isA<TypeError>()));
    });

    test('propagates non-validation exceptions from transformations', () {
      final error = StateError('Callback failed');
      final schema = string().transform((_) => throw error);
      expect(() => schema.validate('Ada'), throwsA(same(error)));
    });

    test('preserves refinement exception-to-failure behavior', () {
      final schema = string().refine(
        onCheck: (_) => throw StateError('Callback failed'),
        name: 'custom',
        error: 'Invalid',
      );
      expect(schema.validate('Ada'), 'Invalid');
    });

    test('rejects async checks, including composed schemas', () {
      var calls = 0;
      final schema = string().refineAsync(
        onCheck: (_) async {
          calls++;
          return false;
        },
        name: 'remote',
        error: 'Unavailable',
      );
      expect(
        () => schema.validate('Ada'),
        throwsA(isA<AsyncValidationException>()),
      );
      expect(
        () => schema.nullable().validate(null),
        throwsA(isA<AsyncValidationException>()),
      );
      expect(
        () => object({'name': schema}).validate({'name': 'Ada'}),
        throwsA(isA<AsyncValidationException>()),
      );
      expect(calls, 0);
    });
  });
}
