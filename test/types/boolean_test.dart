import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  group('$AcanthisBoolean', () {
    test('when creating a boolean validator, '
        'and the value is true, '
        'then the result should be successful', () {
      final b = boolean();
      final result = b.tryParse(true);

      expect(result.success, true);

      final resultParse = b.parse(true);

      expect(resultParse.success, true);
    });

    test('when creating a boolean validator, '
        'and the value is false, '
        'then the result should be successful', () {
      final b = boolean();
      final result = b.tryParse(false);

      expect(result.success, true);

      final resultParse = b.parse(false);

      expect(resultParse.success, true);
    });

    test('when creating a boolean validator, '
        'and add the [isFalse] check, '
        'and the value is [false]'
        'then the result should be successful', () {
      final b = boolean().isFalse();
      final result = b.tryParse(false);

      expect(result.success, true);

      final resultParse = b.parse(false);

      expect(resultParse.success, true);
    });

    test('when creating a boolean validator, '
        'and add the [isFalse] check, '
        'and the value is [true]'
        'then the result should be unsuccessful', () {
      final b = boolean().isFalse();
      final result = b.tryParse(true);

      expect(result.success, false);

      expect(() => b.parse(true), throwsA(TypeMatcher<ValidationError>()));
    });

    test('when creating a boolean validator, '
        'and add the [isTrue] check, '
        'and the value is [true]'
        'then the result should be successful', () {
      final b = boolean().isTrue();
      final result = b.tryParse(true);

      expect(result.success, true);

      final resultParse = b.parse(true);

      expect(resultParse.success, true);
    });

    test('when creating a boolean validator, '
        'and add the [isTrue] check, '
        'and the value is [false]'
        'then the result should be unsuccessful', () {
      final b = boolean().isTrue();
      final result = b.tryParse(false);

      expect(result.success, false);

      expect(() => b.parse(false), throwsA(TypeMatcher<ValidationError>()));
    });

    test('when creating a list of boolean validator, '
        'and the value is valid, '
        'then the result should be successful', () {
      final b = boolean().list();
      final result = b.tryParse([true, false]);

      expect(result.success, true);

      final resultParse = b.parse([true, false]);

      expect(resultParse.success, true);
    });

    test('when creating a tuple validator from a date validator,'
        'and the date is not valid, '
        'then the result should be unsuccessful', () {
      final bool = boolean().and([string()]);
      final result = bool.tryParse([5, 'Hello']);

      expect(result.success, false);

      expect(
        () => bool.parse([5, 'Hello']),
        throwsA(TypeMatcher<ValidationError>()),
      );
    });

    test('when creating a tuple validator from a bool validator,'
        'and the bool is valid, '
        'then the result should be successful', () {
      final bool = boolean().and([string()]);
      final result = bool.tryParse([true, 'Hello']);

      expect(result.success, true);

      final resultParse = bool.parse([true, 'Hello']);

      expect(resultParse.success, true);
    });

    test('when creating a union validator from a bool validator,'
        'and the bool is not valid, '
        'then the result should be unsuccessful', () {
      final bool = boolean().or([string()]);
      final result = bool.tryParse(5);

      expect(result.success, false);

      expect(() => bool.parse(5), throwsA(TypeMatcher<ValidationError>()));
    });

    test('when creating a union validator from a bool validator,'
        'and the bool is valid, '
        'then the result should be successful', () {
      final bool = boolean().or([string()]);
      final result = bool.tryParse(true);

      expect(result.success, true);

      final resultParse = bool.parse(true);

      expect(resultParse.success, true);
    });

    test('when coercion is enabled,'
        'and the input is a boolean-like string, '
        'then the parsed value should become a boolean', () {
      final schema = boolean().coerce().isTrue();

      final result = schema.tryParse('true');

      expect(result.success, true);
      expect(result.value, true);
      expect(schema.parse(1).value, true);
    });

    test('when coercion is enabled,'
        'and the input is not coercible, '
        'then tryParse should return an error', () {
      final schema = boolean().coerce();

      final result = schema.tryParse('truthy');

      expect(result.success, false);
      expect(result.errors.containsKey('type'), true);
    });
  });
}
