import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

import 'package:acanthis/acanthis.dart' as acanthis;

void main() {
  group('$AcanthisType<num> ', () {
    test("Can be created using `const`", () {
      const AcanthisType<num>();
    });
    test(
        'when creating a number validator,'
        'and the number is valid, '
        'then the result should be successful', () {
      final number = acanthis.number();
      final result = number.tryParse(1);

      expect(result.success, true);

      final resultParse = number.parse(1);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with a gte check,'
        'and the number is greater than the check, '
        'then the result should be successful', () {
      final number = acanthis.number().gte(1);
      final result = number.tryParse(2);

      expect(result.success, true);

      final resultParse = number.parse(2);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with a lte check,'
        'and the number is less than the check, '
        'then the result should be successful', () {
      final number = acanthis.number().lte(1);
      final result = number.tryParse(0);

      expect(result.success, true);

      final resultParse = number.parse(0);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with a gte check,'
        'and the number is less than the check, '
        'then the result should be unsuccessful', () {
      final number = acanthis.number().gte(1);
      final result = number.tryParse(0);

      expect(result.success, false);

      expect(() => number.parse(0), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a number validator with a lte check,'
        'and the number is greater than the check, '
        'then the result should be unsuccessful', () {
      final number = acanthis.number().lte(1);
      final result = number.tryParse(2);

      expect(result.success, false);

      expect(() => number.parse(2), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a number validator with a lt check,'
        'and the number is less than the check, '
        'then the result should be successful', () {
      final number = acanthis.number().lt(1);
      final result = number.tryParse(0);

      expect(result.success, true);

      final resultParse = number.parse(0);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with a lt check,'
        'and the number is greater than the check, '
        'then the result should be unsuccessful', () {
      final number = acanthis.number().lt(1);
      final result = number.tryParse(2);

      expect(result.success, false);

      expect(() => number.parse(2), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a number validator with a gt check,'
        'and the number is greater than the check, '
        'then the result should be successful', () {
      final number = acanthis.number().gt(1);
      final result = number.tryParse(2);

      expect(result.success, true);

      final resultParse = number.parse(2);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with a gt check,'
        'and the number is less than the check, '
        'then the result should be unsuccessful', () {
      final number = acanthis.number().gt(1);
      final result = number.tryParse(0);

      expect(result.success, false);

      expect(() => number.parse(0), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a number validator with a positive check,'
        'and the number is positive, '
        'then the result should be successful', () {
      final number = acanthis.number().positive();
      final result = number.tryParse(1);

      expect(result.success, true);

      final resultParse = number.parse(1);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with a positive check,'
        'and the number is negative, '
        'then the result should be unsuccessful', () {
      final number = acanthis.number().positive();
      final result = number.tryParse(-1);

      expect(result.success, false);

      expect(() => number.parse(-1), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a number validator with a negative check,'
        'and the number is negative, '
        'then the result should be successful', () {
      final number = acanthis.number().negative();
      final result = number.tryParse(-1);

      expect(result.success, true);

      final resultParse = number.parse(-1);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with a negative check,'
        'and the number is positive, '
        'then the result should be unsuccessful', () {
      final number = acanthis.number().negative();
      final result = number.tryParse(1);

      expect(result.success, false);

      expect(() => number.parse(1), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a number validator with an integer check,'
        'and the number is an integer, '
        'then the result should be successful', () {
      final number = acanthis.number().integer();
      final result = number.tryParse(1);

      expect(result.success, true);

      final resultParse = number.parse(1);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with an integer check,'
        'and the number is not an integer, '
        'then the result should be unsuccessful', () {
      final number = acanthis.number().integer();
      final result = number.tryParse(1.1);

      expect(result.success, false);

      expect(() => number.parse(1.1), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a number validator with a multipleOf check,'
        'and the number is a multiple of the check value, '
        'then the result should be successful', () {
      final number = acanthis.number().multipleOf(1);
      final result = number.tryParse(2);

      expect(result.success, true);

      final resultParse = number.parse(2);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with a multipleOf check,'
        'and the number is not a multiple of the check value, '
        'then the result should be unsuccessful', () {
      final number = acanthis.number().multipleOf(2);
      final result = number.tryParse(3);

      expect(result.success, false);

      expect(() => number.parse(3), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a number validator with a finite check,'
        'and the number is finite, '
        'then the result should be successful', () {
      final number = acanthis.number().finite();
      final result = number.tryParse(1);

      expect(result.success, true);

      final resultParse = number.parse(1);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with a finite check,'
        'and the number is not finite, '
        'then the result should be unsuccessful', () {
      final number = acanthis.number().finite();
      final result = number.tryParse(double.infinity);

      expect(result.success, false);

      expect(() => number.parse(double.infinity),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a number validator with an infinite check,'
        'and the number is infinite, '
        'then the result should be successful', () {
      final number = acanthis.number().infinite();
      final result = number.tryParse(double.infinity);

      expect(result.success, true);

      final resultParse = number.parse(double.infinity);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with an infinite check,'
        'and the number is not infinite, '
        'then the result should be unsuccessful', () {
      final number = acanthis.number().infinite();
      final result = number.tryParse(1);

      expect(result.success, false);

      expect(() => number.parse(1), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a number validator with a nan check,'
        'and the number is NaN, '
        'then the result should be successful', () {
      final number = acanthis.number().nan();
      final result = number.tryParse(double.nan);

      expect(result.success, true);

      final resultParse = number.parse(double.nan);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with a nan check,'
        'and the number is not NaN, '
        'then the result should be unsuccessful', () {
      final number = acanthis.number().nan();
      final result = number.tryParse(1);

      expect(result.success, false);

      expect(() => number.parse(1), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a number validator with a notNaN check,'
        'and the number is not NaN, '
        'then the result should be successful', () {
      final number = acanthis.number().notNaN();
      final result = number.tryParse(1);

      expect(result.success, true);

      final resultParse = number.parse(1);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with a notNaN check,'
        'and the number is NaN, '
        'then the result should be unsuccessful', () {
      final number = acanthis.number().notNaN();
      final result = number.tryParse(double.nan);

      expect(result.success, false);

      expect(() => number.parse(double.nan),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a number validator with a custom check,'
        'and the custom check is successful, '
        'then the result should be successful', () {
      final number = acanthis.number().refine(
          onCheck: (value) => value == 1,
          error: 'Value must be 1',
          name: 'custom');
      final result = number.tryParse(1);

      expect(result.success, true);

      final resultParse = number.parse(1);

      expect(resultParse.success, true);
    });

    test(
        'when creating a number validator with a custom check,'
        'and the custom check is unsuccessful, '
        'then the result should be unsuccessful', () {
      final number = acanthis.number().refine(
          onCheck: (value) => value == 1,
          error: 'Value must be 1',
          name: 'custom');
      final result = number.tryParse(2);

      expect(result.success, false);

      expect(() => number.parse(2), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a number validator with the pow transformation,'
        'and the number is valid, '
        'then the result should be the transformed value', () {
      final number = acanthis.number().pow(2);
      final result = number.tryParse(2);

      expect(result.success, true);

      final resultParse = number.parse(2);

      expect(resultParse.success, true);
      expect(resultParse.value, 4);
    });

    test(
        'when creating a number validator with a custom transformation,'
        'and the number is valid, '
        'then the result should be the transformed value', () {
      final number = acanthis.number().transform((value) => value * 3);
      final result = number.tryParse(2);

      expect(result.success, true);

      final resultParse = number.parse(2);

      expect(resultParse.success, true);
      expect(resultParse.value, 6);
    });

    test(
        'when creating a number validator,'
        'and use the list method, '
        'and all the values are valid, '
        'then the result should be successful', () {
      final number = acanthis.number().list();
      final result = number.tryParse([1, 2, 3]);

      expect(result.success, true);

      final resultParse = number.parse([1, 2, 3]);

      expect(resultParse.success, true);
    });

    test(
      'when creating a number validator,'
      'and use the between method, '
      'and the value is between the range, '
      'then the result should be successful',
      () {
        final number = acanthis.number().between(1, 3);
        final result = number.tryParse(2);

        expect(result.success, true);

        final resultParse = number.parse(2);

        expect(resultParse.success, true);
      },
    );

    test(
      'when creating a number validator,'
      'and use the between method, '
      'and the value is not between the range, '
      'then the result should be unsuccessful',
      () {
        final number = acanthis.number().between(1, 3);
        final result = number.tryParse(4);

        expect(result.success, false);

        expect(() => number.parse(4), throwsA(TypeMatcher<ValidationError>()));
      },
    );

    test(
      'when creating a number validator,'
      'and use the double method, '
      'and the value is a double value, '
      'then the result should be successful',
      () {
        final number = acanthis.number().double();
        final result = number.tryParse(4.5);

        expect(result.success, true);

        final resultParse = number.parse(4.5);

        expect(resultParse.success, true);
      },
    );

    test(
      'when creating a number validator,'
      'and use the double method, '
      'and the value is not a double value, '
      'then the result should be unsuccessful',
      () {
        final number = acanthis.number().double();
        final result = number.tryParse(4);

        expect(result.success, false);

        expect(() => number.parse(4), throwsA(TypeMatcher<ValidationError>()));
      },
    );
    test("checks and transformations can be used as annotations", () {
      @NumericChecks.between(min: 5, max: 11)
      @NumericChecks.int
      @NumericChecks.multipleOf(2)
      @NumericChecks.positive
      @NumericChecks.finite
      @NumericChecks.notNaN
      @NumericChecks.double
      @NumericChecks.infinite
      @NumericChecks.nan
      @NumericChecks.negative
      @NumericChecks.lt(10)
      @NumericChecks.gt(5)
      @NumericChecks.lte(10)
      @NumericChecks.gte(5)
      @NumericTransforms.pow(5)

      // ignore: unused_local_variable
          final a = 1;
    });
  });
}
