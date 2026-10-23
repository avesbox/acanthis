import 'dart:math' as math;

import '../common/operations.dart';

/// A power operation whose result must fit the schema's numeric output type.
final class PowerNumberTransform<T extends num> implements Transform<T, T> {
  const PowerNumberTransform(this.exponent);
  final int exponent;

  T? tryApply(T value) {
    final result = math.pow(value, exponent);
    if (result is T) return result;
    if (T == int) {
      final num? integer = exactInteger(result);
      if (integer is T) return integer;
    }
    return null;
  }

  @override
  T apply(T value) =>
      tryApply(value) ??
      (throw StateError('Power result does not fit the numeric output type'));
}

/// Convert only finite integral values, rejecting platform saturation.
int? exactInteger(num value) {
  if (value is int) return value;
  if (!value.isFinite || value != value.truncateToDouble()) return null;
  final converted = value.toInt();
  if (converted.toDouble() != value) return null;
  // All valid integral doubles round-trip. The one ambiguous native endpoint
  // is int64.max: it rounds up to 2^63, hiding a saturated positive conversion.
  if (converted == 0x7fffffffffffffff) {
    return BigInt.from(converted) == BigInt.from(value) ? converted : null;
  }
  return converted;
}
