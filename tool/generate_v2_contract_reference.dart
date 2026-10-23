import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:acanthis/acanthis.dart';

void main(List<String> args) async {
  final random = Random(20261015);
  final inputs = <Object?>[
    null,
    true,
    false,
    -0.0,
    0,
    1,
    1.0,
    2,
    2.5,
    -2,
    10,
    1e16,
    9223372036854775807,
    9223372036854775808.0,
    '',
    'a',
    'ab',
    '😀',
    '😀a',
    'forbidden',
    [],
    {},
    [1, 1.0],
    [true, 1],
    [
      {'a': 1, 'b': 2},
      {'b': 2.0, 'a': 1.0},
    ],
    [9223372036854775807, 9223372036854775808.0],
    {'value': 1, 'children': []},
    {
      'value': 1,
      'children': [
        {'value': 2, 'children': []},
      ],
    },
    {
      'value': 1,
      'children': [
        {'value': 'x', 'children': []},
      ],
    },
    for (var i = 0; i < 120; i++)
      i.isEven ? random.nextInt(30) - 10 : random.nextDouble() * 30 - 10,
    for (var i = 0; i < 30; i++)
      List.generate(random.nextInt(5), (_) => random.nextInt(5)),
    for (var i = 0; i < 30; i++)
      {
        'id': i.isEven ? i : '$i',
        'tags': i % 3 == 0 ? ['a', 'b'] : [i],
        if (i % 4 == 0) 'extra': true,
      },
  ];
  final cases = <Map<String, Object?>>[];
  void add(String name, Object? schema, [List<bool>? native]) => cases.add({
    'name': name,
    'schema': schema,
    'inputs': inputs,
    if (native != null) 'native_expected': native,
  });
  final natives = <Schema<Object?, Object?>>[
    number(),
    number().lte(2),
    number().gte(2),
    number().lt(2),
    number().gt(2),
    number().between(2, 4),
    number().positive(),
    number().negative(),
    number().nonPositive(),
    number().nonNegative(),
    number().finite(),
    number().notNaN(),
    number().infinite(),
    number().nan(),
    number().enumerated([1, 1.0, 3]),
    number().exact(2),
    number().gte(2).withDefault(3),
    string(),
    string().required(),
    string().notEmpty(),
    string().contained(['a', '😀']),
    string().exact('😀'),
    string().notEmpty().withDefault('a'),
  ];
  for (var i = 0; i < natives.length; i++) {
    final native = natives[i];
    add('native_$i', native.exportJsonSchema(mode: AcanthisSchemaMode.input), [
      for (final value in inputs) native.tryParse(value).isValid,
    ]);
  }
  final definitions = <Object?>[
    {
      'type': 'object',
      'properties': {
        'value': {'type': 'number'},
        'children': {
          'type': 'array',
          'items': {r'$ref': '#'},
        },
      },
      'required': ['value', 'children'],
      'additionalProperties': false,
    },
    true,
    false,
    {},
    {'type': 'integer'},
    {
      'type': ['number', 'null'],
    },
    {'type': 'boolean'},
    {'type': 'string', 'minLength': 1, 'maxLength': 2},
    {'type': 'number', 'minimum': 9223372036854775808.0},
    {'type': 'number', 'maximum': 9223372036854775807},
    {
      'const': {'a': 1, 'b': 2},
    },
    {'const': 9223372036854775807},
    {
      'enum': [
        true,
        1,
        [1, 2],
        {'id': 'a'},
      ],
    },
    {
      'type': 'array',
      'minItems': 1,
      'maxItems': 3,
      'items': {'type': 'integer'},
    },
    {'uniqueItems': true},
    {'items': false},
    {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer'},
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
      'required': ['id'],
      'additionalProperties': false,
    },
    {
      'type': 'object',
      'properties': {
        'id': {'type': 'integer'},
      },
      'additionalProperties': {'type': 'boolean'},
    },
    {'minProperties': 1, 'maxProperties': 2},
    {
      'required': ['id'],
    },
    {
      'allOf': [
        {'minimum': 0},
        {'maximum': 4},
      ],
    },
    {
      'anyOf': [
        {'type': 'string'},
        {'type': 'number', 'minimum': 1},
      ],
    },
    {
      'not': {'const': 'forbidden'},
    },
    {
      r'$defs': {
        'a/~': {'type': 'integer', 'minimum': 0},
      },
      r'$ref': r'#/$defs/a~1~0',
      'maximum': 4,
    },
    {
      r'$defs': {
        'n': {'type': 'number'},
      },
      'type': 'array',
      'items': {r'$ref': r'#/$defs/n'},
    },
  ];
  for (var i = 0; i < definitions.length; i++) {
    add('json_$i', definitions[i]);
  }
  final request = File('.dart_tool/contract-reference-input.json');
  request.writeAsStringSync(jsonEncode(cases));
  final result = await Process.run(args.isEmpty ? 'python' : args.first, [
    'tool/contract_reference.py',
    request.path,
    'test/fixtures/contract_reference.json',
  ]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) exit(result.exitCode);
}
