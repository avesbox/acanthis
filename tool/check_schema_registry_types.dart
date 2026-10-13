// Run from the repository root with `dart run tool/check_schema_registry_types.dart`.
import 'dart:io';

Future<void> main() async {
  final temp = await Directory.systemTemp.createTemp('acanthis-registry-');
  try {
    final packages = File('.dart_tool/package_config.json').absolute.path;
    for (final fixture in ['binding', 'output', 'nested_binding']) {
      final invalid = await File(
        'test/fixtures/schema_registry_invalid_$fixture.dart.txt',
      ).copy('${temp.path}/invalid.dart');
      final negative = await Process.run(Platform.resolvedExecutable, [
        'compile',
        'kernel',
        '--packages=$packages',
        invalid.path,
        '-o',
        '${temp.path}/invalid.dill',
      ]);
      final diagnostics = '${negative.stdout}\n${negative.stderr}';
      if (negative.exitCode == 0 ||
          !diagnostics.contains("doesn't conform to the bound")) {
        throw StateError(
          'Expected a generic-bound compile failure for $fixture:\n$diagnostics',
        );
      }
      print('PASS: incompatible $fixture rejected at compile time');
    }

    final executable =
        '${temp.path}/registry${Platform.isWindows ? '.exe' : ''}';
    final compiled = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      '--packages=$packages',
      'example/schema_registry/main.dart',
      '-o',
      executable,
    ]);
    if (compiled.exitCode != 0) {
      throw StateError(
        'AOT compile failed:\n${compiled.stdout}\n${compiled.stderr}',
      );
    }
    final result = await Process.run(executable, []);
    if (result.exitCode != 0 ||
        !result.stdout.toString().contains(
          'Cross-module registry reuse passed',
        )) {
      throw StateError(
        'AOT example failed:\n${result.stdout}\n${result.stderr}',
      );
    }
    print('PASS: typed cross-module example compiles and runs under AOT');
  } finally {
    final root = Directory.systemTemp.resolveSymbolicLinksSync();
    final target = temp.resolveSymbolicLinksSync();
    if (!target.startsWith('$root${Platform.pathSeparator}')) {
      throw StateError('Temporary directory is outside the expected root');
    }
    await temp.delete(recursive: true);
  }
}
