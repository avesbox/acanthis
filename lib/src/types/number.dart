import 'dart:math' as math;

import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:nanoid2/nanoid2.dart';

import 'types.dart';

/// A class to validate number types
class AcanthisNumber extends AcanthisType<num> {
  const AcanthisNumber({super.isAsync, super.operations, super.key});

  /// Add a check to the number to check if it is less than or equal to [value]
  AcanthisNumber lte(num value) {
    return withCheck(ConstraintNumberChecks.lte(value));
  }

  /// Add a check to the number to check if it is greater than or equal to [value]
  AcanthisNumber gte(num value) {
    return withCheck(ConstraintNumberChecks.gte(value));
  }

  AcanthisNumber between(num min, num max) {
    return withCheck(ConstraintsNumberChecks.between(min, max));
  }

  /// Add a check to the number to check if it is greater than [value]
  AcanthisNumber gt(num value) {
    return withCheck(ConstraintNumberChecks.gt(value));
  }

  /// Add a check to the number to check if it is less than [value]
  AcanthisNumber lt(num value) {
    return withCheck(ConstraintNumberChecks.lt(value));
  }

  /// Add a check to the number to check if it is positive
  AcanthisNumber positive() {
    return withCheck(ConstraintNumberChecks.positive());
  }

  /// Add a check to the number to check if it is negative
  AcanthisNumber negative() {
    return withCheck(ConstraintNumberChecks.negative());
  }

  /// Add a check to the number to check if it is an integer
  AcanthisNumber integer() {
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => toTest is int,
        error: 'Value must be an integer',
        name: 'integer'));
  }

  /// Add a check to the number to check if it is a double
  AcanthisNumber double() {
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => toTest is! int,
        error: 'Value must be a double',
        name: 'double'));
  }

  /// Add a check to the number to check if it is a multiple of [value]
  AcanthisNumber multipleOf(int value) {
    return withCheck(MultipleOfCheck(value));
  }

  /// Add a check to the number to check if it is finite
  AcanthisNumber finite() {
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => toTest.isFinite,
        error: 'Value is not finite',
        name: 'finite'));
  }

  /// Add a check to the number to check if it is infinite
  AcanthisNumber infinite() {
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => toTest.isInfinite,
        error: 'Value is not infinite',
        name: 'infinite'));
  }

  /// Add a check to the number to check if it is "not a number"
  AcanthisNumber nan() {
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => toTest.isNaN,
        error: 'Value is not NaN',
        name: 'nan'));
  }

  /// Add a check to the number to check if it is not "not a number"
  AcanthisNumber notNaN() {
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => !toTest.isNaN,
        error: 'Value is NaN',
        name: 'notNaN'));
  }

  /// Add a check to the number to check if it is one of the [values]
  AcanthisNumber enumerated(List<num> values) {
    return withCheck(EnumeratedNumberCheck(values));
  }

  AcanthisNumber exact(num value) {
    return withCheck(ExactCheck<num>(value: value));
  }

  /// Transform the number to a power of [value]
  AcanthisNumber pow(int value) {
    return withTransformation(AcanthisTransformation<num>(
        transformation: (toTransform) => math.pow(toTransform, value)));
  }

  @override
  AcanthisNumber withAsyncCheck(AcanthisAsyncCheck<num> check) {
    return AcanthisNumber(
        operations: operations.add(check), isAsync: true, key: key);
  }

  @override
  AcanthisNumber withCheck(AcanthisCheck<num> check) {
    return AcanthisNumber(
        operations: operations.add(check), isAsync: isAsync, key: key);
  }

  @override
  AcanthisNumber withTransformation(
      AcanthisTransformation<num> transformation) {
    return AcanthisNumber(
        operations: operations.add(transformation), isAsync: isAsync, key: key);
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    final metadata = MetadataRegistry().get(key);
    String type = 'number';
    final checks = operations.whereType<AcanthisCheck<num>>();
    if (checks.isNotEmpty) {
      for (var check in checks) {
        if (check.name == 'integer') {
          type = 'integer';
        }
      }
    }
    final exactCheck = operations.whereType<ExactCheck<num>>().firstOrNull;
    if (exactCheck != null) {
      return {
        'const': exactCheck.value,
        if (metadata != null) ...metadata.toJson(),
      };
    }
    final enumeratedCheck =
        operations.whereType<EnumeratedNumberCheck>().firstOrNull;
    if (enumeratedCheck != null) {
      return {
        'enum': enumeratedCheck.values,
        if (metadata != null) ...metadata.toJson(),
      };
    }
    final multipleOfCheck = operations.whereType<MultipleOfCheck>().firstOrNull;
    final constraints = _getConstraints();

    return {
      'type': type,
      if (metadata != null) ...metadata.toJson(),
      if (multipleOfCheck != null) 'multipleOf': multipleOfCheck.value,
      if (constraints.isNotEmpty) ...constraints,
    };
  }

  Map<String, dynamic> _getConstraints() {
    final constraints = operations.whereType<ConstraintNumberChecks>();
    final constraintsList = operations.whereType<ConstraintsNumberChecks>();
    final constraintsMap = <String, dynamic>{};
    for (var constraint in constraints) {
      if (constraint.name == 'gte') {
        constraintsMap['minimum'] = constraint.value;
      } else if (constraint.name == 'lte') {
        constraintsMap['maximum'] = constraint.value;
      } else if (constraint.name == 'gt') {
        constraintsMap['exclusiveMinimum'] = constraint.value;
      } else if (constraint.name == 'lt') {
        constraintsMap['exclusiveMaximum'] = constraint.value;
      } else if (constraint.name == 'positive') {
        constraintsMap['exclusiveMinimum'] = 0;
      } else if (constraint.name == 'negative') {
        constraintsMap['exclusiveMaximum'] = 0;
      }
    }
    for (var constraint in constraintsList) {
      if (constraint.name == 'between') {
        constraintsMap['minimum'] = constraint.lowerLimit;
        constraintsMap['maximum'] = constraint.upperLimit;
      }
    }
    return constraintsMap;
  }

  @override
  AcanthisNumber meta(MetadataEntry<num> metadata) {
    String key = this.key;
    if (key.isEmpty) {
      key = nanoid();
    }
    MetadataRegistry().add(key, metadata);
    return AcanthisNumber(
      operations: operations,
      isAsync: isAsync,
      key: key,
    );
  }
}

class EnumeratedNumberCheck extends AcanthisCheck<num> {
  final List<num> values;

  EnumeratedNumberCheck(this.values)
      : super(
          onCheck: (toTest) => values.contains(toTest),
          error: 'Value must be one of the following: ${values.join(', ')}',
          name: 'enum',
        );
}

class MultipleOfCheck extends AcanthisCheck<num> {
  final int value;

  MultipleOfCheck(this.value)
      : super(
          onCheck: (toTest) => toTest % value == 0,
          error: 'Value must be a multiple of $value',
          name: 'multipleOf',
        );
}

class ConstraintsNumberChecks extends AcanthisCheck<num> {
  final num upperLimit;
  final num lowerLimit;

  ConstraintsNumberChecks(
      {required this.upperLimit,
      required this.lowerLimit,
      required super.name,
      required super.error,
      required super.onCheck});

  static ConstraintsNumberChecks between(num min, num max) {
    return ConstraintsNumberChecks(
      upperLimit: max,
      lowerLimit: min,
      error: 'Value must be between $min and $max',
      name: 'between',
      onCheck: (toTest) => toTest >= min && toTest <= max,
    );
  }
}

class ConstraintNumberChecks extends AcanthisCheck<num> {
  final num value;

  ConstraintNumberChecks(
      {required this.value,
      required super.name,
      required super.error,
      required super.onCheck});

  static ConstraintNumberChecks gte(num value) {
    return ConstraintNumberChecks(
      value: value,
      error: 'Value must be greater than or equal to $value',
      name: 'gte',
      onCheck: (toTest) => toTest >= value,
    );
  }

  static ConstraintNumberChecks lte(num value) {
    return ConstraintNumberChecks(
      value: value,
      error: 'Value must be less than or equal to $value',
      name: 'lte',
      onCheck: (toTest) => toTest <= value,
    );
  }

  static ConstraintNumberChecks gt(num value) {
    return ConstraintNumberChecks(
      value: value,
      error: 'Value must be greater than $value',
      name: 'gt',
      onCheck: (toTest) => toTest > value,
    );
  }

  static ConstraintNumberChecks lt(num value) {
    return ConstraintNumberChecks(
      value: value,
      error: 'Value must be less than $value',
      name: 'lt',
      onCheck: (toTest) => toTest < value,
    );
  }

  static ConstraintNumberChecks positive() {
    return ConstraintNumberChecks(
      value: 0,
      error: 'Value must be positive',
      name: 'positive',
      onCheck: (toTest) => toTest > 0,
    );
  }

  static ConstraintNumberChecks negative() {
    return ConstraintNumberChecks(
      value: 0,
      error: 'Value must be negative',
      name: 'negative',
      onCheck: (toTest) => toTest < 0,
    );
  }
}

/// Create a number type
AcanthisNumber number() => AcanthisNumber();
