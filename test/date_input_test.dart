import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

const _maxMilliseconds = 8640000000000000;
final _invalidNumbers = <num>[
  double.nan,
  double.infinity,
  double.negativeInfinity,
  1e100,
  -1e100,
  _maxMilliseconds + 1,
  -_maxMilliseconds - 1,
  9223372036854775807,
  -9223372036854775808,
];

void _expectInvalid(AcanthisOutcome<DateTime> result) {
  expect(result, isA<AcanthisInvalid<DateTime>>());
  expect((result as AcanthisInvalid<DateTime>).hasValue, isFalse);
  expect(result.issues.single.code, 'type');
  expect(result.issues.single.parameters, {'expected': 'DateTime'});
}

void main() {
  test(
    'invalid numeric dates produce validation failures and skip operations',
    () async {
      var calls = 0;
      final schema = date()
          .coerce()
          .withDefault(DateTime.utc(2025))
          .refine(
            onCheck: (_) {
              calls++;
              return true;
            },
          );
      for (final input in _invalidNumbers) {
        _expectInvalid(schema.tryParse(input));
        _expectInvalid(await schema.tryParseAsync(input));
        expect(() => schema.parse(input), throwsA(isA<ValidationError>()));
        await expectLater(
          schema.parseAsync(input),
          throwsA(isA<ValidationError>()),
        );
        expect(schema.validate(input), isFalse);
        expect(schema.tryValidate(input), isFalse);
        expect(await schema.validateAsync(input), isFalse);
        expect(await schema.tryValidateAsync(input), isFalse);
      }
      expect(calls, 0);
      expect(schema.parse(null), DateTime.utc(2025));
      expect(calls, 1);
    },
  );

  test(
    'genuinely async date schemas reject invalid numbers before callbacks',
    () async {
      var calls = 0;
      final schema = date().coerce().refineAsync(
        CallbackAsyncCheck((_, _) async {
          calls++;
        }),
      );
      for (final input in _invalidNumbers) {
        _expectInvalid(await schema.tryParseAsync(input));
        await expectLater(
          schema.parseAsync(input),
          throwsA(isA<ValidationError>()),
        );
        expect(await schema.validateAsync(input), isFalse);
      }
      expect(calls, 0);
    },
  );

  test(
    'date coercion preserves inclusive timestamp bounds and truncation',
    () async {
      final schema = date().coerce();
      for (final input in <num>[
        -_maxMilliseconds,
        -_maxMilliseconds + 1,
        _maxMilliseconds - 1,
        _maxMilliseconds,
        -1.9,
        0,
        1.9,
        1704067200000,
      ]) {
        expect(schema.parse(input).millisecondsSinceEpoch, input.toInt());
        expect(
          schema.tryParse(input).value.millisecondsSinceEpoch,
          input.toInt(),
        );
        expect(
          (await schema.parseAsync(input)).millisecondsSinceEpoch,
          input.toInt(),
        );
      }
      expect(date().tryParse(0).isValid, isFalse);
      expect(date().parse('2025-01-01'), DateTime(2025));
    },
  );

  test('invalid nested timestamps retain field and index paths', () async {
    final schema = object({'dates': list(date().coerce())});
    final input = {'dates': _invalidNumbers};
    for (final result in [
      schema.tryParse(input),
      await schema.tryParseAsync(input),
    ]) {
      expect(result.isValid, isFalse);
      expect(result.issues.map((i) => i.path), [
        for (var i = 0; i < _invalidNumbers.length; i++) ['dates', i],
      ]);
      expect(result.issues.map((i) => i.code), everyElement('type'));
    }
    expect(() => schema.parse(input), throwsA(isA<ValidationError>()));
    await expectLater(
      schema.parseAsync(input),
      throwsA(isA<ValidationError>()),
    );
  });

  test('date callback exceptions continue to propagate', () async {
    final error = RangeError.value(1);
    final sync = date().coerce().transform((_) => throw error);
    final async = date().coerce().transformAsync(
      CallbackAsyncTransform((_) async => throw error),
    );
    expect(() => sync.tryParse(0), throwsA(same(error)));
    expect(() => sync.parse(0), throwsA(same(error)));
    await expectLater(sync.tryParseAsync(0), throwsA(same(error)));
    await expectLater(async.tryParseAsync(0), throwsA(same(error)));
    await expectLater(async.parseAsync(0), throwsA(same(error)));
  });
}
