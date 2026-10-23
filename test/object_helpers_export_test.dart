import 'dart:convert';
import 'dart:io';

import 'package:acanthis/acanthis.dart';
import 'package:test/test.dart';

void main() {
  final corpus = <Map<String, Object?>>[];

  void compare(Schema<Object?, Object?> schema, List<Object?> inputs) {
    final inputSchema = schema.toJsonSchema(mode: AcanthisSchemaMode.input);
    final outputSchema = schema.toJsonSchema(mode: AcanthisSchemaMode.output);
    final openApiInput = schema.toOpenApiSchema(mode: AcanthisSchemaMode.input);
    final openApiOutput = schema.toOpenApiSchema(
      mode: AcanthisSchemaMode.output,
    );
    final accepted = fromJsonSchema(inputSchema);
    final produced = fromJsonSchema(outputSchema);
    for (final input in inputs) {
      final result = schema.tryParse(input);
      expect(
        accepted.validate(input),
        result.isValid,
        reason: '${jsonEncode(input)} against ${jsonEncode(inputSchema)}',
      );
      if (result.isValid) {
        expect(
          produced.validate(result.value),
          isTrue,
          reason: jsonEncode(result.value),
        );
      }
      corpus.add({
        'inputSchema': inputSchema,
        'outputSchema': outputSchema,
        'openApiInput': openApiInput,
        'openApiOutput': openApiOutput,
        'input': input,
        'valid': result.isValid,
        if (result.isValid) 'output': result.value,
      });
    }
  }

  for (final policy in AcanthisUnknownKeys.values) {
    for (final partial in [false, true]) {
      for (final defaults in [0, 1, 2]) {
        for (final optional in [false, true]) {
          test(
            'property counts: $policy partial=$partial defaults=$defaults optional=$optional',
            () {
              var schema = object({
                'a': defaults > 0 ? boolean().withDefault(true) : boolean(),
                'b': defaults > 1 ? boolean().withDefault(false) : boolean(),
                'c': boolean(),
              }).unknownKeys(policy);
              if (partial) schema = schema.patch();
              if (optional) schema = schema.optionals(['b', 'c']);
              final inputs = <Object?>[
                null,
                false,
                [],
                {'a': 'wrong', 'b': true, 'c': false},
              ];
              for (var mask = 0; mask < 27; mask++) {
                final input = <String, Object?>{};
                var state = mask;
                for (final name in ['a', 'b', 'c']) {
                  final choice = state % 3;
                  state ~/= 3;
                  if (choice != 0) input[name] = choice == 1 ? null : false;
                }
                inputs.addAll([
                  input,
                  {...input, 'extra': false},
                ]);
              }
              for (final checked in [
                schema.minProperties(2),
                schema.maxProperties(1),
                schema.lengthProperties(2),
                schema.minProperties(1).maxProperties(2),
                schema.minProperties(3).maxProperties(1),
                schema.minProperties(-1),
                schema.maxProperties(-1),
                schema.lengthProperties(0),
              ]) {
                compare(checked, inputs);
              }
            },
          );
        }
      }
    }
  }

  test('composition, deep partial, root defaults, and typed additional schemas export', () {
    final base = object({'a': boolean(), 'b': boolean().withDefault(true)});
    final tree = object({'value': boolean()})
        .passthrough(type: lazy((parent) => parent));
    final cases = <Schema<Object?, Object?>>[
      base.pick(['b']).lengthProperties(1).withDefault({}),
      base.omit(['a']).minProperties(1),
      base.extend({'c': boolean()}).partial().lengthProperties(2),
      base.merge({'a': literal(false)}),
      base.passthrough(type: boolean().nullable()).maxProperties(3),
      base.passthrough(type: list(boolean())),
      base.passthrough(type: boolean().withDefault(true)),
      base.passthrough(type: literal(null)),
      object({'child': base}).patch(deep: true).lengthProperties(1),
      tree,
    ];
    final inputs = <Object?>[
      null,
      {},
      {'a': false},
      {'a': false, 'b': null},
      {'b': null},
      {'b': false},
      {'a': false, 'x': true},
      {'a': false, 'x': null},
      {'a': false, 'x': []},
      {
        'a': false,
        'x': [true],
      },
      {'child': {}},
      {
        'child': {'b': null},
      },
      {'value': false},
      {
        'value': true,
        'child': {'value': false},
      },
      {'value': true, 'child': {}},
    ];
    for (final schema in cases) {
      compare(schema, inputs);
    }
  });

  test('projected counts enumerate combinations of optional declared keys', () {
    final schema = object({for (var i = 0; i < 5; i++) 'f$i': boolean()})
        .partial();
    final inputs = <Object?>[
      for (var mask = 0; mask < 32; mask++)
        {
          for (var i = 0; i < 5; i++)
            if ((mask & (1 << i)) != 0) 'f$i': true,
          'extra': true,
        },
    ];
    compare(schema.lengthProperties(2), inputs);
    compare(schema.minProperties(2).maxProperties(3), inputs);
  });

  test(
    'repeated exports isolate snapshots and retain strict callback rejection',
    () {
      final schema = object({'a': boolean().withDefault(true)})
          .passthrough(type: boolean())
          .maxProperties(2);
      final expected = schema.toJsonSchema(mode: AcanthisSchemaMode.input);
      for (var i = 0; i < 4; i++) {
        final snapshot = schema.toJsonSchema(mode: AcanthisSchemaMode.input);
        expect(snapshot, expected);
        snapshot.clear();
      }
      var calls = 0;
      final invalid = <Schema<Object?, Object?>>[
        schema.refine(
          onCheck: (_) {
            calls++;
            return true;
          },
        ),
        schema.transform((value) {
          calls++;
          return value;
        }),
        object({}).passthrough(
          type: boolean().refine(
            onCheck: (_) {
              calls++;
              return true;
            },
          ),
        ),
        object({}).minProperties(9007199254740992),
      ];
      for (final candidate in invalid) {
        for (final mode in AcanthisSchemaMode.values) {
          expect(
            () => candidate.toJsonSchema(mode: mode),
            throwsA(isA<AcanthisSchemaExportException>()),
          );
        }
      }
      expect(calls, 0);
    },
  );

  test('large projected cardinality contracts fail explicitly within export limits', () {
    final schema = object({for (var i = 0; i < 20; i++) 'f$i': boolean()})
        .partial()
        .lengthProperties(10);
    expect(
      () => schema.toJsonSchema(mode: AcanthisSchemaMode.input),
      throwsA(isA<AcanthisSchemaExportException>()),
    );
    expect(schema.toOpenApiSchema(mode: AcanthisSchemaMode.output)['allOf'], [
      {'minProperties': 10, 'maxProperties': 10},
    ]);
    final defaults = object({
      for (var i = 0; i < 13; i++) 'f$i': boolean().withDefault(true),
    }).passthrough().maxProperties(20);
    expect(
      () => defaults.toJsonSchema(mode: AcanthisSchemaMode.input),
      throwsA(isA<AcanthisSchemaExportException>()),
    );
  });

  tearDownAll(() {
    final path = Platform.environment['OBJECT_HELPERS_EXPORT_CORPUS'];
    if (path != null) File(path).writeAsStringSync(jsonEncode(corpus));
  });
}
