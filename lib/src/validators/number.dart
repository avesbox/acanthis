import 'package:acanthis/src/operations/checks.dart';

/// Number check for less than or equal to a value.
class LteNumberCheck extends AcanthisCheck<num> {
  final num value;

  LteNumberCheck(
    this.value, {
    String? message,
    String Function(num value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must be less than or equal to $value',
         name: 'lte',
       );

  @override
  bool call(num value) {
    return value <= this.value;
  }
}

/// Number check for greater than or equal to a value.
class GteNumberCheck extends AcanthisCheck<num> {
  final num value;

  GteNumberCheck(
    this.value, {
    String? message,
    String Function(num value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must be greater than or equal to $value',
         name: 'gte',
       );

  @override
  bool call(num value) {
    return value >= this.value;
  }
}

/// Number check for between two values.
class BetweenNumberCheck extends AcanthisCheck<num> {
  final num min;
  final num max;

  BetweenNumberCheck(
    this.min,
    this.max, {
    String? message,
    String Function(num min, num max)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(min, max) ??
             message ??
             'Value must be between $min and $max',
         name: 'between',
       );

  @override
  bool call(num value) {
    return value >= min && value <= max;
  }
}

/// Number check for Greater than a value.
class GtNumberCheck extends AcanthisCheck<num> {
  final num value;

  GtNumberCheck(
    this.value, {
    String? message,
    String Function(num value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must be greater than $value',
         name: 'gt',
       );

  @override
  bool call(num value) {
    return value > this.value;
  }
}

/// Number check for Less than a value.
class LtNumberCheck extends AcanthisCheck<num> {
  final num value;

  LtNumberCheck(
    this.value, {
    String? message,
    String Function(num value)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(value) ??
             message ??
             'Value must be less than $value',
         name: 'lt',
       );

  @override
  bool call(num value) {
    return value < this.value;
  }
}

/// Number check for positive value.
class PositiveNumberCheck extends AcanthisCheck<num> {
  const PositiveNumberCheck({String? message})
    : super(error: message ?? 'Value must be positive', name: 'positive');

  @override
  bool call(num value) {
    return value > 0;
  }
}

/// Number check for negative value.
class NegativeNumberCheck extends AcanthisCheck<num> {
  const NegativeNumberCheck({String? message})
    : super(error: message ?? 'Value must be negative', name: 'negative');

  @override
  bool call(num value) {
    return value < 0;
  }
}

/// Number check for nonpositive value.
class NonPositiveNumberCheck extends AcanthisCheck<num> {
  const NonPositiveNumberCheck({String? message})
    : super(error: message ?? 'Value must be nonpositive', name: 'nonpositive');

  @override
  bool call(num value) {
    return value <= 0;
  }
}

/// Number check for nonnegative value.
class NonNegativeNumberCheck extends AcanthisCheck<num> {
  const NonNegativeNumberCheck({String? message})
    : super(error: message ?? 'Value must be nonnegative', name: 'nonnegative');

  @override
  bool call(num value) {
    return value >= 0;
  }
}

/// Number check for multiple of a value.
class MultipleOfCheck extends AcanthisCheck<num> {
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
  bool call(num value) {
    return value % this.value == 0;
  }
}

/// Number check for integer value.
class IntegerNumberCheck extends AcanthisCheck<num> {
  const IntegerNumberCheck({String? message})
    : super(error: message ?? 'Value must be an integer', name: 'integer');

  @override
  bool call(num value) {
    return value is int;
  }
}

/// Number check for double value.
class DoubleNumberCheck extends AcanthisCheck<num> {
  const DoubleNumberCheck({String? message})
    : super(error: message ?? 'Value must be a double', name: 'double');

  @override
  bool call(num value) {
    return value is! int;
  }
}

/// Number check for finite value.
class FiniteNumberCheck extends AcanthisCheck<num> {
  const FiniteNumberCheck({String? message})
    : super(error: message ?? 'Value must be finite', name: 'finite');

  @override
  bool call(num value) {
    return value.isFinite;
  }
}

/// Number check for infinite value.
class InfiniteNumberCheck extends AcanthisCheck<num> {
  const InfiniteNumberCheck({String? message})
    : super(error: message ?? 'Value must be infinite', name: 'infinite');

  @override
  bool call(num value) {
    return value.isInfinite;
  }
}

/// Number check for NaN value.
class NaNNumberCheck extends AcanthisCheck<num> {
  const NaNNumberCheck({String? message})
    : super(error: message ?? 'Value must be NaN', name: 'nan');

  @override
  bool call(num value) {
    return value.isNaN;
  }
}

/// Number check for not NaN value.
class NotNaNNumberCheck extends AcanthisCheck<num> {
  const NotNaNNumberCheck({String? message})
    : super(error: message ?? 'Value must not be NaN', name: 'notNaN');

  @override
  bool call(num value) {
    return !value.isNaN;
  }
}

/// Number check for enumerated values.
class EnumeratedNumberCheck extends AcanthisCheck<num> {
  final List<num> values;

  EnumeratedNumberCheck(
    this.values, {
    String? message,
    String Function(List<num> values)? messageBuilder,
  }) : super(
         error:
             messageBuilder?.call(values) ??
             message ??
             'Value must be one of the enumerated values',
         name: 'enumerated',
       );

  @override
  bool call(num value) {
    return values.contains(value);
  }
}
