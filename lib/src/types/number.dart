import 'dart:math' as math;

import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:nanoid2/nanoid2.dart';

import 'list.dart';
import 'types.dart';
import 'union.dart';

/// A class to validate number types
class AcanthisNumber extends AcanthisType<num> {
  const AcanthisNumber({super.isAsync, super.operations, super.key});

  /// Add a check to the number to check if it is less than or equal to [value]
  AcanthisNumber lte(num value) {
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => toTest <= value,
        error: 'Value must be less than or equal to $value',
        name: 'lte'));
  }

  /// Add a check to the number to check if it is greater than or equal to [value]
  AcanthisNumber gte(num value) {
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => toTest >= value,
        error: 'Value must be greater than or equal to $value',
        name: 'gte'));
  }

  AcanthisNumber between(num min, num max) {
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => toTest >= min && toTest <= max,
        error: 'Value must be between $min and $max',
        name: 'between'));
  }

  /// Add a check to the number to check if it is greater than [value]
  AcanthisNumber gt(num value) {
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => toTest > value,
        error: 'Value must be greater than $value',
        name: 'gt'));
  }

  /// Add a check to the number to check if it is less than [value]
  AcanthisNumber lt(num value) {
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => toTest < value,
        error: 'Value must be less than $value',
        name: 'lt'));
  }

  /// Add a check to the number to check if it is positive
  AcanthisNumber positive() {
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => toTest > 0,
        error: 'Value must be positive',
        name: 'positive'));
  }

  /// Add a check to the number to check if it is negative
  AcanthisNumber negative() {
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => toTest < 0,
        error: 'Value must be negative',
        name: 'negative'));
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
    return withCheck(AcanthisCheck<num>(
        onCheck: (toTest) => toTest % value == 0,
        error: 'Value must be a multiple of $value',
        name: 'multipleOf'));
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

  /// Create a list of numbers
  AcanthisList<num> list() {
    return AcanthisList<num>(this);
  }

  /// Transform the number to a power of [value]
  AcanthisNumber pow(int value) {
    return withTransformation(AcanthisTransformation<num>(
        transformation: (toTransform) => math.pow(toTransform, value)));
  }

  /// Create a union from the number
  AcanthisUnion or(List<AcanthisType> elements) {
    return AcanthisUnion([this, ...elements]);
  }

  @override
  AcanthisNumber withAsyncCheck(AcanthisAsyncCheck<num> check) {
    return AcanthisNumber(operations: operations.add(check), isAsync: true, key: key);
  }

  @override
  AcanthisNumber withCheck(AcanthisCheck<num> check) {
    return AcanthisNumber(operations: operations.add(check), isAsync: isAsync, key: key);
  }

  @override
  AcanthisNumber withTransformation(
      AcanthisTransformation<num> transformation) {
    return AcanthisNumber(operations: operations.add(transformation), isAsync: isAsync, key: key);
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
    return {
      'type': type,
      if (metadata != null) ...metadata.toJson(),
    };
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
