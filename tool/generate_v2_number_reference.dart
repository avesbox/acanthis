// Capture a V2 regression baseline; frozen V1 compatibility fixtures stay intact.
import 'dart:convert';
import 'dart:io';

import '../test/support/number_cases.dart';

import 'package:acanthis/acanthis.dart';
import 'package:crypto/crypto.dart';

void main() {
  const seed = 20261015;
  const samples = 600;
  final corpus = numericCorpus(seed: seed, samples: samples);
  final cases = <String, String>{};
  for (final kind in ['num', 'int', 'double']) {
    for (final check in numberChecks) {
      final schema = switch (kind) {
        'num' => numericCase(number(), check, 1, 4),
        'int' => numericCase(integer(), check, 1, 4),
        'double' => numericCase(doubleType(), check, 1.0, 4.0),
        _ => throw StateError('Unknown numeric kind'),
      };
      final inputs = corpus.where(
        (value) =>
            kind == 'num' || (kind == 'int' ? value is int : value is double),
      );
      cases['$kind/$check'] = [
        for (final input in inputs) schema.tryParse(input).isValid ? '1' : '0',
      ].join();
    }
  }
  final tokens = numericCorpusTokens(corpus);
  final sources = [
    ...Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')),
    File('tool/generate_v2_number_reference.dart'),
    File('test/support/number_corpus.dart'),
    File('test/support/number_cases.dart'),
    File('pubspec.lock'),
  ]..sort((a, b) => a.path.compareTo(b.path));
  final output = {
    'implementation': 'v2',
    'sdk': Platform.version,
    'seed': seed,
    'samples': samples,
    'corpus_size': corpus.length,
    'corpus_sha256': sha256.convert(utf8.encode(jsonEncode(tokens))).toString(),
    'source_sha256': {
      for (final file in sources)
        file.path.replaceAll('\\', '/'): sha256
            .convert(file.readAsBytesSync())
            .toString(),
    },
    'cases': cases,
  };
  File('test/fixtures/number_v2_reference.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(output)}\n',
  );
  print(
    'Recorded ${cases.length} numeric V2 cases over ${corpus.length} inputs.',
  );
}
