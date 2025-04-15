import 'dart:math' as math;
import 'dart:core' as core;
import 'dart:core';

import 'types.dart';

/// A class to validate number types
extension AcanthisNumberExt on AcanthisType<num> {
  /// Add a check to the number to check if it is less than or equal to [value]
  AcanthisType<num> lte(num value) {
    return withCheck(NumericChecks.lte(value));
  }

  /// Add a check to the number to check if it is greater than or equal to [value]
  AcanthisType<num> gte(num value) {
    return withCheck(NumericChecks.gte(value));
  }

  AcanthisType<num> between(num min, num max) {
    return withCheck(
      NumericChecks.between(
        min: min,
        max: max,
      ),
    );
  }

  /// Add a check to the number to check if it is greater than [value]
  AcanthisType<num> gt(num value) {
    return withCheck(NumericChecks.gt(value));
  }

  /// Add a check to the number to check if it is less than [value]
  AcanthisType<num> lt(num value) {
    return withCheck(NumericChecks.lt(value));
  }

  /// Add a check to the number to check if it is positive
  AcanthisType<num> positive() {
    return withCheck(NumericChecks.positive);
  }

  /// Add a check to the number to check if it is negative
  AcanthisType<num> negative() {
    return withCheck(NumericChecks.negative);
  }

  /// Add a check to the number to check if it is an integer
  AcanthisType<num> integer() {
    return withCheck(NumericChecks.int);
  }

  /// Add a check to the number to check if it is a double
  AcanthisType<num> double() {
    return withCheck(NumericChecks.double);
  }

  /// Add a check to the number to check if it is a multiple of [value]
  AcanthisType<num> multipleOf(int value) {
    return withCheck(NumericChecks.multipleOf(value));
  }

  /// Add a check to the number to check if it is finite
  AcanthisType<num> finite() {
    return withCheck(NumericChecks.finite);
  }

  /// Add a check to the number to check if it is infinite
  AcanthisType<num> infinite() {
    return withCheck(NumericChecks.infinite);
  }

  /// Add a check to the number to check if it is "not a number"
  AcanthisType<num> nan() {
    return withCheck(NumericChecks.nan);
  }

  /// Add a check to the number to check if it is not "not a number"
  AcanthisType<num> notNaN() {
    return withCheck(NumericChecks.notNaN);
  }

  /// Transform the number to a power of [value]
  AcanthisType<num> pow(num value) {
    return withTransformation(NumericTransforms.pow(value));
  }
}

/// Create a number type
AcanthisType<num> number() => AcanthisType<num>();

abstract class NumericChecks extends BaseAcanthisCheck<num> {
  const NumericChecks();

  const factory NumericChecks.lte(num value) = _LteCheck;
  const factory NumericChecks.gte(num value) = _GteCheck;
  const factory NumericChecks.gt(num value) = _GtCheck;
  const factory NumericChecks.lt(num value) = _LtCheck;
  const factory NumericChecks.between({required num min, required num max}) =
      _BetweenCheck;
  const factory NumericChecks.multipleOf(num value) = _MultipleOfCheck;

  static bool _positiveCheck(num toTest) => toTest > 0;
  static const positive = AcanthisCheck<num>(
      onCheck: _positiveCheck,
      name: "positive",
      error: 'Value must be positive');
  static bool _negativeCheck(num toTest) => toTest < 0;

  static const negative = AcanthisCheck<num>(
      onCheck: _negativeCheck,
      error: 'Value must be negative',
      name: 'negative');

  static bool _isIntegerCheck(num toTest) => toTest is core.int;
  static const int = AcanthisCheck<num>(
      onCheck: _isIntegerCheck,
      error: 'Value must be an integer',
      name: 'integer');

  static bool _isDoubleCheck(num toTest) => toTest is core.double;
  static const double = AcanthisCheck<num>(
      onCheck: _isDoubleCheck, error: 'Value must be a double', name: 'double');

  static bool _finiteCheck(num toTest) => toTest.isFinite;
  static const finite = AcanthisCheck<num>(
      onCheck: _finiteCheck, error: 'Value is not finite', name: 'finite');

  static bool _isInfiniteCheck(num toTest) => toTest.isInfinite;
  static const infinite = AcanthisCheck<num>(
      onCheck: _isInfiniteCheck,
      error: 'Value is not infinite',
      name: 'infinite');

  static bool _isNaNCheck(num toTest) => toTest.isNaN;
  static const nan = AcanthisCheck<num>(
      onCheck: _isNaNCheck, error: 'Value is not NaN', name: 'nan');

  static bool _isNotNaNCheck(num toTest) => !toTest.isNaN;
  static const notNaN = AcanthisCheck<num>(
      onCheck: _isNotNaNCheck, error: 'Value is NaN', name: 'notNaN');
}

class _LteCheck extends NumericChecks {
  final num value;
  const _LteCheck(this.value);

  @override
  bool onCheck(num toTest) => toTest <= value;

  @override
  String get error => 'Value must be less than or equal to $value';
  @override
  String get name => 'lte';
}

class _GteCheck extends NumericChecks {
  final num value;
  const _GteCheck(this.value);

  @override
  bool onCheck(num toTest) => toTest >= value;

  @override
  String get error => 'Value must be greater than or equal to $value';
  @override
  String get name => 'gte';
}

class _GtCheck extends NumericChecks {
  final num value;
  const _GtCheck(this.value);

  @override
  bool onCheck(num toTest) => toTest > value;

  @override
  String get error => 'Value must be greater than $value';
  @override
  String get name => 'gt';
}

class _LtCheck extends NumericChecks {
  final num value;
  const _LtCheck(this.value);

  @override
  bool onCheck(num toTest) => toTest < value;
  @override
  String get error => 'Value must be less than $value';
  @override
  String get name => 'lt';
}

class _MultipleOfCheck extends NumericChecks {
  final num value;
  const _MultipleOfCheck(this.value);

  @override
  bool onCheck(num toTest) => toTest % value == 0;
  @override
  String get error => 'Value must be a multiple of $value';
  @override
  String get name => 'multipleOf';
}

class _BetweenCheck extends NumericChecks {
  final num min;
  final num max;
  const _BetweenCheck({required this.min, required this.max});

  @override
  bool onCheck(num toTest) => toTest >= min && toTest <= max;
  @override
  String get error => 'Value must be between $min and $max';
  @override
  String get name => 'between';
}

abstract class NumericTransforms extends BaseAcanthisTransformation<num> {
  const NumericTransforms();
  const factory NumericTransforms.pow(num value) = _PowerTransformation;
}

class _PowerTransformation extends NumericTransforms {
  final num exponent;
  const _PowerTransformation(this.exponent);

  @override
  num transformation(num toTransform) => math.pow(toTransform, exponent);
}
