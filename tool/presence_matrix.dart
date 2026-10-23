import 'dart:convert';
import 'dart:io';

import 'package:acanthis/acanthis.dart';

// Characterize current V2 presence behavior without replacing reviewed fixtures.
// Run from the repository root; output is written under .dart_tool.
Future<List<Map<String, Object?>>> presenceMatrix() async {
  final factories = <String, ObjectSchema Function()>{
    'required': () => object({'value': string()}),
    'nullable': () => object({'value': string().nullable()}),
    'optional': () => object({'value': string()}).optionals(['value']),
    'optional_nullable': () =>
        object({'value': string().nullable()}).optionals(['value']),
    'default': () => object({'value': string().withDefault('fallback')}),
    'optional_default': () =>
        object({'value': string().withDefault('fallback')})
            .optionals(['value']),
    'nullable_default': () =>
        object({'value': string().nullable(defaultValue: 'fallback')}),
    'invalid_default': () =>
        object({'value': string().min(3).withDefault('x')}),
    'passthrough': () => object({'value': string()}).passthrough(),
    'typed_passthrough': () =>
        object({'value': string()}).passthrough(type: string()),
    'partial': () => object({'value': string()}).partial(),
    'deep_partial': () => object({'value': string()}).partial(deep: true),
  };
  final inputs = <String, Map<String, dynamic>>{
    'absent': {},
    'null': {'value': null},
    'wrong_type': {'value': 42},
    'short': {'value': 'a'},
    'valid': {'value': 'valid'},
    'extra': {'value': 'valid', 'extra': 42},
  };
  final rows = <Map<String, Object?>>[];
  for (final entry in factories.entries) {
    final schema = entry.value();
    final cases = <String, Object?>{};
    for (final input in inputs.entries) {
      final modes = <String, Object?>{};
      for (final mode in [
        'parse',
        'tryParse',
        'parseAsync',
        'tryParseAsync',
        'asyncParse',
        'asyncTryParse',
      ]) {
        var current = entry.value();
        if (mode.startsWith('async')) {
          // A real asynchronous object operation, not the sync forwarding path.
          current = current.refineAsync(CallbackAsyncCheck((_, _) async {}));
        }
        try {
          final value = Map<String, dynamic>.of(input.value);
          AcanthisOutcome<Object?> result;
          try {
            result = switch (mode) {
              'parse' => AcanthisValid(current.parse(value)),
              'parseAsync' ||
              'asyncParse' => AcanthisValid(await current.parseAsync(value)),
              'tryParseAsync' ||
              'asyncTryParse' => await current.tryParseAsync(value),
              _ => current.tryParse(value),
            };
          } on ValidationError catch (error) {
            result = error.failure;
          }
          final hasValue = switch (result) {
            AcanthisValid() => true,
            AcanthisInvalid(:final hasValue) => hasValue,
          };
          modes[mode] = {
            'success': result.isValid,
            'hasValue': hasValue,
            if (hasValue) 'value': result.value,
            if (!result.isValid)
              'issues': [
                for (final issue in result.issues)
                  {'path': issue.path, 'code': issue.code},
              ],
          };
        } catch (error) {
          modes[mode] = {
            'throws': error is TypeError
                ? 'TypeError'
                : error.runtimeType.toString(),
          };
        }
      }
      cases[input.key] = modes;
    }
    rows.add({
      'schema': entry.key,
      'jsonSchema': _export(schema, openApi: false),
      'openApi': _export(schema, openApi: true),
      'cases': cases,
    });
  }
  return rows;
}

Map<String, Object?> _export(ObjectSchema schema, {required bool openApi}) {
  try {
    return openApi
        ? schema.toOpenApiSchema(mode: AcanthisSchemaMode.input)
        : schema.toJsonSchema();
  } on AcanthisSchemaExportException catch (error) {
    return {'unsupported': error.reason, 'path': error.path};
  }
}

Future<void> main() async {
  final file = File('.dart_tool/presence_matrix.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(await presenceMatrix())}\n',
  );
  stdout.writeln(
    'Updated ${file.path}; review behavior changes before accepting the snapshot.',
  );
}
