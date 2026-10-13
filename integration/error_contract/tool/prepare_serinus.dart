// Local integration-only workaround for Serinus 2.1.12 on Dart 3.13.
// Does not modify the pub cache or the published dependency.
import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final packages =
      (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
  final entry = packages.cast<Map>().singleWhere((p) => p['name'] == 'serinus');
  final source = Directory.fromUri(
    config.uri.resolve(entry['rootUri'] as String),
  );
  final target = Directory('.dart_tool/serinus-2.1.12-sdk-compat').absolute;
  if (source.absolute.path == target.path) {
    print('Compatibility source already selected.');
    return;
  }
  final pubspec = await File('${source.path}/pubspec.yaml').readAsString();
  if (!pubspec.contains('version: 2.1.12')) {
    throw StateError(
      'Resolve the pinned Serinus 2.1.12 before preparing the fixture.',
    );
  }
  await target.create(recursive: true);
  for (final entity in source.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final relative = entity.path.substring(source.path.length);
    final file = File('${target.path}$relative');
    await file.parent.create(recursive: true);
    await entity.copy(file.path);
  }
  final route = File(
    '${target.path}/lib/src/routes/route_execution_context.dart',
  );
  final original = await route.readAsString();
  if (!original.contains('processResult(data, executionContext)')) {
    throw StateError('Unexpected upstream source; review the workaround.');
  }
  await route.writeAsString(
    original
        .replaceAll(
          'processResult(data, executionContext)',
          'processResult(data, executionContext!)',
        )
        .replaceAll('executionContext.response', 'executionContext!.response'),
  );
  await File('pubspec_overrides.yaml').writeAsString('''dependency_overrides:
  acanthis:
    path: ../..
  serinus:
    path: .dart_tool/serinus-2.1.12-sdk-compat
''');
  print(
    'Prepared local Serinus 2.1.12 with explicit null assertions after await.',
  );
  print(
    'Run dart pub get, then dart run test. This is not an unmodified upstream verification.',
  );
}
