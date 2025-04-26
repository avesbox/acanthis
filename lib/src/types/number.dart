import 'dart:math' as math;

import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:acanthis/src/validators/common.dart';
import 'package:acanthis/src/validators/number.dart';
import 'package:nanoid2/nanoid2.dart';

import 'types.dart';

/// A class to validate number types
class AcanthisNumber extends AcanthisType<num> {
  const AcanthisNumber({super.isAsync, super.operations, super.key});

  /// Add a check to the number to check if it is less than or equal to [value]
  AcanthisNumber lte(num value) {
    return withCheck(LteNumberCheck(value));
  }

  /// Add a check to the number to check if it is greater than or equal to [value]
  AcanthisNumber gte(num value) {
    return withCheck(GteNumberCheck(value));
  }

  AcanthisNumber between(num min, num max) {
    return withCheck(BetweenNumberCheck(min, max));
  }

  /// Add a check to the number to check if it is greater than [value]
  AcanthisNumber gt(num value) {
    return withCheck(GtNumberCheck(value));
  }

  /// Add a check to the number to check if it is less than [value]
  AcanthisNumber lt(num value) {
    return withCheck(LtNumberCheck(value));
  }

  /// Add a check to the number to check if it is positive
  AcanthisNumber positive() {
    return withCheck(PositiveNumberCheck());
  }

  /// Add a check to the number to check if it is negative
  AcanthisNumber negative() {
    return withCheck(NegativeNumberCheck());
  }

  /// Add a check to the number to check if it is nonpositive
  AcanthisNumber nonPositive() {
    return withCheck(NonPositiveNumberCheck());
  }

  /// Add a check to the number to check if it is nonnegative
  AcanthisNumber nonNegative() {
    return withCheck(NonNegativeNumberCheck());
  }

  /// Add a check to the number to check if it is an integer
  AcanthisNumber integer() {
    return withCheck(IntegerNumberCheck());
  }

  /// Add a check to the number to check if it is a double
  AcanthisNumber double() {
    return withCheck(DoubleNumberCheck());
  }

  /// Add a check to the number to check if it is a multiple of [value]
  AcanthisNumber multipleOf(int value) {
    return withCheck(MultipleOfCheck(value));
  }

  /// Add a check to the number to check if it is finite
  AcanthisNumber finite() {
    return withCheck(FiniteNumberCheck());
  }

  /// Add a check to the number to check if it is infinite
  AcanthisNumber infinite() {
    return withCheck(InfiniteNumberCheck());
  }

  /// Add a check to the number to check if it is "not a number"
  AcanthisNumber nan() {
    return withCheck(NaNNumberCheck());
  }

  /// Add a check to the number to check if it is not "not a number"
  AcanthisNumber notNaN() {
    return withCheck(NotNaNNumberCheck());
  }

  /// Add a check to the number to check if it is one of the [values]
  AcanthisNumber enumerated(List<num> values) {
    if (values.isEmpty) {
      throw ArgumentError('Enumeration values cannot be empty');
    }
    return withCheck(EnumeratedNumberCheck(values));
  }

  /// Add a check to the number to ensure it is exactly [value]
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
        operations: [
          ...operations,
          check,
        ], isAsync: true, key: key);
  }

  @override
  AcanthisNumber withCheck(AcanthisCheck<num> check) {
    return AcanthisNumber(
        operations: [
          ...operations,
          check,
        ], isAsync: isAsync, key: key);
  }

  @override
  AcanthisNumber withTransformation(
      AcanthisTransformation<num> transformation) {
    return AcanthisNumber(
        operations: [
          ...operations,
          transformation,
        ], isAsync: isAsync, key: key);
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
    final constraints = operations.whereType<AcanthisCheck>();
    final constraintsMap = <String, dynamic>{};
    for (var constraint in constraints) {
      if (constraint is GteNumberCheck) {
        constraintsMap['minimum'] = constraint.value;
      } else if (constraint is LteNumberCheck) {
        constraintsMap['maximum'] = constraint.value;
      } else if (constraint is GtNumberCheck) {
        constraintsMap['exclusiveMinimum'] = constraint.value;
      } else if (constraint is LtNumberCheck) {
        constraintsMap['exclusiveMaximum'] = constraint.value;
      } else if (constraint is PositiveNumberCheck) {
        constraintsMap['exclusiveMinimum'] = 0;
      } else if (constraint is NegativeNumberCheck) {
        constraintsMap['exclusiveMaximum'] = 0;
      } else if (constraint is NonPositiveNumberCheck) {
        constraintsMap['maximum'] = 0;
      } else if (constraint is NonNegativeNumberCheck) {
        constraintsMap['minimum'] = 0;
      }
    }
    for (var constraint in constraints) {
      if (constraint is BetweenNumberCheck) {
        constraintsMap['minimum'] = constraint.min;
        constraintsMap['maximum'] = constraint.max;
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

/// Create a number type
AcanthisNumber number() => AcanthisNumber();
