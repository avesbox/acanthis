import 'dart:collection';
import 'dart:convert';

import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/operation.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:meta/meta.dart';

/// A class to validate types
@immutable
abstract class AcanthisType<O> {
  /// The operations that the type should perform
  UnmodifiableListView<AcanthisOperation<O>> get operations =>
      UnmodifiableListView(__operations);

  final List<AcanthisOperation<O>> __operations;

  Type get elementType => O;

  /// A boolean that indicates if the type is async or not
  final bool isAsync;

  /// A string that indicates the key of the type
  final String key;

  /// The constructor of the class
  const AcanthisType(
      {List<AcanthisOperation<O>> operations = const [],
      this.isAsync = false,
      this.key = ''})
      : __operations = operations;

  /// The parse method to parse the value
  /// it returns a [AcanthisParseResult] with the parsed value and throws a [ValidationError] if the value is not valid
  AcanthisParseResult<O> parse(O value) {
    if (isAsync) {
      throw AsyncValidationException(
          'Cannot use tryParse with async operations');
    }
    if (operations.isEmpty) {
      return AcanthisParseResult(
          value: value,
          errors: {},
          success: true,
          metadata: MetadataRegistry().get(key));
    }
    O newValue = value;
    for (var operation in operations) {
      switch (operation) {
        case AcanthisCheck<O>():
          if (!operation(newValue)) {
            throw ValidationError(operation.error);
          }
          break;
        case AcanthisTransformation<O>():
          newValue = operation(newValue);
          break;
        default:
          break;
      }
    }
    return AcanthisParseResult(
        value: newValue, metadata: MetadataRegistry().get(key));
  }

  /// The tryParse method to try to parse the value
  /// it returns a [AcanthisParseResult]
  /// that has the following properties:
  /// - success: A boolean that indicates if the parsing was successful or not.
  /// - value: The value of the parsing. If the parsing was successful, this will contain the parsed value.
  /// - errors: The errors of the parsing. If the parsing was unsuccessful, this will contain the errors of the parsing.
  AcanthisParseResult<O> tryParse(O value) {
    if (isAsync) {
      throw AsyncValidationException(
          'Cannot use tryParse with async operations');
    }
    final errors = <String, String>{};
    if (operations.isEmpty) {
      return AcanthisParseResult(
          value: value,
          errors: errors,
          success: true,
          metadata: MetadataRegistry().get(key));
    }
    O newValue = value;
    for (final operation in operations) {
      switch (operation) {
        case AcanthisCheck<O>():
          if (!operation(newValue)) {
            errors[operation.name] = operation.error;
          }
          break;
        case AcanthisTransformation<O>():
          newValue = operation(newValue);
          break;
        default:
          break;
      }
    }
    return AcanthisParseResult(
        value: newValue,
        errors: errors,
        success: errors.isEmpty,
        metadata: MetadataRegistry().get(key));
  }

  /// The parseAsync method to parse the value that uses [AcanthisAsyncCheck]
  /// it returns a [AcanthisParseResult] with the parsed value and throws a [ValidationError] if the value is not valid
  Future<AcanthisParseResult<O>> parseAsync(O value) async {
    if (operations.isEmpty) {
      return AcanthisParseResult(
          value: value,
          errors: {},
          success: true,
          metadata: MetadataRegistry().get(key));
    }
    O newValue = value;
    for (var operation in operations) {
      switch (operation) {
        case AcanthisCheck<O>():
          if (!operation(newValue)) {
            throw ValidationError(operation.error);
          }
          break;
        case AcanthisAsyncCheck<O>():
          if (!await operation(newValue)) {
            throw ValidationError(operation.error);
          }
          break;
        case AcanthisTransformation<O>():
          newValue = operation(newValue);
          break;
        default:
          break;
      }
    }
    return AcanthisParseResult<O>(
        value: newValue, metadata: MetadataRegistry().get(key));
  }

  /// The tryParseAsync method to try to parse the value that uses [AcanthisAsyncCheck]
  /// it returns a [AcanthisParseResult]
  /// that has the following properties:
  /// - success: A boolean that indicates if the parsing was successful or not.
  /// - value: The value of the parsing. If the parsing was successful, this will contain the parsed value.
  /// - errors: The errors of the parsing. If the parsing was unsuccessful, this will contain the errors of the parsing.
  Future<AcanthisParseResult<O>> tryParseAsync(O value) async {
    final errors = <String, String>{};
    if (operations.isEmpty) {
      return AcanthisParseResult(
          value: value,
          errors: errors,
          success: true,
          metadata: MetadataRegistry().get(key));
    }
    O newValue = value;
    for (var operation in operations) {
      switch (operation) {
        case AcanthisCheck<O>():
          if (!operation(newValue)) {
            errors[operation.name] = operation.error;
          }
          break;
        case AcanthisAsyncCheck<O>():
          if (!await operation(newValue)) {
            errors[operation.name] = operation.error;
          }
          break;
        case AcanthisTransformation<O>():
          newValue = operation(newValue);
          break;
        default:
          break;
      }
    }
    return AcanthisParseResult(
        value: newValue,
        errors: errors,
        success: errors.isEmpty,
        metadata: MetadataRegistry().get(key));
  }

  /// Add a check to the type
  AcanthisType<O> withCheck(AcanthisCheck<O> check);

  /// Add an async check to the type
  AcanthisType<O> withAsyncCheck(AcanthisAsyncCheck<O> check);

  /// Make the type nullable
  AcanthisNullable nullable({O? defaultValue}) {
    return AcanthisNullable(this, defaultValue: defaultValue);
  }

  /// Make the type a list of the type
  AcanthisList<O> list() {
    return AcanthisList<O>(this);
  }

  /// Make the type a tuple
  AcanthisTuple and(List<AcanthisType> elements) {
    return AcanthisTuple([this, ...elements]);
  }

  /// Make the type a union
  AcanthisUnion or(List<AcanthisType> elements) {
    return AcanthisUnion([this, ...elements]);
  }

  /// Add a custom check to the number
  AcanthisType<O> refine(
      {required bool Function(O value) onCheck,
      required String error,
      required String name}) {
    return withCheck(CustomCheck<O>(onCheck, error: error, name: name));
  }

  /// Add a custom async check to the number
  AcanthisType<O> refineAsync(
      {required Future<bool> Function(O value) onCheck,
      required String error,
      required String name}) {
    return withAsyncCheck(
        CustomAsyncCheck<O>(onCheck, error: error, name: name));
  }

  /// Add a pipe transformation to the type to transform the value to another type
  AcanthisPipeline<O, T> pipe<T>(
    AcanthisType<T> type, {
    required T Function(O value) transform,
  }) {
    return AcanthisPipeline(inType: this, outType: type, transform: transform);
  }

  /// Add a transformation to the type
  AcanthisType<O> withTransformation(AcanthisTransformation<O> transformation);

  /// Add a typed transformation to the type. It does not transform the value if the type is not the same
  AcanthisType<O> transform(O Function(O value) transformation) {
    return withTransformation(
        AcanthisTransformation<O>(transformation: transformation));
  }

  /// Convert the type to a JSON schema
  Map<String, dynamic> toJsonSchema();

  /// Add a metadata to the type
  AcanthisType<O> meta(MetadataEntry<O> metadata);

  /// Convert the type to a JSON schema and format it with [indent] spaces
  String toPrettyJsonSchema({int indent = 2}) {
    final encoder = JsonEncoder.withIndent(' ' * indent);
    final json = toJsonSchema();
    return encoder.convert(json);
  }
}

@immutable

/// A class to represent a pipeline of transformations
class AcanthisPipeline<O, T> {
  /// The type of the input value
  final AcanthisType<O> inType;

  /// The type of the output value
  final AcanthisType<T> outType;

  /// The function that will be used to transform the value
  final T Function(O value) transform;

  /// The constructor of the class
  const AcanthisPipeline(
      {required this.inType, required this.outType, required this.transform});

  /// The parse method to parse the value
  AcanthisParseResult parse(O value) {
    var inResult = inType.parse(value);
    final T newValue;
    try {
      newValue = transform(inResult.value);
    } catch (e) {
      return AcanthisParseResult(
          value: inResult.value,
          errors: {'transform': 'Error transforming the value from $O -> $T'},
          success: false);
    }
    var outResult = outType.parse(newValue);
    return outResult;
  }

  /// The tryParse method to try to parse the value
  AcanthisParseResult tryParse(O value) {
    var inResult = inType.tryParse(value);
    if (!inResult.success) {
      return inResult;
    }
    final T newValue;
    try {
      newValue = transform(inResult.value);
    } catch (e) {
      return AcanthisParseResult(
          value: inResult.value,
          errors: {'transform': 'Error transforming the value from $O -> $T'},
          success: false);
    }
    var outResult = outType.tryParse(newValue);
    return outResult;
  }

  /// The parseAsync method to parse the value that uses [AcanthisAsyncCheck]
  Future<AcanthisParseResult> parseAsync(O value) async {
    final inResult = await inType.parseAsync(value);
    final T newValue;
    try {
      newValue = transform(inResult.value);
    } catch (e) {
      return AcanthisParseResult(
          value: inResult.value,
          errors: {'transform': 'Error transforming the value from $O -> $T'},
          success: false);
    }
    final outResult = await outType.parseAsync(newValue);
    return outResult;
  }

  /// The tryParseAsync method to try to parse the value that uses [AcanthisAsyncCheck]
  Future<AcanthisParseResult> tryParseAsync(O value) async {
    var inResult = await inType.tryParseAsync(value);
    if (!inResult.success) {
      return inResult;
    }
    final T newValue;
    try {
      newValue = transform(inResult.value);
    } catch (e) {
      return AcanthisParseResult(
          value: inResult.value,
          errors: {'transform': 'Error transforming the value from $O -> $T'},
          success: false);
    }
    var outResult = await outType.tryParseAsync(newValue);
    return outResult;
  }
}

/// A class to represent the result of a parse operation
@immutable
class AcanthisParseResult<O> {
  /// The value of the parsing
  final O value;

  /// The errors of the parsing
  final Map<String, dynamic> errors;

  /// A boolean that indicates if the parsing was successful or not
  final bool success;

  /// The metadata of the type
  final MetadataEntry<O>? metadata;

  /// The constructor of the class
  const AcanthisParseResult(
      {required this.value,
      this.errors = const {},
      this.success = true,
      this.metadata});

  @override
  String toString() {
    return 'AcanthisParseResult<$O>{value: $value, errors: $errors, success: $success}';
  }
}
