import 'package:acanthis/acanthis.dart';
import 'package:acanthis/acanthis.dart' as acanthis;
import 'package:test/test.dart';

void main() {
  group('$AcanthisTuple', () {
    test("Can be created using `const`", () {
      const AcanthisTuple([]);
    });
    test('when creating a tuple validator,'
        'and the tuple is valid, '
        'then the result should be successful', () {
      final tuple = acanthis.tuple([acanthis.string(), acanthis.number()]);
      final result = tuple.tryParse(['Hello', 5]);

      expect(result.success, true);

      final resultParse = tuple.parse(['Hello', 5]);

      expect(resultParse.success, true);
    });

    test('when creating a tuple validator,'
        'and the tuple is invalid, '
        'then the result should be unsuccessful', () {
      final tuple = acanthis.tuple([acanthis.string(), acanthis.number()]);
      final result = tuple.tryParse(['Hello', '5']);

      expect(result.success, false);

      expect(
        () => tuple.parse(['Hello', '5']),
        throwsA(TypeMatcher<ValidationError>()),
      );
    });

    test('when creating a variadic tuple validator,'
        'and the tuple is valid, '
        'then the result should be successful', () {
      final tuple =
          acanthis.tuple([acanthis.string(), acanthis.number()]).variadic();
      final result = tuple.tryParse(['Hello', 5, 10, 20]);

      expect(result.success, true);

      final resultParse = tuple.parse(['Hello', 5, 10, 20]);

      expect(resultParse.success, true);
    });

    test('when creating a variadic tuple validator,'
        'and the tuple is invalid, '
        'then the result should be unsuccessful', () {
      final tuple =
          acanthis.tuple([acanthis.string(), acanthis.number()]).variadic();
      final result = tuple.tryParse(['Hello', '5']);

      expect(result.success, false);

      expect(
        () => tuple.parse(['Hello', '5']),
        throwsA(TypeMatcher<ValidationError>()),
      );
    });
  });
}
