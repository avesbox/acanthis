import 'dart:io';

/// Run from the package root after installing the optional Python validators.
/// An optional argument adds a local directory to PYTHONPATH.
Future<void> main(List<String> args) async {
  final directory = Directory.systemTemp.createTempSync('acanthis-export-');
  try {
    const suites = {
      'PRIMITIVE': 'contract_test.dart',
      'BOOLEAN': 'boolean_export_test.dart',
      'NULLABLE': 'nullable_export_test.dart',
      'LITERAL': 'literal_export_test.dart',
      'COLLECTION': 'collection_export_test.dart',
      'OBJECT_HELPERS': 'object_helpers_export_test.dart',
    };
    String corpus(String name) =>
        '${directory.path}/${name.toLowerCase()}.json';
    final environment = {
      for (final name in suites.keys) '${name}_EXPORT_CORPUS': corpus(name),
      if (args.isNotEmpty) 'PYTHONPATH': Directory(args.first).absolute.path,
    };
    final tests = await Process.run(Platform.resolvedExecutable, [
      'run',
      'test',
      '--reporter=expanded',
      for (final test in suites.values) 'test/$test',
    ], environment: environment);
    stdout.write(tests.stdout);
    stderr.write(tests.stderr);
    if (tests.exitCode != 0) {
      exitCode = tests.exitCode;
      return;
    }
    for (final name in suites.keys) {
      if (!File(corpus(name)).existsSync()) {
        throw StateError('The $name export suite did not generate its corpus');
      }
      stdout.writeln('Auditing ${name.toLowerCase()} exports...');
      final validation = await Process.run('python', [
        'tool/verify_schema_export.py',
        corpus(name),
      ], environment: environment);
      stdout.write(validation.stdout);
      stderr.write(validation.stderr);
      if (validation.exitCode != 0) {
        exitCode = validation.exitCode;
        return;
      }
    }
  } finally {
    // Delete only the temporary directory allocated by this invocation.
    if (directory.parent.resolveSymbolicLinksSync() ==
        Directory.systemTemp.resolveSymbolicLinksSync()) {
      directory.deleteSync(recursive: true);
    }
  }
}
