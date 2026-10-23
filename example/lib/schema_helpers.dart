import 'package:acanthis/acanthis.dart';

final class User {
  const User(this.name, this.age);
  final String name;
  final int age;
}

void main() {
  final schema = classSchema<Map<String, Object?>, User>()
      .input(object(
          {'name': string().min(2).max(20), 'age': integer().gte(18).lte(80)}))
      .map((f) => User(f['name'] as String, f['age'] as int))
      .validateWith(
          instance<User>().field('age', (u) => u.age, integer().gte(21)))
      .build();
  final user = schema.mockSeeded(seed: 42);
  if (user.age < 21) throw StateError('Mock output validation was skipped');
  final issue = object({'name': string()}).tryParse({}).issues.single;
  if (issue.code != AcanthisIssueCodes.required) {
    throw StateError('Issue code changed');
  }
  print('${user.name}: ${user.age}');
  print(object({'enabled': boolean()}).toPrettyJsonSchema(indent: 4));
}
