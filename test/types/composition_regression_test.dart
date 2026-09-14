import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  group('composition regressions', () {
    test('nested union reports an invalid literal', () {
      final schema = object({
        'kind': union<String>([literal('a'), literal('b')]),
      });

      final result = schema.tryParse({'kind': 'c'});

      expect(result.success, isFalse);
      expect(result.errors['kind'], contains('union'));
    });

    test('nested tuple reports invalid values and length', () {
      final schema = object({
        'value': tuple([string()]),
      });

      final result = schema.tryParse({
        'value': [42, 43],
      });

      expect(result.success, isFalse);
      expect(result.errors, contains('value'));
    });

    test('nullable transformation runs exactly once', () {
      final schema = string().transform((value) => '${value}x').nullable();

      expect(schema.parse('a').value, 'ax');
      expect(schema.tryParse('a').value, 'ax');
    });

    test('literal uses its specialised rules through parseAsync', () async {
      final result = await literal('a').tryParseAsync('b');

      expect(result.success, isFalse);
      expect(result.errors, contains('literal'));
    });

    test('composites return type errors instead of throwing in tryParse', () {
      expect(object({'value': string()}).tryParse(42).success, isFalse);
      expect(string().list().tryParse(42).success, isFalse);
    });

    test('a nested async rule disables synchronous parsing', () {
      final schema = object({
        'value': string().refineAsync(
          onCheck: (_) async => false,
          error: 'unavailable',
          name: 'remote',
        ),
      });

      expect(schema.isAsync, isTrue);
      expect(
        () => schema.tryParse({'value': 'a'}),
        throwsA(isA<AsyncValidationException>()),
      );
    });

    test(
      'maps consistently strip unknown keys in synchronous and async parsing',
      () async {
        final schema = object({'value': string()});

        expect(schema.parse({'value': 'a', 'extra': true}).value, {
          'value': 'a',
        });
        expect((await schema.parseAsync({'value': 'a', 'extra': true})).value, {
          'value': 'a',
        });
      },
    );

    test('an explicit null is validated rather than treated as absent', () {
      final result = object({'value': string()}).tryParse({'value': null});

      expect(result.success, isFalse);
      expect(result.errors['value'], contains('type'));
      expect(result.errors['value'], isNot(contains('required')));
    });

    test('async union discards diagnostics from failed branches', () async {
      final schema = union<String>([
        string().refineAsync(
          onCheck: (_) async => false,
          error: 'first branch rejected',
          name: 'first',
        ),
        string().refineAsync(
          onCheck: (_) async => true,
          error: 'second branch rejected',
          name: 'second',
        ),
      ]);

      final result = await schema.tryParseAsync('b');

      expect(result.success, isTrue);
      expect(result.errors, isEmpty);
      expect(result.value, 'b');
    });

    test('built pipelines snapshot their builder mapper', () {
      final builder = classSchema<String, String>()
        ..input(string())
        ..map((value) => '${value}1');
      final schema = builder.build();
      builder.map((value) => '${value}2');

      expect(schema.parse('a').value, 'a1');
    });

    test('literal JSON schema uses the standard const keyword', () {
      expect(literal('a').toJsonSchema(), {'const': 'a'});
    });

    test('literals support fluent checks and async checks', () async {
      final sync = literal('a').refine(
        onCheck: (value) => value == 'a',
        error: 'unexpected',
        name: 'refined',
      );
      final async = literal('a').refineAsync(
        onCheck: (_) async => true,
        error: 'unexpected',
        name: 'remote',
      );

      expect(sync.parse('a').success, isTrue);
      expect((await async.tryParseAsync('a')).success, isTrue);
    });
  });
}
