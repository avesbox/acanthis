import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';

/// AcanthisLiteral is a class that represents a literal value.
class AcanthisLiteral<T> extends AcanthisType<T> {
  /// The literal value.
  final T value;

  /// Creates a new instance of [AcanthisLiteral].
  AcanthisLiteral(this.value, {super.defaultValue});

  @override
  Map<String, dynamic> toJsonSchema() {
    return {'type': 'literal', 'value': value};
  }

  @override
  T parseInternal(dynamic value) {
    final typedValue = coerceInput(value);
    if (typedValue == this.value) {
      return typedValue;
    }
    throw ValidationError('Value does not match literal');
  }

  @override
  T tryParseInternal(dynamic value, {required Map<String, dynamic> errors}) {
    final typedValue = super.tryParseInternal(value, errors: errors);
    if (errors.isNotEmpty) {
      return typedValue;
    }
    if (typedValue == this.value) {
      return typedValue;
    }
    errors['literal'] = 'Value does not match literal';
    return defaultValue ?? typedValue;
  }

  @override
  AcanthisParseResult<T> parse(dynamic value) {
    return super.parse(value);
  }

  @override
  Future<AcanthisParseResult<T>> parseAsync(dynamic value) async {
    return super.parseAsync(value);
  }

  @override
  AcanthisParseResult<T> tryParse(dynamic value) {
    return super.tryParse(value);
  }

  @override
  Future<AcanthisParseResult<T>> tryParseAsync(dynamic value) async {
    return super.tryParseAsync(value);
  }

  @override
  AcanthisType<T> meta(MetadataEntry<T> metadata) {
    throw UnimplementedError();
  }

  @override
  AcanthisType<T> withAsyncCheck(AcanthisAsyncCheck<T> check) {
    throw UnimplementedError();
  }

  @override
  AcanthisType<T> withCheck(AcanthisCheck<T> check) {
    throw UnimplementedError();
  }

  @override
  AcanthisType<T> withTransformation(AcanthisTransformation<T> transformation) {
    throw UnimplementedError();
  }

  @override
  AcanthisType<T> withDefault(T value) {
    return AcanthisLiteral(value, defaultValue: value);
  }

  @override
  Map<String, dynamic> toOpenApiSchema() {
    return {
      'type': 'literal',
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
