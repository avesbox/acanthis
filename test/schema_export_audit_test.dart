import 'dart:convert';
import 'dart:io';

import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:test/test.dart';

void main() {
  test('metadata cannot change validation or reference keywords', () {
    final schema = number()
        .gte(0)
        .meta(
          const MetadataEntry<num>(
            title: 'Score',
            description: 'A nonnegative score',
            deprecated: true,
            readOnly: true,
            writeOnly: false,
            format: 'custom',
            otherProperties: {
              'type': 'string',
              'minimum': -100,
              r'$ref': '#/missing',
            },
          ),
        )
        .exportJsonSchema(mode: AcanthisSchemaMode.input);
    expect(schema['title'], 'Score');
    expect(schema['description'], 'A nonnegative score');
    expect(schema['deprecated'], true);
    expect(schema['readOnly'], true);
    expect(schema['writeOnly'], false);
    expect(schema['type'], 'number');
    expect(schema['allOf'], [
      {'minimum': 0},
    ]);
    expect(schema.containsKey(r'$ref'), false);
    expect(schema.containsKey('format'), false);
  });

  test('failed recursive export does not affect later exports', () {
    final broken = object({
      'children': lazy((parent) => parent.list()),
      'bad': string().min(2),
    });
    expect(
      () => broken.exportJsonSchema(mode: AcanthisSchemaMode.input),
      throwsA(isA<AcanthisSchemaExportException>()),
    );
    final valid = object({'children': lazy((parent) => parent.list())});
    expect(
      jsonEncode(valid.exportJsonSchema(mode: AcanthisSchemaMode.input)),
      contains(r'"$ref":"#/$defs/schema0"'),
    );
    expect(
      string()
          .exportJsonSchema(mode: AcanthisSchemaMode.input)
          .containsKey(r'$defs'),
      false,
    );
  });

  test(
    'constraints and recursion agree across parse modes and export dialects',
    () async {
      final tree = object({
        'value': number().gte(0).lt(10),
        'children': lazy((parent) => parent.list().max(2)),
      });
      final linked = object({
        'value': string().notEmpty().withDefault('node'),
        'next': lazy((parent) => parent.nullable()),
      });
      final schemas = <AcanthisType>[
        number().gte(2).lte(4),
        number().gt(2).lt(4),
        number().between(2, 4),
        number().gte(4).gte(2),
        number().gte(4).lte(2),
        number().positive(),
        number().negative(),
        number().nonPositive(),
        number().nonNegative(),
        number().finite(),
        number().notNaN(),
        number().infinite(),
        number().nan(),
        number().enumerated([2, 2.0, 4]),
        number().exact(2),
        number().gte(2).withDefault(3),
        boolean().isTrue(),
        boolean().isFalse(),
        string().required(),
        string().notEmpty(),
        string().exact('😀'),
        string().contained(['a', 'a', '😀']),
        string().notEmpty().nullable(),
        string().notEmpty().nullable(defaultValue: 'node'),
        number().list().min(1).max(2),
        number().list().length(2),
        number().list().min(-1),
        number().list().max(-1),
        number().list().length(-1),
        number().withDefault(3).list().length(1),
        union<num>([number().gte(0), number().lte(4)]),
        tree,
        linked,
        object({'left': tree, 'right': tree}),
        object({'a/~': linked}).unknownKeys(AcanthisUnknownKeys.reject),
        object({'value': number().gte(0).withDefault(1)}).patch(),
        object({'value': number().gte(0)}).passthrough(type: number().lt(5)),
      ];
      final inputs = <dynamic>[
        null,
        false,
        true,
        -1,
        0,
        1,
        2,
        2.0,
        2.5,
        3,
        4,
        5,
        10,
        '',
        'a',
        '😀',
        'a\n',
        [],
        [null],
        [1],
        [1, 2],
        [1, 2, 3],
        ['bad'],
        {},
        {'value': null},
        {'value': 0},
        {'value': -1},
        {'value': 1, 'extra': 4},
        {'value': 1, 'extra': 5},
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
            {'value': -1, 'children': []},
          ],
        },
        {
          'value': 1,
          'children': [
            {'value': 2},
          ],
        },
        {
          'value': 1,
          'children': [null],
        },
        {'value': 'a', 'next': null},
        {'next': null},
        {
          'value': 'a',
          'next': {'next': null, 'extra': true},
        },
        {'value': '', 'next': null},
        {
          'a/~': {'next': null},
        },
        {
          'left': {'value': 1, 'children': []},
          'right': {'value': 2, 'children': []},
        },
      ];
      final cases = <Map<String, dynamic>>[];
      for (var index = 0; index < schemas.length; index++) {
        final schema = schemas[index];
        final inputSchema = schema.exportJsonSchema(
          mode: AcanthisSchemaMode.input,
        );
        final outputSchema = schema.exportJsonSchema(
          mode: AcanthisSchemaMode.output,
        );
        final openApiInput = schema.exportOpenApiSchema(
          mode: AcanthisSchemaMode.input,
        );
        final openApiOutput = schema.exportOpenApiSchema(
          mode: AcanthisSchemaMode.output,
        );
        expect(openApiInput, Map.of(inputSchema)..remove(r'$schema'));
        expect(openApiOutput, Map.of(outputSchema)..remove(r'$schema'));
        // Reference allocation is deterministic and local to each export call.
        expect(
          schema.exportJsonSchema(mode: AcanthisSchemaMode.input),
          inputSchema,
        );
        for (final input in inputs) {
          final result = schema.tryParse(input);
          final asyncResult = await schema.tryParseAsync(input);
          expect(
            asyncResult.success,
            result.success,
            reason: 'schema $index input $input',
          );
          expect(schema.validate(input).isValid, result.success);
          if (result.success) {
            expect(asyncResult.value, result.value);
            expect(schema.parse(input).value, result.value);
            expect((await schema.parseAsync(input)).value, result.value);
          }
          cases.add({
            'label': 'schema $index',
            'inputSchema': inputSchema,
            'outputSchema': outputSchema,
            'openApiInput': openApiInput,
            'openApiOutput': openApiOutput,
            'input': input,
            'valid': result.success,
            if (result.success) 'output': result.value,
          });
        }
      }
      final outputPath = Platform.environment['EXPORT_AUDIT_CORPUS_PATH'];
      if (outputPath != null) {
        File(outputPath).writeAsStringSync(jsonEncode(cases));
      }
      expect(cases.length, greaterThan(1000));
    },
  );

  test('unsupported checks cannot impersonate built-ins through names', () {
    final schemas = <AcanthisType>[
      number().withCheck(
        CustomCheck<num>((_) => false, name: 'gte', parameters: {'value': 0}),
      ),
      number().gte(double.infinity),
      number().enumerated([double.nan]),
      number().integer(),
      number().double(),
      number().multipleOf(2),
      string().min(2),
      string().max(2),
      string().email(),
      string().pattern('a'),
      object({}).minProperties(1),
      number().list().unique(),
      object({
        'child': lazy((parent) => parent.list())
            .withCheck(CustomCheck((_) => true)),
      }),
      object({
        'child': lazy((_) => throw StateError('private callback detail')),
      }),
      object({'child': lazy((parent) => parent.passthrough().list())}),
    ];
    for (final schema in schemas) {
      for (final mode in AcanthisSchemaMode.values) {
        expect(
          () => object({'a/~': schema}).exportJsonSchema(mode: mode),
          throwsA(
            isA<AcanthisSchemaExportException>().having(
              (e) => e.path,
              'path',
              startsWith('/a~1~0'),
            ),
          ),
        );
      }
    }
  });
}
