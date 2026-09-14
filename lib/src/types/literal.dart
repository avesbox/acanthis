import 'package:acanthis/src/issue_sink.dart';
import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';

/// AcanthisLiteral is a class that represents a literal value.
class AcanthisLiteral<T> extends AcanthisType<T> {
  /// The literal value.
  final T value;

  /// Creates a new instance of [AcanthisLiteral].
  AcanthisLiteral(
    this.value, {
    super.operations,
    super.isAsync,
    super.key,
    super.metadataEntry,
    super.defaultValue,
  });

  @override
  Map<String, dynamic> toJsonSchema() {
    return {'const': value};
  }

  @override
  T parseInternal(dynamic value) {
    value ??= defaultValue;
    final typedValue = coerceInput(value);
    if (typedValue == this.value) {
      return typedValue;
    }
    throw ValidationError('Value does not match literal');
  }

  @override
  T tryParseInternal(dynamic value, {required Map<String, dynamic> errors}) {
    value ??= defaultValue;
    final typedValue = super.tryParseInternal(value, errors: errors);
    if (errors.isNotEmpty) {
      return typedValue;
    }
    if (typedValue == this.value) {
      return typedValue;
    }
    errors.addIssue(
      'literal',
      'Value does not match literal',
      parameters: {'expected': this.value},
    );
    return defaultValue ?? typedValue;
  }

  @override
  Future<AcanthisParseResult<T>> parseAsync(dynamic value) async {
    value ??= defaultValue;
    if (!isAsync) return parse(value);
    final typedValue = coerceInput(value);
    if (typedValue != this.value) {
      throw ValidationError('Value does not match literal');
    }
    return super.parseAsync(typedValue);
  }

  @override
  Future<AcanthisParseResult<T>> tryParseAsync(dynamic value) async {
    value ??= defaultValue;
    if (!isAsync) return tryParse(value);
    final result = await super.tryParseAsyncOperations(value);
    if (!result.success || result.value == this.value) return result;
    return AcanthisParseResult(
      value: defaultValue ?? result.value,
      errors: IssueSink.single(
        'literal',
        'Value does not match literal',
        parameters: {'expected': this.value},
      ),
      success: false,
      metadata: metadataEntry,
    );
  }

  @override
  AcanthisLiteral<T> meta(MetadataEntry<T> metadata) {
    return AcanthisLiteral(
      value,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadata,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisLiteral<T> withAsyncCheck(AcanthisAsyncCheck<T> check) {
    return AcanthisLiteral(
      value,
      operations: [...operations, check],
      isAsync: true,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisLiteral<T> withCheck(AcanthisCheck<T> check) {
    return AcanthisLiteral(
      value,
      operations: [...operations, check],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisLiteral<T> withTransformation(
    AcanthisTransformation<T> transformation,
  ) {
    return AcanthisLiteral(
      value,
      operations: [...operations, transformation],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisType<T> withDefault(T value) {
    return AcanthisLiteral(
      this.value,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: value,
    );
  }

  @override
  Map<String, dynamic> toOpenApiSchema() {
    return {
      'type': switch (value) {
        String() => 'string',
        bool() => 'boolean',
        int() => 'integer',
        num() => 'number',
        _ => 'string',
      },
      'enum': [value],
    };
  }

  @override
  T mock([int? seed]) {
    return value;
  }
}

/// Creates a new instance of [AcanthisLiteral].
AcanthisLiteral<T> literal<T>(T value) => AcanthisLiteral<T>(value);
