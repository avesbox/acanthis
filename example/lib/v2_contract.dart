import 'dart:convert';

import 'package:acanthis/acanthis.dart' as acanthis;

void main() {
  final schema = acanthis.number().gte(0).lte(10).withDefault(3);
  final definition =
      schema.exportJsonSchema(mode: acanthis.AcanthisSchemaMode.input);
  final contract = acanthis.importJsonSchema(definition);
  print(jsonEncode(definition));
  print('5 accepted: ${contract.validate(5)}');
  print('11: ${contract.tryParse(11).issues.single.message}');

  final documentContract = acanthis.importOpenApiSchema({
    'type': 'object',
    'properties': {
      'name': {'type': 'string', 'minLength': 1},
      'scores': {
        'type': 'array',
        'items': {'type': 'number', 'minimum': 0}
      },
    },
    'required': ['name', 'scores'],
    'additionalProperties': false,
  });
  final result = documentContract.tryParse({
    'name': '',
    'scores': [1, -2]
  });
  for (final issue in result.issues) {
    print('${issue.jsonPointer}: ${issue.message}');
  }
}
