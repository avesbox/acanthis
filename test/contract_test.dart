import 'support/parse_result.dart';

import 'dart:convert';
import 'dart:io';

import 'package:acanthis/acanthis.dart';
import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

void main() {
  final primitiveCorpus = <Map<String, Object?>>[];
  test('strict exports retain V1 constraints and distinct default modes', () {
    final schema = number().gte(2).lte(4).withDefault(3);
    final input = schema.exportJsonSchema(mode: AcanthisSchemaMode.input);
    final output = schema.exportJsonSchema(mode: AcanthisSchemaMode.output);
    expect(input, {
      r'$schema': 'https://json-schema.org/draft/2020-12/schema',
      'anyOf': [
        {
          'type': 'number',
          'allOf': [
            {'minimum': 2},
            {'maximum': 4},
          ],
        },
        {'type': 'null'},
      ],
    });
    expect(output['type'], 'number');
    expect(output['allOf'], [
      {'minimum': 2},
      {'maximum': 4},
    ]);
    expect(
      schema.exportOpenApiSchema(mode: AcanthisSchemaMode.output),
      Map.of(output)..remove(r'$schema'),
    );
    expect(importJsonSchema(input).parseResult(null).isValid, isTrue);
    expect(importJsonSchema(output).parseResult(null).isValid, isFalse);
  });

  test('export caches return independent mutable snapshots', () {
    final schema = number().enumerated([1, 2]);
    for (var i = 0; i < 4; i++) {
      final exported = schema.exportJsonSchema(mode: AcanthisSchemaMode.input);
      expect(exported['allOf'], [
        {
          'enum': [1, 2],
        },
      ]);
      ((exported['allOf'] as List).single['enum'] as List).clear();
      exported['type'] = 'string';
    }
    expect(schema.parseResult(1).isValid, isTrue);
  });

  test(
    'unaudited runtime behavior rejects export without executing callbacks',
    () {
      var calls = 0;
      final candidates = <Schema<Object?, Object?>>[
        integer(),
        doubleType(),
        number().coerce(),
        string().coerce(),
        string().min(2),
        number().multipleOf(2),
        number().integer(),
        number().gte(double.infinity),
        number().exact(9223372036854775807),
        number().withDefault(double.nan),
        number().gte(3).withDefault(1),
        number().refine(
          onCheck: (_) {
            calls++;
            return true;
          },
        ),
        number().transform((v) {
          calls++;
          return v;
        }),
        string().refineAsync(
          CallbackAsyncCheck((v, c) async {
            calls++;
          }),
        ),
        _CustomSchema(),
      ];
      for (final schema in candidates) {
        for (final mode in AcanthisSchemaMode.values) {
          expect(
            () => schema.exportJsonSchema(mode: mode),
            throwsA(isA<AcanthisSchemaExportException>()),
          );
        }
      }
      expect(calls, 0);
    },
  );

  test('all audited primitive predicates round trip on JSON values', () async {
    final schemas = <Schema<Object?, Object?>>[
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
    final values = <Object?>[
      null,
      true,
      false,
      -3,
      -0.0,
      0,
      1,
      1.0,
      2,
      2.5,
      3,
      4,
      5,
      '',
      'a',
      '😀',
      [],
      {},
    ];
    for (final schema in schemas) {
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
      final imported = importJsonSchema(inputSchema);
      for (final input in values) {
        final native = schema.tryParse(input);
        final expected = native.isValid;
        expect(imported.parseResult(input).isValid, expected);
        expect(imported.tryParse(input).isValid, expected);
        expect((await imported.parseResultAsync(input)).isValid, expected);
        expect((await imported.tryParseAsync(input)).isValid, expected);
        primitiveCorpus.add({
          'inputSchema': inputSchema,
          'outputSchema': outputSchema,
          'openApiInput': openApiInput,
          'openApiOutput': openApiOutput,
          'input': input,
          'valid': expected,
          if (expected) 'output': native.value,
        });
      }
    }
  });

  test(
    'imported object contracts collect typed nested paths and preserve input',
    () async {
      final contract = importJsonSchema({
        'type': 'object',
        'properties': {
          'a/~': {
            'type': 'array',
            'items': {'type': 'integer', 'minimum': 1},
          },
        },
        'required': ['a/~', 'missing'],
        'additionalProperties': false,
      });
      final input = <String, Object?>{
        'a/~': [0, 2.5],
        'extra': true,
      };
      final result = contract.tryParse(input);
      expect(result.isValid, isFalse);
      expect(identical(result.value, input), isTrue);
      expect(result.issues.map((i) => i.path), [
        ['missing'],
        ['a/~', 0],
        ['a/~', 1],
        ['extra'],
      ]);
      expect(result.issues[1].jsonPointer, '/a~1~0/0');
      expect(contract.parseResult(input).issues, hasLength(1));
      expect((await contract.tryParseAsync(input)).issues, result.issues);
      expect(input, {
        'a/~': [0, 2.5],
        'extra': true,
      });
    },
  );

  test(
    'JSON integer, Unicode length and structural equality use JSON semantics',
    () {
      expect(
        importJsonSchema({'minLength': 1.0})
            .parseResult('')
            .issues
            .single
            .message,
        'Value must contain at least 1 character',
      );
      expect(importJsonSchema({'type': 'integer'}).validate(1.0), isTrue);
      expect(importJsonSchema({'type': 'integer'}).validate(1.5), isFalse);
      expect(
        importJsonSchema({'type': 'string', 'maxLength': 1}).validate('😀'),
        isTrue,
      );
      final unique = importJsonSchema({'type': 'array', 'uniqueItems': true});
      expect(
        unique.validate([
          {
            'a': 1,
            'b': [2],
          },
          {
            'b': [2.0],
            'a': 1.0,
          },
        ]),
        isFalse,
      );
      expect(unique.validate([true, 1]), isTrue);
      expect(
        unique.validate([9223372036854775807, 9223372036854775808.0]),
        isTrue,
      );
      expect(
        importJsonSchema({'const': 9223372036854775807})
            .validate(9223372036854775808.0),
        isFalse,
      );
      expect(
        importJsonSchema({'maximum': 9223372036854775807})
            .validate(9223372036854775808.0),
        isFalse,
      );
      expect(
        importJsonSchema({'minimum': 9223372036854775808.0})
            .validate(9223372036854775807),
        isFalse,
      );
      expect(importJsonSchema({'const': -0.0}).validate(0), isTrue);
      expect(importJsonSchema({'minimum': 0.0}).validate(-0.0), isTrue);
    },
  );

  test(
    'local references and siblings compile and re-export without aliasing',
    () {
      final definition = <String, Object?>{
        r'$defs': {
          'a/~': {'type': 'number', 'minimum': 0},
        },
        r'$ref': r'#/$defs/a~1~0',
        'maximum': 2,
        'default': 1,
        'description': 'A bounded value',
      };
      final schema = importOpenApiSchema(definition);
      definition.clear();
      expect(schema.validate(1.5), isTrue);
      expect(schema.validate(-1), isFalse);
      expect(schema.validate(3), isFalse);
      expect(schema.parseResult(null).value, isNull);
      expect(schema.validate(null), isFalse); // default is an annotation
      final exported = schema.exportJsonSchema(mode: AcanthisSchemaMode.output);
      (exported[r'$defs'] as Map).clear();
      expect(
        schema.exportOpenApiSchema(mode: AcanthisSchemaMode.input)[r'$defs'],
        isNotEmpty,
      );
      expect(() => (schema.definition as Map).clear(), throwsUnsupportedError);
      expect(
        () => ((schema.definition as Map)[r'$defs'] as Map).clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'anyOf branches and not compose without sharing issues across calls',
    () async {
      final contract = importJsonSchema({
        'anyOf': [
          {'type': 'string'},
          {'type': 'number', 'minimum': 1},
        ],
        'not': {'const': 'forbidden'},
      });
      expect(contract.validate('a'), isTrue);
      expect(contract.validate(2), isTrue);
      expect(contract.validate('forbidden'), isFalse);
      final bad = contract.tryParse(false);
      expect(bad.issues.single.code, 'union');
      expect(bad.issues.single.branches, hasLength(2));
      final results = await Future.wait([
        contract.tryParseAsync(1),
        contract.tryParseAsync(false),
      ]);
      expect(results[0].issues, isEmpty);
      expect(results[1].issues, bad.issues);
    },
  );

  test('boolean contracts reject non-JSON data and normalize for export', () {
    final accepted = importJsonSchema(true);
    expect(
      importOpenApiSchema({
        r'$schema': 'https://spec.openapis.org/oas/3.1/dialect/base',
        'type': 'integer',
      }).validate(1.0),
      isTrue,
    );
    expect(Acanthis.importJsonSchema({'type': 'string'}).validate('a'), isTrue);
    expect(
      AcanthisType.importOpenApiSchema({'type': 'integer'}).validate(1.0),
      isTrue,
    );
    expect(accepted.validate(null), isTrue);
    for (final input in [
      double.nan,
      double.infinity,
      Object(),
      {'a': double.nan},
      {1: 'x'},
    ]) {
      expect(accepted.validate(input), isFalse);
    }
    final cycle = <Object?>[];
    cycle.add(cycle);
    expect(accepted.validate(cycle), isFalse);
    expect(
      accepted.exportOpenApiSchema(mode: AcanthisSchemaMode.input),
      isEmpty,
    );
    expect(importJsonSchema(false).validate(null), isFalse);
    expect(
      importJsonSchema(false)
          .exportOpenApiSchema(mode: AcanthisSchemaMode.output),
      {'not': <String, Object?>{}},
    );
  });

  test('recursive local references descend through JSON containers', () {
    final definition = {
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
    };
    final schema = importJsonSchema(definition);
    expect(
      schema.validate({
        'value': 1,
        'children': [
          {'value': 2, 'children': []},
        ],
      }),
      isTrue,
    );
    final failed = schema.tryParse({
      'value': 1,
      'children': [
        {'value': 'x', 'children': []},
      ],
    });
    expect(failed.issues.single.path, ['children', 0, 'value']);
    expect(
      importJsonSchema(schema.exportJsonSchema(mode: AcanthisSchemaMode.input))
          .validate({'value': 1, 'children': []}),
      isTrue,
    );
    Object? deep = 1;
    for (var i = 0; i < 130; i++) {
      deep = [deep];
    }
    expect(importJsonSchema(true).validate(deep), isFalse);
    final cycle = <String, Object?>{};
    cycle['not'] = cycle;
    expect(
      () => importJsonSchema(cycle),
      throwsA(isA<AcanthisSchemaImportException>()),
    );
    expect(
      () => importJsonSchema({'allOf': List.filled(4100, true)}),
      throwsA(isA<AcanthisSchemaImportException>()),
    );
  });

  final rejected = <String, Object?>{
    'unknown keyword': {'minLenght': 1},
    'legacy nullable': {'type': 'number', 'nullable': true},
    'wrong draft': {r'$schema': 'http://json-schema.org/draft-07/schema#'},
    'format': {'format': 'email'},
    'invalid pattern': {'pattern': '['},
    'nonstring pattern': {'pattern': 1},
    'invalid tuple prefix': {'prefixItems': {}},
    'empty tuple prefix': {'prefixItems': []},
    'multipleOf': {'multipleOf': 0.1},
    'negative length': {'minLength': -1},
    'wrong annotation': {'title': 1},
    'empty enum': {'enum': []},
    'duplicate enum': {
      'enum': [1, 1.0],
    },
    'wrong type': {'type': 'unknown'},
    'duplicate types': {
      'type': ['number', 'number'],
    },
    'wrong bound': {'minimum': '1'},
    'empty allOf': {'allOf': []},
    'invalid required': {
      'required': [1],
    },
    'invalid defs': {r'$defs': []},
    'missing reference': {r'$ref': '#/missing'},
    'external reference': {r'$ref': 'https://example.com/schema'},
    'cyclic reference': {r'$ref': '#'},
    'shared unguarded reference': {
      'properties': {
        'x': {r'$ref': '#'},
      },
      'allOf': [
        {r'$ref': '#/properties/x'},
      ],
    },
    'bad pointer escape': {r'$ref': '#/a~2'},
    'non-schema': 3,
    'non-JSON': {'const': double.nan},
  };
  for (final entry in rejected.entries) {
    test('import rejects ${entry.key}', () {
      expect(
        () => importJsonSchema(entry.value),
        throwsA(isA<AcanthisSchemaImportException>()),
      );
    });
  }

  test('malformed nested schemas report escaped contract paths', () {
    expect(
      () => importJsonSchema({
        'properties': {
          'a/~': {'wat': true},
        },
      }),
      throwsA(
        isA<AcanthisSchemaImportException>().having(
          (e) => e.path,
          'path',
          '/properties/a~1~0/wat',
        ),
      ),
    );
  });

  test(
    'independent validator corpus agrees with all four entry points',
    () async {
      final corpus = jsonDecode(
        File('test/fixtures/contract_reference.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final entry
          in (corpus['source_sha256'] as Map<String, dynamic>).entries) {
        expect(
          sha256
              .convert(
                utf8.encode(
                  File(entry.key).readAsStringSync().replaceAll('\r\n', '\n'),
                ),
              )
              .toString(),
          entry.value,
        );
      }
      for (final record in corpus['cases'] as List) {
        final imported = importJsonSchema(record['schema']);
        final inputs = record['inputs'] as List;
        final expected = record['valid'] as List;
        final reimported = importOpenApiSchema(
          imported.exportOpenApiSchema(mode: AcanthisSchemaMode.output),
        );
        for (var i = 0; i < inputs.length; i++) {
          for (final result in [
            imported.parseResult(inputs[i]),
            imported.tryParse(inputs[i]),
            await imported.parseResultAsync(inputs[i]),
            await imported.tryParseAsync(inputs[i]),
            reimported.parseResult(inputs[i]),
          ]) {
            expect(
              result.isValid,
              expected[i],
              reason: '${record['name']} input $i: ${inputs[i]}',
            );
            expect(identical(result.value, inputs[i]), isTrue);
          }
        }
      }
    },
  );
  tearDownAll(() {
    final path = Platform.environment['PRIMITIVE_EXPORT_CORPUS'];
    if (path != null) File(path).writeAsStringSync(jsonEncode(primitiveCorpus));
  });
}

final class _CustomSchema extends Schema<Object?, Object?> {
  @override
  Object? parse(Object? input) => input;
  @override
  AcanthisOutcome<Object?> tryParse(Object? input) => AcanthisValid(input);
}
