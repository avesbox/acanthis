import 'package:acanthis/src/operations/checks.dart';

/// Number check for less than or equal to a value.
class LteNumberCheck<T extends num> extends AcanthisCheck<T> {
  final T value;

  LteNumberCheck(
    this.value, {
    String? message,
    String Function(T value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must be less than or equal to $value',
         name: 'lte',
       );

  @override
  bool call(T value) {
    return value <= this.value;
  }
}

/// Number check for greater than or equal to a value.
class GteNumberCheck<T extends num> extends AcanthisCheck<T> {
  final T value;

  GteNumberCheck(
    this.value, {
    String? message,
    String Function(T value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must be greater than or equal to $value',
         name: 'gte',
       );

  @override
  bool call(T value) {
    return value >= this.value;
  }
}

/// Number check for between two values.
class BetweenNumberCheck<T extends num> extends AcanthisCheck<T> {
  final T min;
  final T max;

  BetweenNumberCheck(
    this.min,
    this.max, {
    String? message,
    String Function(T min, T max)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(min, max) ??
             message ??
             'Value must be between $min and $max',
         name: 'between',
       );

  @override
  bool call(T value) {
    return value >= min && value <= max;
  }
}

/// Number check for Greater than a value.
class GtNumberCheck<T extends num> extends AcanthisCheck<T> {
  final T value;

  GtNumberCheck(
    this.value, {
    String? message,
    String Function(T value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must be greater than $value',
         name: 'gt',
       );

  @override
  bool call(T value) {
    return value > this.value;
  }
}

/// Number check for Less than a value.
class LtNumberCheck<T extends num> extends AcanthisCheck<T> {
  final T value;

  LtNumberCheck(
    this.value, {
    String? message,
    String Function(T value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must be less than $value',
         name: 'lt',
       );

  @override
  bool call(T value) {
    return value < this.value;
  }
}

/// Number check for positive value.
class PositiveNumberCheck<T extends num> extends AcanthisCheck<T> {
  const PositiveNumberCheck({String? message})
    : super(error: message ?? 'Value must be positive', name: 'positive');

  @override
  bool call(T value) {
    return value > 0;
  }
}

/// Number check for negative value.
class NegativeNumberCheck<T extends num> extends AcanthisCheck<T> {
  const NegativeNumberCheck({String? message})
    : super(error: message ?? 'Value must be negative', name: 'negative');

  @override
  bool call(T value) {
    return value < 0;
  }
}

/// Number check for nonpositive value.
class NonPositiveNumberCheck<T extends num> extends AcanthisCheck<T> {
  const NonPositiveNumberCheck({String? message})
    : super(error: message ?? 'Value must be nonpositive', name: 'nonpositive');

  @override
  bool call(T value) {
    return value <= 0;
  }
}

/// Number check for nonnegative value.
class NonNegativeNumberCheck<T extends num> extends AcanthisCheck<T> {
  const NonNegativeNumberCheck({String? message})
    : super(error: message ?? 'Value must be nonnegative', name: 'nonnegative');

  @override
  bool call(T value) {
    return value >= 0;
  }
}

/// Number check for multiple of a value.
class MultipleOfCheck<T extends num> extends AcanthisCheck<T> {
  final int value;

  MultipleOfCheck(
    this.value, {
    String? message,
    String Function(int value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must be a multiple of $value',
         name: 'multipleOf',
       );

  @override
  bool call(T value) {
    return value % this.value == 0;
  }
}

/// Number check for integer value.
class IntegerNumberCheck<T extends num> extends AcanthisCheck<T> {
  const IntegerNumberCheck({String? message})
    : super(error: message ?? 'Value must be an integer', name: 'integer');

  @override
  bool call(T value) {
    return value is int;
  }
}

/// Number check for double value.
class DoubleNumberCheck<T extends num> extends AcanthisCheck<T> {
  const DoubleNumberCheck({String? message})
    : super(error: message ?? 'Value must be a double', name: 'double');

  @override
  bool call(T value) {
    return value is! int;
  }
}

/// Number check for finite value.
class FiniteNumberCheck<T extends num> extends AcanthisCheck<T> {
  const FiniteNumberCheck({String? message})
    : super(error: message ?? 'Value must be finite', name: 'finite');

  @override
  bool call(T value) {
    return value.isFinite;
  }
}

/// Number check for infinite value.
class InfiniteNumberCheck<T extends num> extends AcanthisCheck<T> {
  const InfiniteNumberCheck({String? message})
    : super(error: message ?? 'Value must be infinite', name: 'infinite');

  @override
  bool call(T value) {
    return value.isInfinite;
  }
}

/// Number check for NaN value.
class NaNNumberCheck<T extends num> extends AcanthisCheck<T> {
  const NaNNumberCheck({String? message})
    : super(error: message ?? 'Value must be NaN', name: 'nan');

  @override
  bool call(T value) {
    return value.isNaN;
  }
}

/// Number check for not NaN value.
class NotNaNNumberCheck<T extends num> extends AcanthisCheck<T> {
  const NotNaNNumberCheck({String? message})
    : super(error: message ?? 'Value must not be NaN', name: 'notNaN');

  @override
  bool call(T value) {
    return !value.isNaN;
  }
}

/// Number check for enumerated values.
class EnumeratedNumberCheck<T extends num> extends AcanthisCheck<T> {
  final List<T> values;

  EnumeratedNumberCheck(
    this.values, {
    String? message,
    String Function(List<T> values)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(values) ??
             message ??
             'Value must be one of the enumerated values',
         name: 'enumerated',
       );

  @override
  bool call(T value) {
    return values.contains(value);
  }
}
