import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  group('AcanthisType.mock', () {
    test('boolean mock is deterministic with same seed', () {
      final schema = boolean();

      final first = schema.mock(42);
      final second = schema.mock(42);

      expect(first, equals(second));
      expect(first, isA<bool>());
    });

    test('number mocks return expected numeric types', () {
      final numberSchema = number().gte(10).lte(20);
      final intSchema = integer().gte(1).lte(3);
      final doubleSchema = doubleType().gte(1).lte(2);

      final numberResult = numberSchema.mock(1);
      final intResult = intSchema.mock(1);
      final doubleResult = doubleSchema.mock(1);

      expect(numberResult, inInclusiveRange(10, 20));
      expect(intResult, inInclusiveRange(1, 3));
      expect(intResult, isA<int>());
      expect(doubleResult, inInclusiveRange(1.0, 2.0));
      expect(doubleResult, isA<double>());
    });

    test('string mock supports exact and enum constraints', () {
      final exactSchema = string().exact('fixed-value');
      final enumSchema = string().enumerated(_MockEnum.values);

      final exactResult = exactSchema.mock(7);
      final enumResult = enumSchema.mock(7);

      expect(exactResult, equals('fixed-value'));
      expect(
        enumResult,
        isIn(_MockEnum.values.map((value) => value.name).toList()),
      );
    });

    test('string mock is deterministic with same seed', () {
      final schema = string().min(4).max(8);

      final first = schema.mock(7);
      final second = schema.mock(7);

      expect(first, equals(second));
      expect(first, isA<String>());
      expect(first.length, inInclusiveRange(4, 8));
    });

    test('date mock returns value within min/max range', () {
      final min = DateTime(2020, 1, 1);
      final max = DateTime(2020, 12, 31);
      final schema = date().min(min).max(max);

      final result = schema.mock(7);

      expect(result.isBefore(min), isFalse);
      expect(result.isAfter(max), isFalse);
    });

    test('list mock returns values with configured length', () {
      final schema = list(string()).anyOf(['alpha', 'beta']).length(2);

      final result = schema.mock(9);

      expect(result, hasLength(2));
      expect(result, everyElement(isIn(['alpha', 'beta'])));
    });

    test('literal mock returns literal value', () {
      final schema = literal('hello');

      expect(schema.mock(123), equals('hello'));
    });

    test('map mock returns mocked values for fields', () {
      final schema = object({
        'name': literal('Alice'),
        'age': integer().gte(18).lte(65),
      });

      final result = schema.mock(3);

      expect(result['name'], equals('Alice'));
      expect(result['age'], inInclusiveRange(18, 65));
    });

    test('nullable mock is deterministic with same seed', () {
      final schema = string().exact('value').nullable();

      final first = schema.mock(1);
      final second = schema.mock(1);

      expect(first, equals(second));
      expect(first == null || first == 'value', isTrue);
    });

    test('tuple mock returns one mocked value per element', () {
      final schema = tuple([literal('value'), integer().gte(2).lte(2)]);

      final result = schema.mock(3);

      expect(result, hasLength(2));
      expect(result[0], equals('value'));
      expect(result[1], equals(2));
    });

    test('union mock returns a mocked value from first type', () {
      final schema = union([literal('first'), integer().gte(1).lte(1)]);

      final result = schema.mock(5);

      expect(result, equals('first'));
    });

    test('empty union mock throws unimplemented error', () {
      final schema = union([]);

      expect(() => schema.mock(1), throwsA(isA<UnimplementedError>()));
    });

    test('pipeline mock transforms the input mock value', () {
      final schema = literal(
        'abcd',
      ).pipe(number().integer(), transform: (value) => value.length);

      final result = schema.mock(1);

      expect(result, equals(4));
    });

    test('instance mock throws unimplemented error', () {
      final schema = instance<_MockClass>();

      expect(() => schema.mock(1), throwsA(isA<UnimplementedError>()));
    });

    test('template mock throws unimplemented error', () {
      final schema = template(['prefix-', string()]);

      expect(() => schema.mock(1), throwsA(isA<UnimplementedError>()));
    });

    test('lazy mock throws unimplemented error', () {
      final schema = lazy<String>((_) => string());

      expect(() => schema.mock(1), throwsA(isA<UnimplementedError>()));
    });
  });
}

class _MockClass {}

enum _MockEnum { first, second, third }
