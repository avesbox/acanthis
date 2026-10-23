import 'dart:convert';
import 'dart:io';
import 'dart:math';

List<Map<String, dynamic>> stringCases() => (jsonDecode(
  File('test/fixtures/string_checks.json').readAsStringSync(),
) as List).cast<Map<String, dynamic>>();

List<String> stringCorpus({int seed = 20261014, int samples = 600}) {
  final known = <String>{
    for (final entry in stringCases()) ...[
      ...(entry['valid'] as List).cast<String>(),
      ...(entry['invalid'] as List).cast<String>(),
    ],
    'é',
    '😀',
    'a\n',
    '\n',
    '\r\n',
    '\u0000',
    'a\u0000b',
    '£',
    '\ud800',
  };
  const alphabet = <String>[
    'a',
    'Z',
    '0',
    '9',
    '-',
    '_',
    ' ',
    '\n',
    '\r',
    '!',
    '.',
    '@',
    ':',
    '/',
    '#',
    '[',
    ']',
    '=',
    '+',
    'é',
    '😀',
    '£',
  ];
  final random = Random(seed);
  return [
    ...known,
    for (var sample = 0; sample < samples; sample++)
      List.generate(
        random.nextInt(48),
        (_) => alphabet[random.nextInt(alphabet.length)],
      ).join(),
  ];
}
