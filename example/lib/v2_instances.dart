import 'package:acanthis/acanthis.dart';

final class User {
  const User(this.name, this.age);
  final String name;
  final int age;
}

Future<void> main() async {
  final userType = instance<User>()
      .field('name', (u) => u.name, string().min(2))
      .field('age', (u) => u.age, integer().gte(18))
      .withRefs((refs) => refs.ref('minimumAge', (_) => 18))
      .refineWithRefs((u, refs) => u.age >= refs.call<int>('minimumAge'),
          'User must be an adult',
          name: 'app.adult');
  final schema = classSchema<Map<String, Object?>, User>()
      .input(object({'name': string().trim(), 'age': integer()}))
      .map((data) => User(data['name'] as String, data['age'] as int))
      .validateWith(userType)
      .build();

  final user = await schema.parseAsync({'name': ' Ada ', 'age': 21});
  if (user.name != 'Ada' || !identical(userType.parse(user), user)) {
    throw StateError('Class mapping or instance identity changed');
  }
  final invalid = schema.tryParse({'name': 'Ada', 'age': 17});
  if (invalid.isValid || invalid.issues.first.path.single != 'age') {
    throw StateError('Expected a field diagnostic at age');
  }
  print(userType.toMap(user));
}
