import 'dart:convert';

import 'package:acanthis/acanthis.dart';

final class User {
  const User(this.name, this.score);
  final String name;
  final num score;
}

void main() {
  final fields = instance<User>()
      .field('name', (u) => u.name, string())
      .field('score', (u) => u.score, number().gte(0).lte(10))
      .withFactory(
          (values) => User(values['name'] as String, values['score'] as num));
  final description = fields.toJsonSchema();
  final sample = fields.mockSeeded(seed: 42);
  if (!fields.validate(sample) || description['type'] != 'object') {
    throw StateError('Instance generation or field export failed');
  }
  print(jsonEncode(fields.toMap(sample)));

  final mapped = classSchema<Map<String, Object?>, User>()
      .input(object({
        'displayName': string().exact('Ada'),
        'score': number().between(0, 10)
      }))
      .map((values) =>
          User(values['displayName'] as String, values['score'] as num))
      .validateWith(fields)
      .build();
  final inputSample = mapped.inType.mockSeeded(seed: 42);
  final user = mapped.parse(inputSample);
  if (user.name != 'Ada') throw StateError('Class mapping failed');
  print(
      jsonEncode(mapped.outType.toJsonSchema(mode: AcanthisSchemaMode.output)));
}
