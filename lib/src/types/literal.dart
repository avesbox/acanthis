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
  AcanthisParseResult<T> parse(T value) {
    if (value == this.value) {
      return AcanthisParseResult(value: value, success: true);
    }
    throw ValidationError('Value does not match literal');
  }

  @override
  Future<AcanthisParseResult<T>> parseAsync(T value) async {
    if (value == this.value) {
      return AcanthisParseResult(value: value, success: true);
    }
    throw ValidationError('Value does not match literal');
  }

  @override
  AcanthisParseResult<T> tryParse(T value) {
    if (value == this.value) {
      return AcanthisParseResult(value: value, success: true);
    }
    return AcanthisParseResult(value: value, success: false);
  }

  @override
  Future<AcanthisParseResult<T>> tryParseAsync(T value) async {
    if (value == this.value) {
      return AcanthisParseResult(value: value, success: true);
    }
    return AcanthisParseResult(value: value, success: false);
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
