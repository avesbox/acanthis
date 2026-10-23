import 'package:acanthis/acanthis.dart';

export 'number_corpus.dart';

AcanthisNumeric<T> numericCase<T extends num>(
  AcanthisNumeric<T> schema,
  String check,
  T lower,
  T upper,
) => switch (check) {
  'lte' => schema.lte(upper),
  'gte' => schema.gte(lower),
  'lt' => schema.lt(upper),
  'gt' => schema.gt(lower),
  'between' => schema.between(lower, upper),
  'positive' => schema.positive(),
  'negative' => schema.negative(),
  'nonPositive' => schema.nonPositive(),
  'nonNegative' => schema.nonNegative(),
  'integer' => schema.integer(),
  'double' => schema.double(),
  'multipleOf' => schema.multipleOf(2),
  'finite' => schema.finite(),
  'infinite' => schema.infinite(),
  'nan' => schema.nan(),
  'notNaN' => schema.notNaN(),
  'enumerated' => schema.enumerated([lower, upper]),
  'exact' => schema.exact(lower),
  _ => throw StateError('Missing numeric case: $check'),
};
