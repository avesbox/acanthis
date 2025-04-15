import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';
import 'package:acanthis/acanthis.dart' as acanthis;

void main() {
  group('$AcanthisList', () {
    test("Can be created using `const`", () {
      const AcanthisList(AcanthisType<DateTime>());
    });
    test(
        'when creating a list validator,'
        'and the list is valid, '
        'then the result should be successful', () {
      final list = acanthis.string().min(5).max(20).list();
      final result = list.tryParse(['value']);

      expect(result.success, true);

      final resultParse = list.parse(['value']);

      expect(resultParse.success, true);
    });

    test(
        'when creating a list validator with a required field,'
        'and the list is empty, '
        'then the result should be successful', () {
      final list = acanthis.string().min(5).max(20).list();
      final result = list.tryParse([]);
      expect(result.success, true);

      final resultParse = list.parse([]);

      expect(resultParse.success, true);
    });

    test(
        'when creating a list validator with a min and max check,'
        'and the list is less than the min check, '
        'then the result should be unsuccessful', () {
      final list = acanthis.string().min(5).max(20).list().min(2);
      final result = list.tryParse(['value']);

      expect(result.success, false);

      expect(
          () => list.parse(['value']), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a list validator with a min and max check,'
        'and the list is greater than the max check, '
        'then the result should be unsuccessful', () {
      final list = acanthis.string().min(5).max(20).list().max(1);
      final result = list.tryParse(['value', 'other']);

      expect(result.success, false);

      expect(() => list.parse(['value', 'other']),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a list validator with a min and max check,'
        'and the list is less than the min check, '
        'then the result should be unsuccessful', () {
      final list = acanthis.string().min(5).max(20).list().min(2).max(3);
      final result = list.tryParse(['value']);

      expect(result.success, false);

      expect(
          () => list.parse(['value']), throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a list validator with a min and max check,'
        'and the list is greater than the max check, '
        'then the result should be unsuccessful', () {
      final list = acanthis.string().min(5).max(20).list().min(2).max(3);
      final result = list.tryParse(['value', 'other', 'another', 'one']);

      expect(result.success, false);

      expect(() => list.parse(['value', 'other', 'another', 'one']),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a list validator with a min and max check,'
        'and the list is valid, '
        'then the result should be successful', () {
      final list = acanthis.string().min(5).max(20).list().min(2).max(3);
      final result = list.tryParse(['value', 'other']);

      expect(result.success, true);

      final resultParse = list.parse(['value', 'other']);

      expect(resultParse.success, true);
    });

    test(
        'when creating a list validator with a min and max check,'
        'and the list is valid, '
        'then the result should be successful', () {
      final list = acanthis.string().min(5).max(20).list().min(2).max(3);
      final result = list.tryParse(['value', 'other', 'another']);

      expect(result.success, true);

      final resultParse = list.parse(['value', 'other', 'another']);

      expect(resultParse.success, true);
    });

    test(
        'when creating a list validator with a unique check,'
        'and the list is valid, '
        'then the result should be successful', () {
      final list = acanthis.string().min(5).max(20).list().unique();
      final result = list.tryParse(['value', 'other', 'another', 'oneee']);
      expect(result.success, true);

      final resultParse = list.parse(['value', 'other', 'another', 'oneee']);

      expect(resultParse.success, true);
    });

    test(
        'when creating a list validator with a unique check,'
        'and the list is invalid, '
        'then the result should be unsuccessful', () {
      final list = acanthis.string().min(5).max(20).list().unique();
      final result = list.tryParse(['value', 'other', 'another', 'another']);

      expect(result.success, false);

      expect(() => list.parse(['value', 'other', 'another', 'another']),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a list validator with the length check,'
        'and the list is valid, '
        'then the result should be successful', () {
      final list = acanthis.string().min(5).max(20).list().length(4);
      final result = list.tryParse(['value', 'other', 'another', 'oneee']);

      expect(result.success, true);

      final resultParse = list.parse(['value', 'other', 'another', 'oneee']);

      expect(resultParse.success, true);
    });

    test(
        'when creating a list validator with a custom check,'
        'and the list is invalid, '
        'then the result should be unsuccessful', () {
      final list = acanthis
          .string()
          .min(5)
          .max(20)
          .list()
          .refine(onCheck: (value) => value.length == 4, error: '5', name: '5');
      final result =
          list.tryParse(['value', 'other', 'another', 'another', 'oneee']);

      expect(result.success, false);

      expect(
          () => list.parse(['value', 'other', 'another', 'another', 'oneee']),
          throwsA(TypeMatcher<ValidationError>()));
    });

    test(
        'when creating a list validator with a custom transformation,'
        'and all the elements in the list are valid, '
        'and the list itself is valid, '
        'then the result should be transformed', () {
      final list = acanthis
          .string()
          .min(5)
          .max(20)
          .list()
          .transform((value) => value.map((e) => e.toUpperCase()).toList());

      final result = list.tryParse(['value', 'other', 'another', 'oneee']);

      expect(result.success, true);

      final resultParse = list.parse(['value', 'other', 'another', 'oneee']);

      expect(resultParse.success, true);
      expect(resultParse.value, ['VALUE', 'OTHER', 'ANOTHER', 'ONEEE']);
    });
    test("checks and transformations can be used as annotations", () {
      @ListChecks.anyOf([])
      @ListChecks.everyOf([])
      @ListChecks.unique()
      @ListChecks.length(1)
      @ListChecks.min(1)
      @ListChecks.max(1)

      // ignore: unused_local_variable
          final a = 1;
    });
  });

  test(
    'when creating with anyOf check, and the list is valid, then the result should be successful',
    () {
      final list = acanthis.string().list().anyOf(['value', 'other']);
      final result = list.tryParse(['other']);

      expect(result.success, true);

      final resultParse = list.parse(['value']);

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating with anyOf check, and the list is invalid, then the result should be unsuccessful',
    () {
      final list = acanthis.string().list().anyOf(['value', 'other']);
      final result = list.tryParse(['another']);

      expect(result.success, false);

      expect(() => list.parse(['another']),
          throwsA(TypeMatcher<ValidationError>()));
    },
  );

  test(
    'when creating with everyOf check, and the list is valid, then the result should be successful',
    () {
      final list = acanthis.string().list().everyOf(['value', 'other']);
      final result = list.tryParse(['value', 'other']);

      expect(result.success, true);

      final resultParse = list.parse(['value', 'other']);

      expect(resultParse.success, true);
    },
  );

  test(
    'when creating with everyOf check, and the list is invalid, then the result should be unsuccessful',
    () {
      final list = acanthis.string().list().everyOf(['value', 'other']);
      final result = list.tryParse(['value', 'another']);

      expect(result.success, false);

      expect(() => list.parse(['value', 'another']),
          throwsA(TypeMatcher<ValidationError>()));
    },
  );
}
