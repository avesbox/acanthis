import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

import 'package:acanthis/acanthis.dart' as acanthis;

void main() {
  group('$AcanthisNumber', () {
    test("Can be created using `const`", () {
      const AcanthisNumber();
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

    test(
      'when creating an enumerated number validator, and the number is in the list of valid values, then the result should be successful',
      () {
        final number = acanthis.number().enumerated([1, 2, 3]);
        final result = number.tryParse(1);

        expect(result.success, true);

        final resultParse = number.parse(1);
        expect(resultParse.success, true);
      },
    );

    test(
      'when creating an enumerated number validator, and the number is not in the list of valid values, then the result should be unsuccessful',
      () {
        final number = acanthis.number().enumerated([1, 2, 3]);
        final result = number.tryParse(4);

        expect(result.success, false);

        expect(
            () => number.parse(4),
            throwsA(
              TypeMatcher<ValidationError>(),
            ));
      },
    );

    test(
      'when creating an exact number validator, and the number is not exactly the value passed, then the result should be unsuccessful',
      () {
        final number = acanthis.number().exact(1);
        final result = number.tryParse(2);

        expect(result.success, false);

        expect(
            () => number.parse(2),
            throwsA(
              TypeMatcher<ValidationError>(),
            ));
      },
    );

    test(
      'when creating an exact number validator, and the number is exactly the value passed, then the result should be successful',
      () {
        final number = acanthis.number().exact(1);
        final result = number.tryParse(1);

        expect(result.success, true);

        final resultParse = number.parse(1);

        expect(resultParse.success, true);
      },
    );

    test(
      'when creating an number validator,'
      'and use the toJsonSchema method and the validator has constraint checks, '
      'then the result should be a valid json schema with the constraints',
      () {
        final number = acanthis.number().gte(1).lte(3);
        final result = number.toJsonSchema();

        final expected = {
          'type': 'number',
          'minimum': 1,
          'maximum': 3,
        };
        expect(result, expected);

        final number2 = acanthis.number().gt(1).lt(3);
        final result2 = number2.toJsonSchema();

        final expected2 = {
          'type': 'number',
          'exclusiveMinimum': 1,
          'exclusiveMaximum': 3,
        };

        expect(result2, expected2);

        final number3 = acanthis.number().positive().negative();
        final result3 = number3.toJsonSchema();

        final expected3 = {
          'type': 'number',
          'exclusiveMinimum': 0,
          'exclusiveMaximum': 0,
        };

        expect(result3, expected3);

        final number4 = acanthis.number().between(10, 30);
        final result4 = number4.toJsonSchema();

        final expected4 = {
          'type': 'number',
          'minimum': 10,
          'maximum': 30,
        };
        expect(result4, expected4);
      },
    );

    test(
      'when creating a number validator,'
      'and use the toJsonSchema method and the validator has a multipleOf check, '
      'then the result should be a valid json schema with the multipleOf',
      () {
        final number = acanthis.number().multipleOf(2);
        final result = number.toJsonSchema();

        final expected = {
          'type': 'number',
          'multipleOf': 2,
        };
        expect(result, expected);
      },
    );

    test(
      'when creating an number validator,'
      'and use the toJsonSchema method and the metadata, '
      'then the result should be a valid json schema with the metadata',
      () {
        final number = acanthis.number().meta(MetadataEntry(
              description: 'test',
              title: 'test',
            ));
        final result = number.toJsonSchema();

        final expected = {
          'type': 'number',
          'description': 'test',
          'title': 'test',
        };
        expect(result, expected);
      },
    );

    test(
      'when creating an number validator,'
      'and use the toJsonSchema method and the integer validator, '
      'then the result should be a valid json schema type "integer"',
      () {
        final number = acanthis.number().integer();
        final result = number.toJsonSchema();

        final expected = {
          'type': 'integer',
        };
        expect(result, expected);
      },
    );

    test(
      'when creating an enumerated number validator,'
      'and use the toJsonSchema method, '
      'then the result should be a valid json schema',
      () {
        final number = acanthis.number().enumerated([1, 2]);
        final result = number.toJsonSchema();

        final expected = {
          'enum': [1, 2],
        };
        expect(result, expected);
      },
    );

    test(
      'when creating an exact number validator,'
      'and use the toJsonSchema method, '
      'then the result should be a valid json schema',
      () {
        final number = acanthis.number().exact(1);
        final result = number.toJsonSchema();

        final expected = {
          'const': 1,
        };
        expect(result, expected);
      },
    );
  });
}
