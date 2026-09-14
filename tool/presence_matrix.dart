import 'dart:convert';
import 'dart:io';

import 'package:acanthis/acanthis.dart';

// Characterization of current behavior, including known discrepancies.
// Run from the repository root. Tests verify the checked-in snapshot.
Future<List<Map<String, Object?>>> presenceMatrix() async {
  final factories = <String, AcanthisMap<dynamic> Function(bool)>{
    'required': (pure) => AcanthisMap({'value': string()}, isPure: pure),
    'nullable': (pure) =>
        AcanthisMap({'value': string().nullable()}, isPure: pure),
    'optional': (pure) =>
        AcanthisMap({'value': string()}, isPure: pure).optionals(['value']),
    'optional_nullable': (pure) => AcanthisMap({
      'value': string().nullable(),
    }, isPure: pure).optionals(['value']),
    'default': (pure) =>
        AcanthisMap({'value': string().withDefault('fallback')}, isPure: pure),
    'optional_default': (pure) => AcanthisMap({
      'value': string().withDefault('fallback'),
    }, isPure: pure).optionals(['value']),
    'nullable_default': (pure) => AcanthisMap({
      'value': string().nullable(defaultValue: 'fallback'),
    }, isPure: pure),
    'invalid_default': (pure) =>
        AcanthisMap({'value': string().min(3).withDefault('x')}, isPure: pure),
    'passthrough': (pure) =>
        AcanthisMap({'value': string()}, isPure: pure).passthrough(),
    'typed_passthrough': (pure) => AcanthisMap({
      'value': string(),
    }, isPure: pure).passthrough(type: string()),
    'partial': (pure) =>
        AcanthisMap({'value': string()}, isPure: pure).partial(),
    'deep_partial': (pure) =>
        AcanthisMap({'value': string()}, isPure: pure).partial(deep: true),
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
    final schema = entry.value(true);
    final cases = <String, Object?>{};
    for (final input in inputs.entries) {
      final modes = <String, Object?>{};
      for (final mode in [
        'parse',
        'tryParse',
        'parseAsync',
        'tryParseAsync',
        'genericTryParse',
        'asyncParse',
        'asyncTryParse',
      ]) {
        AcanthisType<Map<String, dynamic>> current = entry.value(
          mode != 'genericTryParse',
        );
        if (mode.startsWith('async')) {
          // A real asynchronous object operation, not the sync forwarding path.
          current = current.refineAsync(
            onCheck: (_) async => true,
            name: 'pass',
            error: '',
          );
        }
        try {
          final value = Map<String, dynamic>.of(input.value);
          final result = switch (mode) {
            'parse' => current.parse(value),
            'parseAsync' || 'asyncParse' => await current.parseAsync(value),
            'tryParseAsync' ||
            'asyncTryParse' => await current.tryParseAsync(value),
            _ => current.tryParse(value),
          };
          modes[mode] = {
            'success': result.success,
            'value': result.value,
            if (!result.success)
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
      'jsonSchema': schema.toJsonSchema(),
      'openApi': schema.toOpenApiSchema(),
      'cases': cases,
    });
  }
  return rows;
}

Future<void> main() async {
  final file = File('test/fixtures/presence_matrix.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(await presenceMatrix())}\n',
  );
  stdout.writeln(
    'Updated ${file.path}; review behavior changes before accepting the snapshot.',
  );
}
