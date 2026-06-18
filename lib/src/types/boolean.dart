import 'dart:math';

import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:acanthis/src/validators/boolean.dart';
import 'package:nanoid2/nanoid2.dart';

import '../exceptions/validation_error.dart';
import 'types.dart';

class AcanthisBoolean extends AcanthisType<bool> {
  final bool coercionEnabled;

  @override
  bool get isPure => !coercionEnabled && super.isPure;

  AcanthisBoolean({
    super.operations,
    super.isAsync,
    super.key,
    super.metadataEntry,
    super.defaultValue,
    this.coercionEnabled = false,
  });

  AcanthisBoolean coerce() {
    return AcanthisBoolean(
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
      coercionEnabled: true,
    );
  }

  @override
  bool coerceInput(dynamic value) {
    if (!coercionEnabled) {
      return super.coerceInput(value);
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
    }
    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
          return true;
        case 'false':
        case '0':
          return false;
      }
    }
    throw ValidationError(
      'Invalid value: $value, expected coercible boolean value',
    );
  }

  /// Add a check to the boolean to check if it is true
  AcanthisBoolean isTrue({String? message}) {
    return withCheck(IsTrueCheck(message: message));
  }

  /// Add a check to the boolean to check if it is false
  AcanthisBoolean isFalse({String? message}) {
    return withCheck(IsFalseCheck(message: message));
  }

  @override
  AcanthisBoolean withAsyncCheck(AcanthisAsyncCheck<bool> check) {
    return AcanthisBoolean(
      operations: [...operations, check],
      isAsync: true,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
      coercionEnabled: coercionEnabled,
    );
  }

  @override
  AcanthisBoolean withCheck(AcanthisCheck<bool> check) {
    return AcanthisBoolean(
      operations: [...operations, check],
      key: key,
      isAsync: isAsync,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
      coercionEnabled: coercionEnabled,
    );
  }

  @override
  AcanthisBoolean withTransformation(
    AcanthisTransformation<bool> transformation,
  ) {
    return AcanthisBoolean(
      operations: [...operations, transformation],
      key: key,
      isAsync: isAsync,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
      coercionEnabled: coercionEnabled,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return {
      'type': 'boolean',
      if (metadataEntry != null) ...metadataEntry!.toJson(),
    };
  }

  @override
  AcanthisBoolean meta(MetadataEntry<bool> metadata) {
    String key = this.key;
    if (key.isEmpty) {
      key = nanoid();
    }
    MetadataRegistry().add(key, metadata);
    return AcanthisBoolean(
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadata,
      defaultValue: defaultValue,
      coercionEnabled: coercionEnabled,
    );
  }

  @override
  AcanthisBoolean withDefault(bool value) {
    return AcanthisBoolean(
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: value,
      coercionEnabled: coercionEnabled,
    );
  }

  @override
  Map<String, dynamic> toOpenApiSchema() {
    if (operations.any((op) => op is IsTrueCheck)) {
      return {
        'type': 'boolean',
        'enum': [true],
      };
    } else if (operations.any((op) => op is IsFalseCheck)) {
      return {
        'type': 'boolean',
        'enum': [false],
      };
    }
    return {'type': 'boolean'};
  }

  @override
  bool mock([int? seed]) {
    final random = Random(seed);
    return random.nextBool();
  }
}

/// Create a boolean validator
AcanthisBoolean boolean() => AcanthisBoolean();
