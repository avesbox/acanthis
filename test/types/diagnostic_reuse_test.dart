import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'list diagnostics stay independent across invalid and valid children',
    () {
      for (final child in [
        string().min(2),
        string().min(2).transform((value) => value.trim()),
      ]) {
        final result = child.list().tryParse(['', 'valid', 'x', 'valid']);

        expect(result.success, isFalse);
        expect(result.errors.keys, ['0', '2']);
        expect(result.errors['0'], isNotEmpty);
        expect(result.errors['2'], isNotEmpty);
        expect(identical(result.errors['0'], result.errors['2']), isFalse);
        expect(child.list().tryParse(['valid']).success, isTrue);
      }
    },
  );

  test(
    'object diagnostics stay independent across invalid and valid fields',
    () {
      for (final child in [
        string().min(2),
        string().min(2).transform((value) => value.trim()),
      ]) {
        final schema = object({'a': child, 'b': child, 'c': child});
        final result = schema.tryParse({'a': '', 'b': 'valid', 'c': 'x'});

        expect(result.success, isFalse);
        expect(result.errors.keys, ['a', 'c']);
        expect(result.errors['a'], isNotEmpty);
        expect(result.errors['c'], isNotEmpty);
        expect(identical(result.errors['a'], result.errors['c']), isFalse);
        expect(
          schema.tryParse({'a': 'ok', 'b': 'ok', 'c': 'ok'}).success,
          isTrue,
        );
      }
    },
  );

  test('child defaults still apply only to failing values', () {
    final child = string().min(2).withDefault('fallback');
    final result = child.list().tryParse(['', 'valid', 'x']);

    expect(result.value, ['fallback', 'valid', 'fallback']);
    expect(result.errors.keys, ['0', '2']);
    expect(child.tryParse('valid').value, 'valid');
    expect(child.tryParse('').value, 'fallback');
  });
}
