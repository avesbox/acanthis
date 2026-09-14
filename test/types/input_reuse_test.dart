import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test('plain and constrained objects return their input', () async {
    for (final schema in [
      object({'a': string()}),
      object({'a': string().min(2)}),
    ]) {
      final input = {'a': 'ok'};
      expect(identical(schema.parse(input).value, input), isTrue);
      expect(identical(schema.tryParse(input).value, input), isTrue);
      expect(identical((await schema.parseAsync(input)).value, input), isTrue);
      expect(
        identical((await schema.tryParseAsync(input)).value, input),
        isTrue,
      );
      schema.parse(input).value['a'] = 'updated';
      expect(input['a'], 'updated');
    }
  });

  test(
    'stripping allocates without mutating input; passthrough reuses input',
    () {
      final schema = object({'a': string()});
      final input = {'a': 'ok', 'extra': 'keep'};
      for (final result in [schema.parse(input), schema.tryParse(input)]) {
        expect(result.value, {'a': 'ok'});
        expect(identical(result.value, input), isFalse);
        expect(input['extra'], 'keep');
      }
      expect(identical(schema.passthrough().parse(input).value, input), isTrue);
      expect(
        identical(schema.passthrough().tryParse(input).value, input),
        isTrue,
      );
    },
  );

  test('coercion, child transformations and defaults keep their outputs', () {
    final coercedInput = {'a': 42};
    final coerced = object({'a': string().coerce()}).parse(coercedInput).value;
    expect(coerced, {'a': '42'});
    expect(coercedInput, {'a': 42});
    final input = {'a': 'ok'};
    var calls = 0;
    final transformed = object({
      'a': string().transform((v) {
        calls++;
        return '$v!';
      }),
    });
    expect(transformed.parse(input).value, {'a': 'ok!'});
    expect(calls, 1);
    expect(input['a'], 'ok');
    final fallback = object({'a': string().min(3).withDefault('fallback')})
        .tryParse(input);
    expect(fallback.success, isFalse);
    expect(fallback.value['a'], 'fallback');
    expect(input['a'], 'ok');
  });

  test('async checks run every time without retaining errors', () async {
    var calls = 0;
    final schema = object({
      'a': string().refineAsync(
        onCheck: (value) async {
          calls++;
          return value == 'ok';
        },
        name: 'remote',
        error: 'rejected',
      ),
    });
    final input = {'a': 'ok'};
    expect((await schema.tryParseAsync({'a': 'bad'})).success, isFalse);
    expect(identical((await schema.tryParseAsync(input)).value, input), isTrue);
    expect(identical((await schema.parseAsync(input)).value, input), isTrue);
    expect(calls, 3);
  });

  test('pure lists retain identity, transformed elements do not', () async {
    final input = ['ok'];
    final schema = string().min(1).list();
    expect(identical(schema.parse(input).value, input), isTrue);
    expect(identical(schema.tryParse(input).value, input), isTrue);
    expect(identical((await schema.parseAsync(input)).value, input), isTrue);
    final transformed = string()
        .transform((v) => '$v!')
        .list()
        .parse(input)
        .value;
    expect(transformed, ['ok!']);
    expect(input, ['ok']);
  });

  test(
    'nested pure objects share input and read-only input stays read-only',
    () {
      final schema = object({
        'child': object({'a': string()}),
      });
      final input = {
        'child': {'a': 'ok'},
      };
      expect(identical(schema.parse(input).value, input), isTrue);
      final frozen = Map<String, dynamic>.unmodifiable(input);
      expect(identical(schema.parse(frozen).value, frozen), isTrue);
    },
  );
}
