import 'package:acanthis/src/issue_sink.dart';

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
  final bool _explicitDefault;

  @override
  bool get hasDefault => _explicitDefault || defaultValue != null;

  @override
  bool get isPure => element.isPure && super.isPure;

  @override
  T? parseInternal(dynamic value) {
    value ??= defaultValue;
    if (value == null) {
      return super.parseInternal(null);
    }
    final elementValue = element.parseInternal(value);
    return super.parseInternal(elementValue);
  }

  @override
  T? tryParseInternal(dynamic value, {required Map<String, dynamic> errors}) {
    value ??= defaultValue;
    if (value == null) {
      return super.tryParseInternal(null, errors: errors);
    }
    final initialCount = errors.issueCount;
    final elementValue = element.tryParseInternal(value, errors: errors);
    final parsed = super.tryParseInternal(elementValue, errors: errors);
    return errors.issueCount == initialCount ? parsed : defaultValue ?? parsed;
  }

  AcanthisNullable(
    this.element, {
    T? defaultValue,
    bool hasDefault = false,
    super.operations,
    bool isAsync = false,
    super.key,
    super.metadataEntry,
  }) : _explicitDefault = hasDefault,
       super(
         defaultValue: hasDefault
             ? defaultValue
             : defaultValue ?? element.defaultValue,
         isAsync: isAsync || element.isAsync,
       );

  /// override of the [parse] method from [AcanthisType]
  @override
  AcanthisParseResult<T?> parse(dynamic value) {
    value ??= defaultValue;
    if (isAsync) {
      throw ValidationError('Cannot use parse on async type');
    }
    return AcanthisParseResult(
      value: parseInternal(value),
      metadata: metadataEntry,
    );
  }

  /// override of the [tryParse] method from [AcanthisType]
  @override
  AcanthisParseResult<T?> tryParse(dynamic value) {
    value ??= defaultValue;
    if (isAsync) {
      throw ValidationError('Cannot use tryParse on async type');
    }
    final errors = IssueSink();
    final parsed = tryParseInternal(value, errors: errors);
    return AcanthisParseResult(
      value: errors.isEmpty ? parsed : defaultValue ?? parsed,
      errors: errors,
      success: errors.isEmpty,
      metadata: metadataEntry,
    );
  }

  @override
  Future<AcanthisParseResult<T?>> parseAsync(dynamic value) async {
    value ??= defaultValue;
    if (!isAsync) return parse(value);
    if (value == null) {
      return super.parseAsync(null);
    }
    final elementResult = await element.parseAsync(value);
    return await super.parseAsync(elementResult.value);
  }

  @override
  Future<AcanthisParseResult<T?>> tryParseAsync(dynamic value) async {
    value ??= defaultValue;
    if (!isAsync) return tryParse(value);
    if (value == null) {
      return super.tryParseAsyncOperations(null);
    }
    final elementResult = await element.tryParseAsync(value);
    final result = await super.tryParseAsyncOperations(elementResult.value);
    return AcanthisParseResult(
      value: result.success && elementResult.success
          ? result.value
          : defaultValue ?? result.value,
      errors: IssueSink.of(elementResult.errors)..addAll(result.errors),
      success: result.success && elementResult.success,
      metadata: result.metadata,
    );
  }

  @override
  AcanthisNullable<T> withAsyncCheck(AcanthisAsyncCheck<T?> check) {
    return AcanthisNullable(
      element,
      defaultValue: defaultValue,
      hasDefault: hasDefault,
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
      hasDefault: hasDefault,
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
      hasDefault: hasDefault,
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
      hasDefault: hasDefault,
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
      hasDefault: true,
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
