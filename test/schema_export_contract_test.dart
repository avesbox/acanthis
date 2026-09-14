import 'dart:convert';
import 'dart:io';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  test(
    'input and output export use distinct presence and unknown-key contracts',
    () {
      final schema = object({
        'name': string().withDefault('guest'),
        'note': string().nullable(),
        'optional': string(),
      }).optionals(['optional']);
      final input = schema.exportJsonSchema(mode: AcanthisSchemaMode.input);
      final output = schema.exportJsonSchema(mode: AcanthisSchemaMode.output);
      expect(input['required'], ['note']);
      expect(output['required'], ['name', 'note']);
      expect(input['additionalProperties'], true);
      expect(output['additionalProperties'], false);
      expect(input['properties']['name'], {
        'anyOf': [
          {'type': 'string'},
          {'type': 'null'},
        ],
      });
      expect(output['properties']['name'], {'type': 'string'});
      expect(
        schema.exportOpenApiSchema(mode: AcanthisSchemaMode.output),
        Map.of(output)..remove(r'$schema'),
      );
      expect(
        schema.patch().exportJsonSchema(
          mode: AcanthisSchemaMode.output,
        )['required'],
        isEmpty,
      );
    },
  );

  test('nested and nullable default contracts propagate the chosen mode', () {
    final schema = object({
      'rows': object({'name': string().nullable(defaultValue: 'guest')}).list(),
    });
    final input = schema.exportJsonSchema(mode: AcanthisSchemaMode.input);
    final output = schema.exportJsonSchema(mode: AcanthisSchemaMode.output);
    expect(input['properties']['rows']['items']['required'], isEmpty);
    expect(output['properties']['rows']['items']['required'], ['name']);
    expect(output['properties']['rows']['items']['properties']['name'], {
      'type': 'string',
    });
  });

  test('unsupported behavior fails with a useful schema path', () {
    for (final field in <AcanthisType>[
      string().min(2),
      string().coerce(),
      date(),
      integer(),
      doubleType(),
      string().transform((value) => value.toUpperCase()),
      union<String>([variant<String>(guard: (_) => true, schema: string())]),
    ]) {
      expect(
        () =>
            object({'a/b': field})
                .exportJsonSchema(mode: AcanthisSchemaMode.input),
        throwsA(
          isA<AcanthisSchemaExportException>().having(
            (e) => e.path,
            'path',
            '/a~1b',
          ),
        ),
      );
    }
  });

  test('shared structural corpus for independent JSON Schema validation', () async {
    final cases = <Map<String, dynamic>>[];
    final schemas = <AcanthisMap<dynamic>>[
      object({'name': number()}),
      object({'name': string()}),
      object({'name': string().nullable()}),
      object({'name': string()}).optionals(['name']),
      object({'name': string().nullable()}).optionals(['name']),
      object({'name': string().withDefault('guest')}),
      object({'name': string().nullable(defaultValue: 'guest')}),
      object({'name': string().withDefault('guest')}).patch(),
      object({'name': string()}).unknownKeys(AcanthisUnknownKeys.reject),
      object({'name': string()}).passthrough(),
      object({'name': string()}).passthrough(type: string()),
      object({
        'name': object({'nested': string().withDefault('guest')}),
      }),
      object({'name': string().nullable().list()}),
      object({
        'name': union<dynamic>([string(), boolean()]),
      }),
    ];
    for (final schema in schemas) {
      for (final input in <Map<String, dynamic>>[
        {},
        {'name': null},
        {'name': 'Ada'},
        {'name': 42},
        {'name': 42.0},
        {'name': true},
        {'name': 'Ada', 'extra': 1},
        {'name': 'Ada', 'extra': 'ok'},
        {'name': <String, dynamic>{}},
        {
          'name': ['Ada', null],
        },
      ]) {
        final result = schema.tryParse(input);
        cases.add({
          'inputSchema': schema.exportJsonSchema(
            mode: AcanthisSchemaMode.input,
          ),
          'outputSchema': schema.exportJsonSchema(
            mode: AcanthisSchemaMode.output,
          ),
          'input': input,
          'valid': result.success,
          if (result.success) 'output': result.value,
        });
      }
    }
    // Optional output path lets the external dialect validator consume exactly
    // the same runtime observations without adding a Python runtime dependency.
    final outputPath = Platform.environment['EXPORT_CORPUS_PATH'];
    if (outputPath != null) {
      File(outputPath).writeAsStringSync(jsonEncode(cases));
    }
    expect(cases.length, 140);
  });
}

