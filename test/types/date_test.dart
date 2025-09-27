import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

import 'package:acanthis/acanthis.dart' as acanthis;

void main() {
  group('$AcanthisDate', () {
    test("Can be created using `const`", () {
      const AcanthisDate();
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
        'and the date is lower than the check, '
        'then the result should be successful', () {
      final date = acanthis.date().max(DateTime(2020, 1, 1));
      final result = date.tryParse(DateTime(2019, 1, 1));

      expect(result.success, true);

      final resultParse = date.parse(DateTime(2019, 1, 1));

      expect(resultParse.success, true);
    });

    test(
        'when creating a date validator with a min check,'
        'and the date is greater than the check, '
        'then the result should be unsuccessful', () {
      final date = acanthis.date().min(DateTime(2020, 1, 1));
      final result = date.tryParse(DateTime(2021, 1, 1));

      expect(result.success, true);

      final resultParse = date.parse(DateTime(2021, 1, 1));

      expect(resultParse.success, true);
    });

    test(
        'when creating a date validator with a min check,'
        'and the date is lower than the check, '
        'then the result should be unsuccessful', () {
      final date = acanthis.date().min(DateTime(2020, 1, 1));
      final result = date.tryParse(DateTime(2019, 1, 1));

      expect(result.success, false);

      expect(
        () => date.parse(DateTime(2019, 1, 1)),
        throwsA(TypeMatcher<ValidationError>()),
      );
    });

    test(
        'when creating a date validator with a min and max check,'
        'and the date is less than the min check, '
        'then the result should be unsuccessful', () {
      final date =
          acanthis.date().min(DateTime(2020, 1, 1)).max(DateTime(2021, 1, 1));
      final result = date.tryParse(DateTime(2019, 1, 1));

      expect(result.success, false);

      expect(
        () => date.parse(DateTime(2019, 1, 1)),
        throwsA(TypeMatcher<ValidationError>()),
      );
    });

    test(
        'when creating a date validator with a min and max check,'
        'and the date is greater than the max check, '
        'then the result should be unsuccessful', () {
      final date =
          acanthis.date().min(DateTime(2020, 1, 1)).max(DateTime(2021, 1, 1));
      final result = date.tryParse(DateTime(2022, 1, 1));

      expect(result.success, false);

      expect(
        () => date.parse(DateTime(2022, 1, 1)),
        throwsA(TypeMatcher<ValidationError>()),
      );
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
        'when creating a tuple validator from a date validator,'
        'and the date is valid, '
        'then the result should be successful', () {
      final date = acanthis.date().and([acanthis.string()]);
      final result = date.tryParse([DateTime(2020, 1, 1), 'Hello']);

      expect(result.success, true);

      final resultParse = date.parse([DateTime(2020, 1, 1), 'Hello']);

      expect(resultParse.success, true);
    });

    test(
        'when creating a tuple validator from a date validator,'
        'and the date is not valid, '
        'then the result should be unsuccessful', () {
      final date = acanthis.date().and([acanthis.string()]);
      final result = date.tryParse([DateTime(2020, 1, 1), 5]);

      expect(result.success, false);

      expect(
        () => date.parse([DateTime(2020, 1, 1), 5]),
        throwsA(TypeMatcher<ValidationError>()),
      );
    });

    test(
        'when creating a union validator from a date validator,'
        'and the date is not valid, '
        'then the result should be unsuccessful', () {
      final date = acanthis.date().or([acanthis.string()]);
      final result = date.tryParse(5);

      expect(result.success, false);

      expect(() => date.parse(5), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a union validator from a date validator,'
        'and the date is valid, '
        'then the result should be successful', () {
      final date = acanthis.date().or([acanthis.string()]);
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
            name: 'customCheck',
          );
      final result = date.tryParse(DateTime(2021, 1, 1));

      expect(result.success, false);

      expect(
        () => date.parse(DateTime(2021, 1, 1)),
        throwsA(TypeMatcher<ValidationError>()),
      );
    });

    test(
        'when creating a date validator with a customCheck,'
        'and the date is valid, '
        'then the result should be successful', () {
      final date = acanthis.date().refine(
            onCheck: (date) => date.year == 2020,
            error: 'Date must be in 2020',
            name: 'customCheck',
          );
      final result = date.tryParse(DateTime(2020, 1, 1));

      expect(result.success, true);

      final resultParse = date.parse(DateTime(2020, 1, 1));

      expect(resultParse.success, true);
    });

    test(
        'when creating a date validator with a custom transformation,'
        'and the date is valid, '
        'then the result should be transformed', () {
      final date = acanthis.date().transform(
            (date) => DateTime(date.year, date.month, date.day + 1),
          );
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
      final result = date.tryParse([
        DateTime(2020, 1, 1),
        DateTime(2021, 1, 1),
      ]);

      expect(result.success, true);

      final resultParse = date.parse([
        DateTime(2020, 1, 1),
        DateTime(2021, 1, 1),
      ]);

      expect(resultParse.success, true);
    });

    test(
        'when creating a date validator,'
        'and use the differenceFromNow method, '
        'and the value is valid, '
        'then the result should be successful', () {
      final date = acanthis.date().differsFromNow(Duration(days: 1));
      final result = date.tryParse(DateTime.now().add(Duration(days: 2)));

      expect(result.success, true);

      final resultParse = date.parse(DateTime.now().add(Duration(days: 2)));

      expect(resultParse.success, true);
    });

    test(
        'when creating a date validator,'
        'and use the differenceFromNow method, '
        'and the value is not valid, '
        'then the result should be unsuccessful', () {
      final date = acanthis.date().differsFromNow(Duration(days: 1));
      final result = date.tryParse(DateTime.now().add(Duration(hours: 12)));

      expect(result.success, false);

      expect(
        () => date.parse(DateTime.now().add(Duration(hours: 12))),
        throwsA(TypeMatcher<ValidationError>()),
      );
    });

    test(
        'when creating a date validator,'
        'and use the differenceFrom method, '
        'and the value is valid, '
        'then the result should be successful', () {
      final date = acanthis.date().differsFrom(
            DateTime(2023, 10, 1),
            Duration(days: 1),
          );
      final result = date.tryParse(DateTime(2023, 10, 2));

      expect(result.success, true);

      final resultParse = date.parse(DateTime(2023, 10, 2));

      expect(resultParse.success, true);
    });

    test(
        'when creating a date validator,'
        'and use the differenceFrom method, '
        'and the value is not valid, '
        'then the result should be unsuccessful', () {
      final date = acanthis.date().differsFrom(
            DateTime(2023, 10, 1),
            Duration(days: 2),
          );
      final result = date.tryParse(DateTime(2023, 10, 0));

      expect(result.success, false);

      expect(
        () => date.parse(DateTime(2023, 10, 0)),
        throwsA(TypeMatcher<ValidationError>()),
      );
    });

    test(
        'when creating a date validator,'
        'and use the toJsonSchema method, '
        'then the result should be a valid json schema', () {
      final date = acanthis.date().differsFromNow(Duration(days: 1));
      final result = date.toJsonSchema();

      expect(result, isA<Map<String, dynamic>>());
      expect(result['type'], 'string');
      expect(result['format'], 'date-time');
    });

    test(
        'when creating a date validator,'
        'and use the toJsonSchema method and the meta method, '
        'then the result should be a valid json schema with the metadata', () {
      final date = acanthis.date().differsFromNow(Duration(days: 1)).meta(
            MetadataEntry(
              description: 'A date in the future',
              id: 'date-future',
              title: 'Future Date',
              examples: [DateTime(2023, 10, 1)],
            ),
          );
      final result = date.toJsonSchema();

      expect(result, isA<Map<String, dynamic>>());
      expect(result['type'], 'string');
      expect(result['format'], 'date-time');
      expect(result['description'], 'A date in the future');
      expect(result['id'], 'date-future');
      expect(result['title'], 'Future Date');
      expect(result['examples'], ['2023-10-01T00:00:00.000']);
    });
  });
}
