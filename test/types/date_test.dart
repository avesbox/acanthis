import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

import 'package:acanthis/acanthis.dart' as acanthis;

void main() {
  group('$AcanthisType<DateTime> ', () {
    test("Can be created using `const`", () {
      const AcanthisType<DateTime>();
    });
    test(
        'when creating a date validator,'
        'and the date is valid, '
        'then the result should be successful', () {
      final date = acanthis.date();
      final result = date.tryParse(DateTime(2020, 1, 1));

      expect(result.success, true);

      final resultParse = date.parse(DateTime(2020, 1, 1));

      expect(resultParse.success, true);
    });

    test(
        'when creating a date validator with a max check,'
        'and the date is greater than the check, '
        'then the result should be unsuccessful', () {
      final date = acanthis.date().max(DateTime(2020, 1, 1));
      final result = date.tryParse(DateTime(2021, 1, 1));

      expect(result.success, false);

      expect(() => date.parse(DateTime(2021, 1, 1)),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a date validator with a min check,'
        'and the date is less than the check, '
        'then the result should be unsuccessful', () {
      final date = acanthis.date().min(DateTime(2020, 1, 1));
      final result = date.tryParse(DateTime(2019, 1, 1));

      expect(result.success, false);

      expect(() => date.parse(DateTime(2019, 1, 1)),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a date validator with a min and max check,'
        'and the date is less than the min check, '
        'then the result should be unsuccessful', () {
      final date =
          acanthis.date().min(DateTime(2020, 1, 1)).max(DateTime(2021, 1, 1));
      final result = date.tryParse(DateTime(2019, 1, 1));

      expect(result.success, false);

      expect(() => date.parse(DateTime(2019, 1, 1)),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a date validator with a min and max check,'
        'and the date is greater than the max check, '
        'then the result should be unsuccessful', () {
      final date =
          acanthis.date().min(DateTime(2020, 1, 1)).max(DateTime(2021, 1, 1));
      final result = date.tryParse(DateTime(2022, 1, 1));

      expect(result.success, false);

      expect(() => date.parse(DateTime(2022, 1, 1)),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a date validator with a min and max check,'
        'and the date is between the min and max check, '
        'then the result should be successful', () {
      final date =
          acanthis.date().min(DateTime(2020, 1, 1)).max(DateTime(2021, 1, 1));
      final result = date.tryParse(DateTime(2020, 1, 1));

      expect(result.success, true);

      final resultParse = date.parse(DateTime(2020, 1, 1));

      expect(resultParse.success, true);
    });

    test(
        'when creating a date validator with a customCheck,'
        'and the date is not valid, '
        'then the result should be unsuccessful', () {
      final date = acanthis.date().refine(
          onCheck: (date) => date.year == 2020,
          error: 'Date must be in 2020',
          name: 'customCheck');
      final result = date.tryParse(DateTime(2021, 1, 1));

      expect(result.success, false);

      expect(() => date.parse(DateTime(2021, 1, 1)),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a date validator with a customCheck,'
        'and the date is valid, '
        'then the result should be successful', () {
      final date = acanthis.date().refine(
          onCheck: (date) => date.year == 2020,
          error: 'Date must be in 2020',
          name: 'customCheck');
      final result = date.tryParse(DateTime(2020, 1, 1));

      expect(result.success, true);

      final resultParse = date.parse(DateTime(2020, 1, 1));

      expect(resultParse.success, true);
    });

    test(
        'when creating a date validator with a custom transformation,'
        'and the date is valid, '
        'then the result should be transformed', () {
      final date = acanthis
          .date()
          .transform((date) => DateTime(date.year, date.month, date.day + 1));
      final result = date.tryParse(DateTime(2021, 1, 1));

      expect(result.success, true);

      final resultParse = date.parse(DateTime(2021, 1, 1));

      expect(resultParse.success, true);
      expect(resultParse.value, DateTime(2021, 1, 2));
    });

    test(
        'when creating a date validator,'
        'and use the list method, '
        'and all the values are valid, '
        'then the result should be successful', () {
      final date = acanthis
          .date()
          .min(DateTime(2020, 1, 1))
          .max(DateTime(2021, 1, 1))
          .list();
      final result =
          date.tryParse([DateTime(2020, 1, 1), DateTime(2021, 1, 1)]);

      expect(result.success, true);

      final resultParse =
          date.parse([DateTime(2020, 1, 1), DateTime(2021, 1, 1)]);

      expect(resultParse.success, true);
    });

    test(
      'when creating a date validator,'
      'and use the differenceFromNow method, '
      'and the value is valid, '
      'then the result should be successful',
      () {
        final date = acanthis.date().differsFromNow(Duration(days: 1));
        final result = date.tryParse(DateTime.now().add(Duration(days: 2)));

        expect(result.success, true);

        final resultParse = date.parse(DateTime.now().add(Duration(days: 2)));

        expect(resultParse.success, true);
      },
    );

    test(
      'when creating a date validator,'
      'and use the differenceFromNow method, '
      'and the value is not valid, '
      'then the result should be unsuccessful',
      () {
        final date = acanthis.date().differsFromNow(Duration(days: 1));
        final result = date.tryParse(DateTime.now().add(Duration(hours: 12)));

        expect(result.success, false);

        expect(() => date.parse(DateTime.now().add(Duration(hours: 12))),
            throwsA(TypeMatcher<ValidationError>()));
      },
    );

    test("checks and transformations can be used as annotations", () {
      // TODO: DateTime has no const constructor
      // @DateChecks.min(DateTime())
      // @DateChecks.max(Duration(days: 1))
      @DateChecks.differsFromNow(Duration(days: 1))
      // ignore: unused_local_variable
          final a = 1;
    });
  });
}
