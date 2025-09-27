import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  group('$AcanthisNullable', () {
    test("Can be created using `const`", () {
      const AcanthisNullable(AcanthisDate());
    });
    test('when creating a nullable validator on a string,'
        'and the value is not null, '
        'then the result should be successful', () {
      final nullable = string().nullable();
      final result = nullable.tryParse('This is a test');

      expect(result.success, true);

      final resultParse = nullable.parse('This is a test');

      expect(resultParse.success, true);
    });

    test('when creating a nullable validator on a string,'
        'and the value is null, '
        'then the result should be successful', () {
      final nullable = string().nullable();
      final result = nullable.tryParse(null);

      expect(result.success, true);

      final resultParse = nullable.parse(null);

      expect(resultParse.success, true);
    });

    test('when creating a nullable validator on a number,'
        'and the value is not null, '
        'then the result should be successful', () {
      final nullable = number().nullable();
      final result = nullable.tryParse(1);

      expect(result.success, true);

      final resultParse = nullable.parse(1);

      expect(resultParse.success, true);
    });

    test('when creating a nullable validator on a number,'
        'and the value is null, '
        'then the result should be successful', () {
      final nullable = number().nullable();
      final result = nullable.tryParse(null);

      expect(result.success, true);

      final resultParse = nullable.parse(null);

      expect(resultParse.success, true);
    });

    test('when creating a nullable validator on a date,'
        'and the value is not null, '
        'then the result should be successful', () {
      final nullable = date().nullable();
      final result = nullable.tryParse(DateTime(2020, 1, 1));

      expect(result.success, true);

      final resultParse = nullable.parse(DateTime(2020, 1, 1));

      expect(resultParse.success, true);
    });

    test('when creating a nullable validator on a date,'
        'and the value is null, '
        'then the result should be successful', () {
      final nullable = date().nullable();
      final result = nullable.tryParse(null);

      expect(result.success, true);

      final resultParse = nullable.parse(null);

      expect(resultParse.success, true);
    });

    test(
      'when creating an enumerated nullable validator, and the value is in the list of valid values or nulll, then the result should be successful',
      () {
        final schema = number().nullable().enumerated([1, 2, 3]);
        final result = schema.tryParse(1);

        expect(result.success, true);

        final resultParse = schema.parse(1);
        expect(resultParse.success, true);
      },
    );

    test(
      'when creating an enumerated nullable validator, and the value is not in the list of valid values or null, then the result should be unsuccessful',
      () {
        final schema = number().nullable().enumerated([1, 2, 3]);
        final result = schema.tryParse(4);

        expect(result.success, false);

        expect(() => schema.parse(4), throwsA(TypeMatcher<ValidationError>()));
      },
    );

    test('when creating a list of nullable strings,'
        'and the value is not null, '
        'then the result should be successful', () {
      final nullable = string().nullable().list();

      final result = nullable.tryParse(['This is a test']);

      expect(result.success, true);

      final resultParse = nullable.parse(['This is a test']);

      expect(resultParse.success, true);
    });

    test('when creating a list of nullable strings,'
        'and the value is null, '
        'then the result should be successful', () {
      final nullable = string().nullable().list();

      final result = nullable.tryParse([null]);

      expect(result.success, true);

      final resultParse = nullable.parse([null]);

      expect(resultParse.success, true);
    });

    test('when creating a nullable list of strings,'
        'and the value is not null, '
        'then the result should be successful', () {
      final nullable = string().list().nullable();

      final result = nullable.tryParse(['This is a test']);

      expect(result.success, true);

      final resultParse = nullable.parse(['This is a test']);

      expect(resultParse.success, true);
    });

    test('when creating a nullable list of strings,'
        'and the value is null, '
        'then the result should be successful', () {
      final nullable = string().list().nullable();

      final result = nullable.tryParse(null);

      expect(result.success, true);

      final resultParse = nullable.parse(null);

      expect(resultParse.success, true);
    });

    test('when creating a nullable list of nullable strings,'
        'and the value is not null, '
        'then the result should be successful', () {
      final nullable = string().nullable().list().nullable();

      final result = nullable.tryParse(['This is a test']);

      expect(result.success, true);

      final resultParse = nullable.parse(['This is a test']);

      expect(resultParse.success, true);
    });

    test('when creating a nullable list of nullable strings,'
        'and the value is null, '
        'then the result should be successful', () {
      final nullable = string().nullable().list().nullable();

      final result = nullable.tryParse(null);

      expect(result.success, true);

      final resultParse = nullable.parse(null);

      expect(resultParse.success, true);
    });

    test('when creating a nullable map,'
        'and the value is not null, '
        'then the result should be successful', () {
      final nullable = object({'key': string()}).nullable();

      final result = nullable.tryParse({'key': 'This is a test'});

      expect(result.success, true);

      final resultParse = nullable.parse({'key': 'This is a test'});

      expect(resultParse.success, true);
    });

    test('when creating a nullable map,'
        'and the value is null, '
        'then the result should be successful', () {
      final nullable = object({'key': string()}).nullable();

      final result = nullable.tryParse(null);

      expect(result.success, true);

      final resultParse = nullable.parse(null);

      expect(resultParse.success, true);
    });

    test('when creating a nullable map with nullable values,'
        'and the value is not null, '
        'then the result should be successful', () {
      final nullable = object({'key': string().nullable()}).nullable();

      final result = nullable.tryParse({'key': 'This is a test'});

      expect(result.success, true);

      final resultParse = nullable.parse({'key': 'This is a test'});

      expect(resultParse.success, true);
    });

    test('when creating a nullable map with nullable values,'
        'and the value is null, '
        'then the result should be successful', () {
      final nullable = object({'key': string().nullable()}).nullable();

      final result = nullable.tryParse(null);

      expect(result.success, true);

      final resultParse = nullable.parse(null);

      expect(resultParse.success, true);
    });

    test('when creating a nullable map with nullable keys,'
        'and the value is not null, '
        'then the result should be successful', () {
      final nullable = object({'key': string()}).nullable();

      final result = nullable.tryParse({'key': 'This is a test'});

      expect(result.success, true);

      final resultParse = nullable.parse({'key': 'This is a test'});

      expect(resultParse.success, true);
    });

    test('when creating a nullable map with nullable keys,'
        'and the value is null, '
        'then the result should be successful', () {
      final nullable = object({'key': string()}).nullable();

      final result = nullable.tryParse(null);

      expect(result.success, true);

      final resultParse = nullable.parse(null);

      expect(resultParse.success, true);
    });

    test('when creating a nullable map with a default value,'
        'and the value is null, '
        'then the result should be successful', () {
      final nullable = object({
        'key': string(),
      }).nullable(defaultValue: {'key': 'This is a null value'});

      final result = nullable.tryParse(null);

      expect(result.success, true);

      final resultParse = nullable.parse(null);

      expect(resultParse.success, true);
      expect(resultParse.value, {'key': 'This is a null value'});
    });

    test('when creating a nullable boolean validator, '
        'and the value is null, '
        'then the result should be successful', () {
      final b = boolean().nullable();
      final result = b.tryParse(null);

      expect(result.success, true);

      final resultParse = b.parse(null);

      expect(resultParse.success, true);
    });

    test('when creating a nullable validator,'
        'and use the toJsonSchema method, '
        'then the result should be a valid json schema', () {
      final schema = string().nullable();
      final result = schema.toJsonSchema();

      final expected = {
        'oneOf': [
          {'type': 'string'},
          {'type': 'null'},
        ],
      };
      expect(result, expected);
    });

    test('when creating an enumerated nullable validator,'
        'and use the toJsonSchema method, '
        'then the result should be a valid json schema', () {
      final schema = string().nullable().enumerated(['Hello', 'World']);
      final result = schema.toJsonSchema();

      final expected = {
        'enum': ['Hello', 'World', null],
      };
      expect(result, expected);
    });

    test('when creating a nullable validator,'
        'and use the toJsonSchema method and the metadata, '
        'then the result should be a valid json schema with metadata', () {
      final schema = string().nullable().meta(
        MetadataEntry(title: 'Title', description: 'Description'),
      );
      final result = schema.toJsonSchema();

      final expected = {
        'oneOf': [
          {'type': 'string'},
          {'type': 'null'},
        ],
        'title': 'Title',
        'description': 'Description',
      };
      expect(result, expected);
    });
  });
}
