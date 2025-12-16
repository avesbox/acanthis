import 'dart:math' as math;

import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:acanthis/src/validators/common.dart';
import 'package:acanthis/src/validators/number.dart';
import 'package:nanoid2/nanoid2.dart';

import 'types.dart';

/// A class to validate number types
class AcanthisNumeric<T extends num> extends AcanthisType<T> {
  const AcanthisNumeric({
    super.isAsync,
    super.operations,
    super.key,
    super.metadataEntry,
    super.defaultValue,
  });

  /// Add a check to the number to check if it is less than or equal to [value]
  AcanthisNumeric<T> lte(
    T value, {
    String? message,
    String Function(T value)? messageBuilder,
  }) {
    return withCheck(
      LteNumberCheck(value, message: message, messageBuilder: messageBuilder),
    );
  }

  /// Add a check to the number to check if it is greater than or equal to [value]
  AcanthisNumeric<T> gte(
    T value, {
    String? message,
    String Function(T value)? messageBuilder,
  }) {
    return withCheck(
      GteNumberCheck(value, message: message, messageBuilder: messageBuilder),
    );
  }

  AcanthisNumeric<T> between(
    T min,
    T max, {
    String? message,
    String Function(T min, T max)? messageBuilder,
  }) {
    return withCheck(
      BetweenNumberCheck(
        min,
        max,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the number to check if it is greater than [value]
  AcanthisNumeric<T> gt(
    T value, {
    String? message,
    String Function(T value)? messageBuilder,
  }) {
    return withCheck(
      GtNumberCheck(value, message: message, messageBuilder: messageBuilder),
    );
  }

  /// Add a check to the number to check if it is less than [value]
  AcanthisNumeric<T> lt(
    T value, {
    String? message,
    String Function(T value)? messageBuilder,
  }) {
    return withCheck(
      LtNumberCheck(value, message: message, messageBuilder: messageBuilder),
    );
  }

  /// Add a check to the number to check if it is positive
  AcanthisNumeric positive({String? message}) {
    return withCheck(PositiveNumberCheck(message: message));
  }

  /// Add a check to the number to check if it is negative
  AcanthisNumeric negative({String? message}) {
    return withCheck(NegativeNumberCheck(message: message));
  }

  /// Add a check to the number to check if it is nonpositive
  AcanthisNumeric nonPositive({String? message}) {
    return withCheck(NonPositiveNumberCheck(message: message));
  }

  /// Add a check to the number to check if it is nonnegative
  AcanthisNumeric nonNegative({String? message}) {
    return withCheck(NonNegativeNumberCheck(message: message));
  }

  /// Add a check to the number to check if it is an integer
  AcanthisNumeric integer({String? message}) {
    return withCheck(IntegerNumberCheck(message: message));
  }

  /// Add a check to the number to check if it is a double
  AcanthisNumeric double({String? message}) {
    return withCheck(DoubleNumberCheck(message: message));
  }

  /// Add a check to the number to check if it is a multiple of [value]
  AcanthisNumeric multipleOf(
    int value, {
    String? message,
    String Function(int value)? messageBuilder,
  }) {
    return withCheck(
      MultipleOfCheck(value, message: message, messageBuilder: messageBuilder),
    );
  }

  /// Add a check to the number to check if it is finite
  AcanthisNumeric finite({String? message}) {
    return withCheck(FiniteNumberCheck(message: message));
  }

  /// Add a check to the number to check if it is infinite
  AcanthisNumeric infinite({String? message}) {
    return withCheck(InfiniteNumberCheck(message: message));
  }

  /// Add a check to the number to check if it is "not a number"
  AcanthisNumeric nan({String? message}) {
    return withCheck(NaNNumberCheck(message: message));
  }

  /// Add a check to the number to check if it is not "not a number"
  AcanthisNumeric notNaN({String? message}) {
    return withCheck(NotNaNNumberCheck(message: message));
  }

  /// Add a check to the number to check if it is one of the [values]
  AcanthisNumeric<T> enumerated(
    List<T> values, {
    String? message,
    String Function(List<T> values)? messageBuilder,
  }) {
    if (values.isEmpty) {
      throw ArgumentError('Enumeration values cannot be empty');
    }
    return withCheck(
      EnumeratedNumberCheck(
        values,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the number to ensure it is exactly [value]
  AcanthisNumeric<T> exact(
    T value, {
    String? message,
    String Function(T value)? messageBuilder,
  }) {
    return withCheck(
      ExactCheck<T>(
        value: value,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Transform the number to a power of [value]
  AcanthisNumeric<T> pow(int value) {
    return withTransformation(
      AcanthisTransformation<T>(
        transformation: (toTransform) => math.pow(toTransform, value) as T,
      ),
    );
  }

  @override
  AcanthisNumeric<T> withAsyncCheck(AcanthisAsyncCheck<T> check) {
    return AcanthisNumeric(
      operations: [...operations, check],
      isAsync: true,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisNumeric<T> withCheck(AcanthisCheck<T> check) {
    return AcanthisNumeric(
      operations: [...operations, check],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisNumeric<T> withTransformation(
    AcanthisTransformation<T> transformation,
  ) {
    return AcanthisNumeric(
      operations: [...operations, transformation],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
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
        if (metadataEntry != null) ...metadataEntry!.toJson(),
      };
    }
    final enumeratedCheck = operations
        .whereType<EnumeratedNumberCheck>()
        .firstOrNull;
    if (enumeratedCheck != null) {
      return {
        'enum': enumeratedCheck.values,
        if (metadataEntry != null) ...metadataEntry!.toJson(),
      };
    }
    final multipleOfCheck = operations.whereType<MultipleOfCheck>().firstOrNull;
    final constraints = _getConstraints();

    return {
      'type': type,
      if (metadataEntry != null) ...metadataEntry!.toJson(),
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
  AcanthisNumeric<T> meta(MetadataEntry<T> metadata) {
    String key = this.key;
    if (key.isEmpty) {
      key = nanoid();
    }
    MetadataRegistry().add(key, metadata);
    return AcanthisNumeric(
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadata,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisNumeric<T> withDefault(T value) {
    return AcanthisNumeric(
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: value,
    );
  }

  @override
  Map<String, dynamic> toOpenApiSchema() {
    String type = 'number';
    final constraints = _getConstraints();
    final enumerated = operations
        .whereType<EnumeratedNumberCheck>()
        .firstOrNull;
    final checks = operations.whereType<AcanthisCheck<num>>();
    if (checks.isNotEmpty) {
      for (var check in checks) {
        if (check.name == 'integer') {
          type = 'integer';
        }
      }
    }
    final exactCheck = operations.whereType<ExactCheck<num>>().firstOrNull;
    return {
      'type': type,
      if (enumerated != null) 'enum': enumerated.values,
      if (constraints.isNotEmpty) ...constraints,
      if (exactCheck != null) 'enum': [exactCheck.value],
    };
  }
}

typedef AcanthisNumber = AcanthisNumeric<num>;
typedef AcanthisInt = AcanthisNumeric<int>;
typedef AcanthisDouble = AcanthisNumeric<double>;

AcanthisNumber number() => AcanthisNumber();

AcanthisInt integer() => AcanthisInt();

AcanthisDouble doubleType() => AcanthisDouble();
