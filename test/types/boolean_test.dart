import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  group('$AcanthisBoolean', () {
    test("Can be created using `const`", () {
      const AcanthisBoolean();
    });
    test(
        'when creating a boolean validator, '
        'and the value is true, '
        'then the result should be successful', () {
      final b = boolean();
      final result = b.tryParse(true);

      expect(result.success, true);

      final resultParse = b.parse(true);

      expect(resultParse.success, true);
    });

    test(
        'when creating a boolean validator, '
        'and the value is false, '
        'then the result should be successful', () {
      final b = boolean();
      final result = b.tryParse(false);

      expect(result.success, true);

      final resultParse = b.parse(false);

      expect(resultParse.success, true);
    });

    test(
        'when creating a boolean validator, '
        'and add the [isFalse] check, '
        'and the value is [false]'
        'then the result should be successful', () {
      final b = boolean().isFalse();
      final result = b.tryParse(false);

      expect(result.success, true);

      final resultParse = b.parse(false);

      expect(resultParse.success, true);
    });

    test(
        'when creating a boolean validator, '
        'and add the [isFalse] check, '
        'and the value is [true]'
        'then the result should be unsuccessful', () {
      final b = boolean().isFalse();
      final result = b.tryParse(true);

      expect(result.success, false);

      expect(() => b.parse(true), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a boolean validator, '
        'and add the [isTrue] check, '
        'and the value is [true]'
        'then the result should be successful', () {
      final b = boolean().isTrue();
      final result = b.tryParse(true);

      expect(result.success, true);

      final resultParse = b.parse(true);

      expect(resultParse.success, true);
    });

    test(
        'when creating a boolean validator, '
        'and add the [isTrue] check, '
        'and the value is [false]'
        'then the result should be unsuccessful', () {
      final b = boolean().isTrue();
      final result = b.tryParse(false);

      expect(result.success, false);

      expect(() => b.parse(false), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a list of boolean validator, '
        'and the value is valid, '
        'then the result should be successful', () {
      final b = boolean().list();
      final result = b.tryParse([true, false]);

      expect(result.success, true);

      final resultParse = b.parse([true, false]);

      expect(resultParse.success, true);
    });

    test("checks and transformations can be used as annotations", () {
      @BooleanChecks.isTrue
      @BooleanChecks.isFalse
      // ignore: unused_local_variable
          final a = 1;
    });
  });
}
