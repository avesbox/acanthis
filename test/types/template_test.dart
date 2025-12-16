import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  group('$AcanthisTemplate', () {
    test('matches an exact literal string', () {
      final schema = template(['hi there']);

      expect(schema.parse('hi there').success, isTrue);
      expect(() => schema.parse('hi'), throwsA(isA<ValidationError>()));

      final result = schema.tryParse('hi');
      expect(result.success, isFalse);
      expect(result.errors.containsKey('templateLiteral'), isTrue);
    });

    test('supports string placeholder segments', () {
      final schema = template(['email: ', string()]);

      expect(schema.parse('email: john@doe.dev').success, isTrue);
      expect(() => schema.parse('email john@doe.dev'),
          throwsA(isA<ValidationError>()));
    });

    test('supports literal segments', () {
      final schema = template(['high', literal(5)]);

      expect(schema.parse('high5').success, isTrue);
      expect(() => schema.parse('high6'), throwsA(isA<ValidationError>()));
    });

    test('supports nullable literal segments', () {
      final schema = template([literal('grassy').nullable()]);

      expect(schema.parse('grassy').success, isTrue);
      expect(schema.parse('null').success, isTrue);
      expect(schema.tryParse('other').success, isFalse);
    });

    test('supports enums with numeric placeholders', () {
      final schema = template([
        number(),
        string().enumerated(SizeUnit.values),
      ]);

      expect(schema.parse('12px').success, isTrue);
      expect(schema.parse('3em').success, isTrue);
      expect(schema.parse('1.5rem').success, isTrue);
      expect(schema.tryParse('12kg').success, isFalse);
    });
  });
}

enum SizeUnit { px, em, rem }