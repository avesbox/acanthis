import 'package:acanthis/acanthis.dart';
import 'package:nanoid2/nanoid2.dart';

/// A class to validate nullable types
class AcanthisNullable<T> extends AcanthisType<T?> {
  /// The default value of the nullable
  final T? defaultValue;

  /// The element of the nullable
  final AcanthisType<T> element;

  const AcanthisNullable(this.element,
      {this.defaultValue, super.operations, super.isAsync, super.key});

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
    final result = super.parse(elementResult.value);
    return AcanthisParseResult(
      value: result.value,
    );
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
      errors: {
        ...result.errors,
        ...elementResult.errors,
      },
      success: result.success && elementResult.success,
    );
  }

  @override
  Future<AcanthisParseResult<T?>> parseAsync(T? value) async {
    if (value == null) {
      return AcanthisParseResult(value: defaultValue);
    }
    final elementResult = await element.parseAsync(value);
    final result = await super.parseAsync(elementResult.value);
    return AcanthisParseResult(
      value: result.value,
    );
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
      errors: {
        ...result.errors,
        ...elementResult.errors,
      },
      success: result.success && elementResult.success,
    );
  }

  @override
  AcanthisNullable nullable({T? defaultValue}) {
    return this;
  }

  @override
  AcanthisNullable<T> withAsyncCheck(AcanthisAsyncCheck<T?> check) {
    return AcanthisNullable(element,
        defaultValue: defaultValue,
        operations: operations.add(check),
        isAsync: true,
        key: key);
  }

  @override
  AcanthisNullable<T> withCheck(AcanthisCheck<T?> check) {
    return AcanthisNullable(element,
        defaultValue: defaultValue,
        operations: operations.add(check),
        isAsync: isAsync,
        key: key);
  }

  @override
  AcanthisNullable<T> withTransformation(
      AcanthisTransformation<T?> transformation) {
    return AcanthisNullable(element,
        defaultValue: defaultValue,
        operations: operations.add(transformation),
        isAsync: isAsync,
        key: key);
  }

  AcanthisNullable<T> enumerated(List<T?> values) {
    final enumeratedValue = {...values, null};
    return withCheck(EnumeratedWithNullCheck(enumeratedValue.toList()));
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    final metadata = MetadataRegistry().get(key);
    final type = _getType();
    final enumerated =
        operations.whereType<EnumeratedWithNullCheck>().firstOrNull;
    if (enumerated != null) {
      final values = {...enumerated.values, defaultValue, null};
      return {
        'enum': values.toList(),
      };
    }
    return {
      'type': type,
      if (metadata != null) ...metadata.toJson(),
    };
  }

  dynamic _getType() {
    if (element is AcanthisString) {
      return ['string', 'null'];
    } else if (element is AcanthisNumber) {
      return ['number', 'null'];
    } else if (element is AcanthisBoolean) {
      return ['boolean', 'null'];
    } else if (element is AcanthisList) {
      return ['array', 'null'];
    } else if (element is AcanthisMap) {
      return ['object', 'null'];
    } else if (element is AcanthisDate) {
      return ['string', 'null'];
    }
    return 'null';
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
    );
  }
}

class EnumeratedWithNullCheck<T> extends AcanthisCheck<T?> {
  final List<T?> values;

  EnumeratedWithNullCheck(this.values)
      : super(
          onCheck: (toTest) => values.contains(toTest),
          error: 'Value must be one of the following: ${values.join(', ')}',
          name: 'enum',
        );
}
