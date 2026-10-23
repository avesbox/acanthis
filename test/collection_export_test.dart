import 'support/parse_result.dart';

import 'dart:convert';
import 'dart:io';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  final corpus = <Map<String, Object?>>[];
  final tree = object({
    'name': string().notEmpty(),
    'children': lazy((parent) => parent.list().max(2)).withDefault([]),
  });
  final variantTree = object({
    'name': string(),
    'children': lazy(
      (parent) => parent.unknownKeys(AcanthisUnknownKeys.preserve).list(),
    ),
  });
  late ObjectSchema mutualA;
  late ObjectSchema mutualB;
  mutualA = object({'a': string(), 'b': lazy((_) => mutualB)}).optionals(['b']);
  mutualB = object({'b': number(), 'a': lazy((_) => mutualA)}).optionals(['a']);
  final imported = fromJsonSchema({
    'type': 'object',
    'properties': {
      'literal': {
        'const': {r'$ref': 'literal data'},
      },
      'children': {
        'type': 'array',
        'items': {r'$ref': '#'},
      },
    },
    'additionalProperties': false,
  });
  final cases = <String, Schema<Object?, Object?>>{
    for (final policy in AcanthisUnknownKeys.values)
      'object/$policy': object({
        'name': string().notEmpty(),
        'n': number().gte(0).withDefault(2),
        'tags': list(string()).withDefault(['new']),
        'optional': string(),
      }).optionals(['optional']).unknownKeys(policy),
    'optional_default': object({'n': number().withDefault(2)}).optionals(['n']),
    'partial': object({'n': number().withDefault(2), 'name': string()})
        .partial(),
    'nested_default': object({
      'box': object({'n': number().withDefault(2)}).withDefault({}),
    }).withDefault({}),
    'list/min': list(string()).min(2).max(4).min(3),
    'list/length': list(number()).length(2),
    'list/unique': list(string()).unique(),
    'list/unique_number': list(number()).unique(),
    'list/unique_number_default': list(number().withDefault(1)).unique(),
    'list/default_contains_null': list<Object?>(string().withDefault('x'))
        .contains(null),
    'list/default_any_null': list<Object?>(string().withDefault('x'))
        .anyOf([null]),
    'list/default_every_null': list<Object?>(string().withDefault('x'))
        .everyOf([null]),
    'list/contains': list(string()).contains('x'),
    'list/any': list(string()).anyOf(['x', 'y']),
    'list/every': list(string()).everyOf(['x', 'y']),
    'list/any_empty': list(string()).anyOf([]),
    'list/every_empty': list(string()).everyOf([]),
    'list/min_negative': list(number()).min(-1),
    'list/max_negative': list(number()).max(-1),
    'list/length_negative': list(number()).length(-1),
    'list/default': list(number().gte(0)).withDefault([1]),
    'list/default_unique': list(string().withDefault('x')).unique(),
    'list/default_contains': list(string().withDefault('x')).contains('x'),
    'list/default_any': list(string().withDefault('x')).anyOf(['x', 'y']),
    'list/default_every': list(string().withDefault('x')).everyOf(['x']),
    'record': record(string().notEmpty(), number().gte(0).withDefault(2)),
    'record/key_enum': record(string().contained(['a', 'b']), number()),
    'tree': tree,
    'variant_tree': variantTree,
    'mutual_tree': mutualA,
    'imported_child': object({'box': imported}),
  };
  final inputs = <Object?>[
    null,
    true,
    1,
    'text',
    {},
    {'n': 1},
    {'n': null},
    {'name': ''},
    {'name': 'Ada'},
    {'name': 'Ada', 'extra': 1},
    {'name': 'Ada', 'optional': null},
    {'name': 'Ada', 'n': -1},
    {'name': 'Ada', 'tags': []},
    {'box': {}},
    {
      'box': {
        'literal': {r'$ref': 'literal data'},
      },
    },
    {
      'box': {
        'children': [{}],
      },
    },
    {
      'box': {
        'children': [
          {'unknown': 1},
        ],
      },
    },
    {'a': 1},
    {'a': 'root'},
    {
      'a': 'root',
      'b': {'b': 2},
    },
    {
      'a': 'root',
      'b': {
        'b': 2,
        'a': {'a': 'leaf'},
      },
    },
    {
      'a': 'root',
      'b': {'b': 'bad'},
    },
    {'': 1},
    {'b': null},
    [],
    ['x'],
    ['y'],
    ['z'],
    ['x', 'x'],
    ['x', 'y'],
    ['y', 'z'],
    [null],
    [null, 'x'],
    [null, null],
    [null, 'y'],
    [1, 2],
    [1, 1.0],
    [0, -0.0],
    [9007199254740992, 9007199254740993],
    [9007199254740992, 9007199254740993.0],
    [9223372036854775807, 9223372036854775807.0],
    [1, -1],
    ['x', 'y', 'z'],
    ['x', 'y', 'z', 'w', 'v'],
    {'name': 'root', 'children': []},
    {
      'name': 'root',
      'children': [
        {'name': 'leaf'},
      ],
    },
    {
      'name': 'root',
      'children': [
        {'name': 'leaf', 'children': [], 'extra': 1},
      ],
    },
    {
      'name': 'root',
      'children': [
        {'name': ''},
      ],
    },
    {
      'name': 'root',
      'children': [{}, {}, {}],
    },
  ];

  for (final entry in cases.entries) {
    test(
      '${entry.key} exports exact input acceptance and valid output in both dialects',
      () {
        final inputSchema = entry.value.exportJsonSchema(
          mode: AcanthisSchemaMode.input,
        );
        final outputSchema = entry.value.exportJsonSchema(
          mode: AcanthisSchemaMode.output,
        );
        final openApiInput = entry.value.exportOpenApiSchema(
          mode: AcanthisSchemaMode.input,
        );
        final openApiOutput = entry.value.exportOpenApiSchema(
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
      },
    );
  }

  test('strip, preserve, defaults and partial have distinct presence/output contracts', () {
    final schema = object({'n': number().withDefault(2)}).optionals(['n']);
    final input = schema.toOpenApiSchema(mode: AcanthisSchemaMode.input);
    final output = schema.toOpenApiSchema(mode: AcanthisSchemaMode.output);
    expect(input['required'], isNull);
    expect(input['additionalProperties'], isTrue);
    expect(output['required'], ['n']);
    expect(output['additionalProperties'], isFalse);
    expect(
      schema.partial().toOpenApiSchema(
        mode: AcanthisSchemaMode.output,
      )['required'],
      isNull,
    );
    expect(fromJsonSchema(output).validate({'n': 2, 'extra': true}), isFalse);
  });

  test('recursive exports are stable, serializable and return independent cached snapshots', () {
    var resolutions = 0;
    final schema = object({
      'children': lazy((parent) {
        resolutions++;
        return parent.list();
      }),
    });
    final first = jsonEncode(
      schema.toJsonSchema(mode: AcanthisSchemaMode.input),
    );
    for (var i = 0; i < 4; i++) {
      final current = schema.toJsonSchema(mode: AcanthisSchemaMode.input);
      expect(jsonEncode(current), first);
      expect(current[r'$defs'], isNotEmpty);
      (current[r'$defs'] as Map).clear();
      (current['properties'] as Map).clear();
    }
    expect(resolutions, 1);
  });

  test('unsupported collection behavior fails at escaped paths without validation callbacks', () {
    var calls = 0;
    final candidates = <Schema<Object?, Object?>>[
      object({'a/~': list(string().min(1))}),
      object({'n': number()})
          .refine(
            onCheck: (_) {
              calls++;
              return true;
            },
          )
          .withDefault({'n': 1}),
      object({
        'child': lazy((_) => string()).refine(
          onCheck: (_) {
            calls++;
            return true;
          },
        ),
      }),
      list(string()).transform((v) {
        calls++;
        return v;
      }),
      list(object({'n': number()})).unique(),
      record(integer(), number()),
      record(
        string().transform((v) {
          calls++;
          return v;
        }),
        number(),
      ),
      object({
        'n': number().refineAsync(
          CallbackAsyncCheck((_, _) async {
            calls++;
          }),
        ),
      }),
      lazy((_) => string()),
    ];
    for (final candidate in candidates) {
      expect(
        () => candidate.toJsonSchema(mode: AcanthisSchemaMode.input),
        throwsA(isA<AcanthisSchemaExportException>()),
      );
    }
    expect(calls, 0);
    expect(
      () => candidates.first.toJsonSchema(mode: AcanthisSchemaMode.input),
      throwsA(
        isA<AcanthisSchemaExportException>().having(
          (e) => e.path,
          'path',
          '/properties/a~1~0/items',
        ),
      ),
    );
  });

  test('invalid JSON defaults and invalid resolver graphs fail explicitly', () {
    for (final candidate in <Schema<Object?, Object?>>[
      object({'n': number().positive()}).withDefault({'n': -1}),
      object({'n': number()}).withDefault({}),
      list(number().positive()).withDefault([-1]),
      list(string().withDefault('x')).unique().withDefault(['x', 'x']),
      record(string().notEmpty(), number()).withDefault({'': 1}),
      object({'x': lazy((_) => number().positive()).withDefault(-1)}),
    ]) {
      expect(
        () => candidate.toJsonSchema(mode: AcanthisSchemaMode.input),
        throwsA(isA<AcanthisSchemaExportException>()),
      );
    }
    final broken = object({
      'bad': lazy<String>((_) => throw StateError('private resolver detail')),
    });
    expect(
      () => broken.toJsonSchema(mode: AcanthisSchemaMode.input),
      throwsA(
        isA<AcanthisSchemaExportException>().having(
          (e) => e.path,
          'path',
          '/properties/bad',
        ),
      ),
    );
  });

  test('cached contracts recheck caller-owned nested defaults without running callbacks', () {
    final nested = <String, Object?>{'n': 1};
    final schema = object({
      'box': object({'n': number().positive()}),
    }).withDefault({'box': nested});
    for (var i = 0; i < 3; i++) {
      schema.toJsonSchema(mode: AcanthisSchemaMode.input);
    }
    nested['n'] = -1;
    expect(schema.parseResult(null).isValid, isFalse);
    expect(
      () => schema.toJsonSchema(mode: AcanthisSchemaMode.input),
      throwsA(isA<AcanthisSchemaExportException>()),
    );
    nested['n'] = 2;
    expect(
      fromJsonSchema(schema.toJsonSchema(mode: AcanthisSchemaMode.input))
          .validate(null),
      isTrue,
    );
  });

  tearDownAll(() {
    final path = Platform.environment['COLLECTION_EXPORT_CORPUS'];
    if (path != null) File(path).writeAsStringSync(jsonEncode(corpus));
  });
}
