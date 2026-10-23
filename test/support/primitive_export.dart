import 'dart:convert';
import 'dart:io';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void testPrimitiveExports(
  String kind,
  Map<String, Schema<Object?, Object?>> cases,
) {
  final corpus = <Map<String, Object?>>[];
  final inputs = <Object?>[
    null,
    true,
    false,
    0,
    1,
    1.0,
    2,
    'ok',
    'other',
    '',
    [],
    [null],
    [true],
    [false],
    [null, false],
    [null, true],
    [true, true],
    [null, null],
    [false, false],
    [true, false],
    ['ok'],
    [1],
    {},
    {'enabled': null},
    {'enabled': true},
    {'enabled': false},
    {'enabled': 1},
    {'kind': null},
    {'kind': true},
    {'other': false},
    {'tag': 'node', 'next': null},
    {
      'tag': 'node',
      'enabled': false,
      'next': {'tag': 'node', 'next': null},
    },
    {'tag': 'other', 'next': null},
  ];
  for (final entry in cases.entries) {
    test('${entry.key} exports input/output semantics in JSON and OpenAPI', () {
      final inputSchema = entry.value.toJsonSchema(
        mode: AcanthisSchemaMode.input,
      );
      final outputSchema = entry.value.toJsonSchema(
        mode: AcanthisSchemaMode.output,
      );
      final openApiInput = entry.value.toOpenApiSchema(
        mode: AcanthisSchemaMode.input,
      );
      final openApiOutput = entry.value.toOpenApiSchema(
        mode: AcanthisSchemaMode.output,
      );
      final accepted = fromJsonSchema(inputSchema);
      final produced = fromJsonSchema(outputSchema);
      for (final input in inputs) {
        final native = entry.value.tryParse(input);
        expect(
          accepted.validate(input),
          native.isValid,
          reason: '${entry.key}: ${jsonEncode(input)}',
        );
        if (native.isValid) {
          expect(
            produced.validate(native.value),
            isTrue,
            reason: '${entry.key}: output ${jsonEncode(native.value)}',
          );
        }
        corpus.add({
          'inputSchema': inputSchema,
          'outputSchema': outputSchema,
          'openApiInput': openApiInput,
          'openApiOutput': openApiOutput,
          'input': input,
          'valid': native.isValid,
          if (native.isValid) 'output': native.value,
        });
      }
    });
  }

  tearDownAll(() {
    final path = Platform.environment['${kind.toUpperCase()}_EXPORT_CORPUS'];
    if (path != null) File(path).writeAsStringSync(jsonEncode(corpus));
  });
}
