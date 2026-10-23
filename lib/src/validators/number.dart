import '../common/issue.dart' show freezeIssueParameters;
import '../common/operations.dart';

/// Native numeric predicates, with frozen constraint metadata.
sealed class NumberCheck<T extends num> implements Check<T> {
  NumberCheck(this.code, {Map<String, Object?> parameters = const {}})
    : parameters = freezeIssueParameters(parameters);

  final String code;
  final Map<String, Object?> parameters;
  bool test(T value);

  @override
  void evaluate(T value, CheckContext context) {
    if (!test(value)) context.addIssue(code, parameters: parameters);
  }
}

final class LteNumberCheck<T extends num> extends NumberCheck<T> {
  LteNumberCheck(this.value) : super('lte', parameters: {'value': value});
  final T value;
  @override
  bool test(T value) => value <= this.value;
}

final class GteNumberCheck<T extends num> extends NumberCheck<T> {
  GteNumberCheck(this.value) : super('gte', parameters: {'value': value});
  final T value;
  @override
  bool test(T value) => value >= this.value;
}

final class GtNumberCheck<T extends num> extends NumberCheck<T> {
  GtNumberCheck(this.value) : super('gt', parameters: {'value': value});
  final T value;
  @override
  bool test(T value) => value > this.value;
}

final class LtNumberCheck<T extends num> extends NumberCheck<T> {
  LtNumberCheck(this.value) : super('lt', parameters: {'value': value});
  final T value;
  @override
  bool test(T value) => value < this.value;
}

final class BetweenNumberCheck<T extends num> extends NumberCheck<T> {
  BetweenNumberCheck(this.min, this.max)
    : super('between', parameters: {'min': min, 'max': max});
  final T min;
  final T max;
  @override
  bool test(T value) => value >= min && value <= max;
}

final class PositiveNumberCheck<T extends num> extends NumberCheck<T> {
  PositiveNumberCheck() : super('positive');
  @override
  bool test(T value) => value > 0;
}

final class NegativeNumberCheck<T extends num> extends NumberCheck<T> {
  NegativeNumberCheck() : super('negative');
  @override
  bool test(T value) => value < 0;
}

final class NonPositiveNumberCheck<T extends num> extends NumberCheck<T> {
  NonPositiveNumberCheck() : super('nonpositive');
  @override
  bool test(T value) => value <= 0;
}

final class NonNegativeNumberCheck<T extends num> extends NumberCheck<T> {
  NonNegativeNumberCheck() : super('nonnegative');
  @override
  bool test(T value) => value >= 0;
}

final class MultipleOfCheck<T extends num> extends NumberCheck<T> {
  MultipleOfCheck(this.value)
    : super('multipleOf', parameters: {'value': value}) {
    if (value == 0) {
      throw ArgumentError.value(value, 'value', 'Must be nonzero');
    }
  }
  final int value;
  @override
  bool test(T value) => value % this.value == 0;
}

final class IntegerNumberCheck<T extends num> extends NumberCheck<T> {
  IntegerNumberCheck() : super('integer');
  @override
  bool test(T value) => value is int;
}

final class DoubleNumberCheck<T extends num> extends NumberCheck<T> {
  DoubleNumberCheck() : super('double');
  @override
  bool test(T value) => value is! int;
}

final class FiniteNumberCheck<T extends num> extends NumberCheck<T> {
  FiniteNumberCheck() : super('finite');
  @override
  bool test(T value) => value.isFinite;
}

final class InfiniteNumberCheck<T extends num> extends NumberCheck<T> {
  InfiniteNumberCheck() : super('infinite');
  @override
  bool test(T value) => value.isInfinite;
}

final class NaNNumberCheck<T extends num> extends NumberCheck<T> {
  NaNNumberCheck() : super('nan');
  @override
  bool test(T value) => value.isNaN;
}

final class NotNaNNumberCheck<T extends num> extends NumberCheck<T> {
  NotNaNNumberCheck() : super('notNaN');
  @override
  bool test(T value) => !value.isNaN;
}

final class EnumeratedNumberCheck<T extends num> extends NumberCheck<T> {
  factory EnumeratedNumberCheck(List<T> values) {
    final snapshot = List<T>.unmodifiable(values);
    if (snapshot.isEmpty) {
      throw ArgumentError('Enumeration values cannot be empty');
    }
    return EnumeratedNumberCheck._(snapshot);
  }
  EnumeratedNumberCheck._(this.values)
    : super('enumerated', parameters: {'values': values});
  final List<T> values;
  // Retain List.contains semantics for NaN and numeric int/double equality.
  @override
  bool test(T value) => values.contains(value);
}
