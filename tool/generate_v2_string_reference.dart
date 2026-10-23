// Capture a V2 regression baseline; frozen V1 compatibility fixtures stay intact.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../test/support/string_corpus.dart';
import '../test/support/string_schemas.dart';

void main() {
  const seed = 20261014;
  const samples = 600;
  final corpus = stringCorpus(seed: seed, samples: samples);
  final cases = <String, String>{};
  for (final entry in stringCases()) {
    final name = entry['name'] as String;
    final schema = buildStringCase(name);
    cases[name] = [
      for (final input in corpus) schema.tryParse(input).isValid ? '1' : '0',
    ].join();
  }
  final sources = [
    ...Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')),
    File('tool/generate_v2_string_reference.dart'),
    File('test/support/string_corpus.dart'),
    File('test/support/string_schemas.dart'),
    File('test/fixtures/string_checks.json'),
    File('pubspec.lock'),
  ]..sort((a, b) => a.path.compareTo(b.path));
  final output = {
    'implementation': 'v2',
    'sdk': Platform.version,
    'seed': seed,
    'samples': samples,
    'corpus_size': corpus.length,
    'corpus_sha256': sha256.convert(utf8.encode(jsonEncode(corpus))).toString(),
    'source_sha256': {
      for (final file in sources)
        file.path.replaceAll('\\', '/'): sha256
            .convert(file.readAsBytesSync())
            .toString(),
    },
    'cases': cases,
  };
  File('test/fixtures/string_v2_reference.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );
  print('Recorded ${cases.length} V2 cases x ${corpus.length} inputs.');
}
