import 'dart:math';

const numberChecks = [
  'lte',
  'gte',
  'lt',
  'gt',
  'between',
  'positive',
  'negative',
  'nonPositive',
  'nonNegative',
  'integer',
  'double',
  'multipleOf',
  'finite',
  'infinite',
  'nan',
  'notNaN',
  'enumerated',
  'exact',
];

List<num> numericCorpus({int seed = 20261015, int samples = 600}) {
  final random = Random(seed);
  return [
    -10,
    -2,
    -1,
    0,
    1,
    2,
    3,
    4,
    5,
    10,
    -10.0,
    -2.0,
    -1.0,
    -0.0,
    0.0,
    0.5,
    1.0,
    1.5,
    2.0,
    3.0,
    4.0,
    5.0,
    10.0,
    double.nan,
    double.infinity,
    double.negativeInfinity,
    9007199254740991,
    9007199254740992,
    9007199254740993,
    9223372036854775807,
    -9223372036854775808,
    1e40,
    -1e40,
    for (var sample = 0; sample < samples; sample++)
      random.nextBool()
          ? random.nextInt(20001) - 10000
          : (random.nextDouble() - 0.5) * 20000,
  ];
}

List<Map<String, String>> numericCorpusTokens(List<num> corpus) => [
  for (final value in corpus)
    {'type': value is int ? 'int' : 'double', 'value': value.toString()},
];
