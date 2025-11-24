import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

class _User {
  final String name;
  final int age;

  const _User({required this.name, required this.age});

  @override
  bool operator ==(Object other) {
    return other is _User && other.name == name && other.age == age;
  }

  @override
  int get hashCode => Object.hash(name, age);

  @override
  String toString() => '_User(name: $name, age: $age)';
}

void main() {
  group('ClassSchemaBuilder', () {
    test('throws when build is called without an input schema', () {
      final builder = classSchema<Map<String, dynamic>, _User>().map(
        (_) => const _User(name: 'fallback', age: 0),
      );

      expect(
        () => builder.build(),
        throwsA(
          isA<StateError>().having(
            (err) => err.message,
            'message',
            contains('input()'),
          ),
        ),
      );
    });

    test('throws when build is called without a mapper', () {
      final builder = classSchema<Map<String, dynamic>, _User>().input(
        object({}),
      );

      expect(
        () => builder.build(),
        throwsA(
          isA<StateError>().having(
            (err) => err.message,
            'message',
            contains('map()'),
          ),
        ),
      );
    });

    test('composes input validation, mapping and output refinement', () {
      final pipeline = classSchema<Map<String, dynamic>, _User>()
          .input(object({'name': string().min(1), 'age': number().gte(0)}))
          .map(
            (payload) => _User(
              name: payload['name'] as String,
              age: (payload['age'] as num).toInt(),
            ),
          )
          .validateWith(
            instance<_User>()
                .field('name', (user) => user.name, string().min(2))
                .field('age', (user) => user.age, number().gte(0)),
          )
          .refine(
            name: 'adult',
            error: 'Age must be at least 18',
            onCheck: (user) => user.age >= 18,
          )
          .defaultOutput(const _User(name: 'fallback', age: 0))
          .build();

      final success = pipeline.parse({'name': 'Alice', 'age': 21});
      expect(success.value, equals(const _User(name: 'Alice', age: 21)));

      final missingField = pipeline.tryParse({'age': 21});
      expect(missingField.success, isFalse);
      expect(missingField.value, equals(const _User(name: 'fallback', age: 0)));

      final invalidOutput = pipeline.tryParse({'name': 'A', 'age': 21});
      expect(invalidOutput.success, isFalse);
      expect(invalidOutput.errors.keys, contains('name.minLength'));

      final refineFailure = pipeline.tryParse({'name': 'Adam', 'age': 16});
      expect(refineFailure.success, isFalse);
      expect(refineFailure.errors.keys, contains('adult'));
      expect(refineFailure.value, equals(const _User(name: 'Adam', age: 16)));
    });
  });
}
