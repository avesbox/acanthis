import 'dart:io';

/// Run from the package root after installing the optional Python validators.
/// An optional argument adds a local directory to PYTHONPATH.
Future<void> main(List<String> args) async {
  final directory = Directory.systemTemp.createTempSync('acanthis-export-');
  try {
    final environment = {
      'EXPORT_CORPUS_PATH': '${directory.path}/structural.json',
      'EXPORT_AUDIT_CORPUS_PATH': '${directory.path}/audit.json',
      if (args.isNotEmpty) 'PYTHONPATH': Directory(args.first).absolute.path,
    };
    final tests = await Process.run(Platform.resolvedExecutable, [
      'run',
      'test',
      'test/schema_export_contract_test.dart',
      'test/schema_export_audit_test.dart',
    ], environment: environment);
    stdout.write(tests.stdout);
    stderr.write(tests.stderr);
    if (tests.exitCode != 0) {
      exitCode = tests.exitCode;
      return;
    }
    for (final corpus in ['structural', 'audit']) {
      final validation = await Process.run('python', [
        'tool/verify_schema_export.py',
        '${directory.path}/$corpus.json',
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
