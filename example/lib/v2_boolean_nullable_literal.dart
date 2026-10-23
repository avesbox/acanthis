import 'package:acanthis/acanthis.dart';

class LabelSchema extends Schema<String, String>
    with ListableSchema<String, String>, NullableSchema<String, String> {
  @override
  String parse(Object? input) => tryParse(input).valueOrThrow;
  @override
  AcanthisOutcome<String> tryParse(Object? input) => input is String
      ? AcanthisValid(input)
      : AcanthisInvalid<String>.withoutValue([
          AcanthisIssue(path: [], code: 'type'),
        ]);
}

void main() {
  final bool enabled = boolean().coerce().parse(' TRUE ');
  final String kind = literal('node').parse('node');
  final List<String?> labels =
      LabelSchema().nullable().list().parse([null, 'Ada']);
  final nullableDefault =
      string().withDefault('child').nullable().withDefault(null);
  final String? value = nullableDefault.parse(null);
  print('$enabled, $kind, $labels, $value');

  final tree = object({
    'kind': literal('node'),
    'enabled': boolean().withDefault(false),
    'next': lazy((parent) => parent.nullable()),
  });
  print(tree.parse({'kind': 'node', 'next': null}));
  print(tree.toJsonSchema(mode: AcanthisSchemaMode.input));
}
