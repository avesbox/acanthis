import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  group('$AcanthisTemplate', () {
    test('matches an exact literal string', () {
      final schema = template(['hi there']);

      expect(schema.parse('hi there'), isA<String>());
      expect(() => schema.parse('hi'), throwsA(isA<ValidationError>()));

      final result = schema.tryParse('hi');
      expect(result.isValid, isFalse);
      expect(result.errors.containsKey('templateLiteral'), isTrue);
    });

    test('supports string placeholder segments', () {
      final schema = template(['email: ', string()]);

      expect(schema.parse('email: john@doe.dev'), isA<String>());
      expect(
        () => schema.parse('email john@doe.dev'),
        throwsA(isA<ValidationError>()),
      );
    });

    test('supports literal segments', () {
      final schema = template(['high', literal(5)]);

      expect(schema.parse('high5'), isA<String>());
      expect(() => schema.parse('high6'), throwsA(isA<ValidationError>()));
    });

    test('supports nullable literal segments', () {
      final schema = template([literal('grassy').nullable()]);

      expect(schema.parse('grassy'), isA<String>());
      expect(schema.parse('null'), isA<String>());
      expect(schema.tryParse('other').isValid, isFalse);
    });

    test('supports enums with numeric placeholders', () {
      final schema = template([number(), string().enumerated(SizeUnit.values)]);

      expect(schema.parse('12px'), isA<String>());
      expect(schema.parse('3em'), isA<String>());
      expect(schema.parse('1.5rem'), isA<String>());
      expect(schema.tryParse('12kg').isValid, isFalse);
    });

    test('supports coercion before template matching', () {
      final schema = template(['id_', literal(5)]).coerce();

      expect(schema.parse('id_5'), isA<String>());
      expect(schema.tryParse(5).isValid, isFalse);
    });
  });
}

enum SizeUnit { px, em, rem }
