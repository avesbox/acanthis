import 'dart:math';

import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/validators/nullable.dart';
import 'package:nanoid2/nanoid2.dart';

/// A class to validate nullable types
class AcanthisNullable<T> extends AcanthisType<T?> {
  /// The element of the nullable
  final AcanthisType<T> element;

  AcanthisNullable(
    this.element, {
    super.defaultValue,
    super.operations,
    super.isAsync,
    super.key,
    super.metadataEntry,
  });

  /// override of the [parse] method from [AcanthisType]
  @override
  AcanthisParseResult<T?> parse(T? value) {
    if (isAsync) {
      throw ValidationError('Cannot use parse on async type');
    }
    if (value == null) {
      return AcanthisParseResult(value: defaultValue);
    }
    final elementResult = element.parse(value);
    return super.parse(elementResult.value);
  }

  /// override of the [tryParse] method from [AcanthisType]
  @override
  AcanthisParseResult<T?> tryParse(T? value) {
    if (isAsync) {
      throw ValidationError('Cannot use tryParse on async type');
    }
    if (value == null) {
      return AcanthisParseResult(value: defaultValue);
    }
    final elementResult = element.tryParse(value);
    final result = super.tryParse(elementResult.value);
    return AcanthisParseResult(
      value: result.value,
      errors: {...result.errors, ...elementResult.errors},
      success: result.success && elementResult.success,
      metadata: result.metadata,
    );
  }

  @override
  Future<AcanthisParseResult<T?>> parseAsync(T? value) async {
    if (value == null) {
      return AcanthisParseResult(value: defaultValue);
    }
    final elementResult = await element.parseAsync(value);
    return await super.parseAsync(elementResult.value);
  }

  @override
  Future<AcanthisParseResult<T?>> tryParseAsync(T? value) async {
    if (value == null) {
      return AcanthisParseResult(value: defaultValue);
    }
    final elementResult = await element.tryParseAsync(value);
    final result = await super.tryParseAsync(elementResult.value);
    return AcanthisParseResult(
      value: result.value,
      errors: {...result.errors, ...elementResult.errors},
      success: result.success && elementResult.success,
      metadata: result.metadata,
    );
  }

  @override
  AcanthisNullable nullable({T? defaultValue}) {
    return this;
  }

  @override
  AcanthisNullable<T> withAsyncCheck(AcanthisAsyncCheck<T?> check) {
    return AcanthisNullable(
      element,
      defaultValue: defaultValue,
      operations: [...operations, check],
      isAsync: true,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  @override
  AcanthisNullable<T> withCheck(AcanthisCheck<T?> check) {
    return AcanthisNullable(
      element,
      defaultValue: defaultValue,
      operations: [...operations, check],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  @override
  AcanthisNullable<T> withTransformation(
    AcanthisTransformation<T?> transformation,
  ) {
    return AcanthisNullable(
      element,
      defaultValue: defaultValue,
      operations: [...operations, transformation],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  /// Check if the value is part of the enumerated values
  AcanthisNullable<T> enumerated(
    List<T?> values, {
    String? message,
    String Function(List<T?> value)? messageBuilder,
  }) {
    final enumeratedValue = {...values, null};
    return withCheck(
      EnumeratedNullableCheck(
        enumeratedValue.toList(),
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    final enumerated = operations
        .whereType<EnumeratedNullableCheck>()
        .firstOrNull;
    if (enumerated != null) {
      final values = {...enumerated.values, defaultValue, null};
      return {
        'enum': values.toList(),
        if (metadataEntry != null) ...metadataEntry!.toJson(),
      };
    }
    return {
      'oneOf': [
        {
          ...element.toJsonSchema(),
          if (defaultValue != null) 'default': defaultValue,
        },
        {'type': 'null'},
      ],
      if (metadataEntry != null) ...metadataEntry!.toJson(),
    };
  }

  @override
  AcanthisType<T?> meta(MetadataEntry<T?> metadata) {
    String key = this.key;
    if (key.isEmpty) {
      key = nanoid();
    }
    MetadataRegistry().add(key, metadata);
    return AcanthisNullable(
      element,
      defaultValue: defaultValue,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadata,
    );
  }

  @override
  AcanthisType<T?> withDefault(T? value) {
    return AcanthisNullable(
      element,
      defaultValue: value,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  @override
  Map<String, dynamic> toOpenApiSchema() {
    return {
      ...element.toOpenApiSchema(),
      'nullable': true,
      if (defaultValue != null) 'default': defaultValue,
    };
  }
  
  @override
  T? mock([int? seed]) {
    final random = Random(seed);
    return random.nextBool() ? null : element.mock(seed);
  }
}
