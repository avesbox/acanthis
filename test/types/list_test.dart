import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';
import 'package:acanthis/acanthis.dart' as acanthis;

void main() {
  group('$AcanthisList', () {
    test("Can be created using `const`", () {
      const AcanthisList(AcanthisDate());
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
      'when creating a tuple validator from a list validator,'
      'and the list is not valid, '
      'then the result should be unsuccessful',
      () {
        final schema = string().list().and([string()]);
        final result = schema.tryParse([5, 'Hello']);

        expect(result.success, false);

        expect(() => schema.parse([5, 'Hello']),
            throwsA(TypeMatcher<ValidationError>()));
      },
    );

    test(
      'when creating a tuple validator from a list validator,'
      'and the list is valid, '
      'then the result should be successful',
      () {
        final schema = string().list().and([string()]);
        final result = schema.tryParse([['Hello'], 'World'],);

        expect(result.success, true);

        final resultParse = schema.parse([['Hello'], 'World']);

        expect(resultParse.success, true);
      },
    );

    test(
      'when creating a union validator from a list validator,'
      'and the list is not valid, '
      'then the result should be unsuccessful',
      () {
        final schema = string().list().or([string()]);
        final result = schema.tryParse(5);

        expect(result.success, false);

        expect(() => schema.parse(5),
            throwsA(TypeMatcher<ValidationError>()));
      },
    );

    test(
      'when creating a union validator from a list validator,'
      'and the list is valid, '
      'then the result should be successful',
      () {
        final schema = string().list().or([string()]);
        final result = schema.tryParse(['Hello', 'World']);

        expect(result.success, true);

        final resultParse = schema.parse(['Hello', 'World']);

        expect(resultParse.success, true);
      },
    );

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

  test(
    'when creating a list validator,'
    'and use the toJsonSchema method, '
    'then the result should be a valid json schema',
    () {
      final schema = acanthis.string().list();
      final result = schema.toJsonSchema();

      expect(result, isA<Map<String, dynamic>>());
      expect(result['type'], 'array');
      expect(result['items'], isA<Map<String, dynamic>>());
    },
  );

  test(
      'when creating a list validator,'
      'and use the toJsonSchema method and the meta method, '
      'then the result should be a valid json schema with the metadata', () {
    final schema = acanthis.string().list().meta(MetadataEntry(
          description: 'description',
          title: 'title',
          examples: [
            ['example1', 'example2']
          ],
        ));
    final result = schema.toJsonSchema();
    expect(result, isA<Map<String, dynamic>>());
    expect(result['type'], 'array');
    expect(result['items'], isA<Map<String, dynamic>>());
    expect(result['description'], 'description');
    expect(result['title'], 'title');
    expect(result['examples'], [
      ['example1', 'example2']
    ]);
    expect(result['items']['type'], 'string');
  });

  test(
      'when creating a list validator,'
      'and use the toJsonSchema method and length checks are used, '
      'then the result should be a valid json schema with the constraints', () {
    final schema = acanthis.string().list().min(2).max(5);
    final result = schema.toJsonSchema();
    expect(result, isA<Map<String, dynamic>>());
    expect(result['type'], 'array');
    expect(result['items'], isA<Map<String, dynamic>>());
    expect(result['minItems'], 2);
    expect(result['maxItems'], 5);

    final schema2 = acanthis.string().list().length(3);
    final result2 = schema2.toJsonSchema();
    expect(result2, isA<Map<String, dynamic>>());
    expect(result2['type'], 'array');
    expect(result2['items'], isA<Map<String, dynamic>>());
    expect(result2['minItems'], 3);
    expect(result2['maxItems'], 3);
  });

  test(
      'when creating a list validator,'
      'and use the toJsonSchema method and the unique check, '
      'then the result should be a valid json schema with uniqueItems true',
      () {
    final schema = acanthis.string().list().unique();
    final result = schema.toJsonSchema();
    expect(result, isA<Map<String, dynamic>>());
    expect(result['type'], 'array');
    expect(result['items'], isA<Map<String, dynamic>>());
    expect(result['uniqueItems'], true);
  });
}
