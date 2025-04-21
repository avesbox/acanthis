import 'dart:convert';

import 'package:acanthis/acanthis.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';

/// A class to validate types
@immutable
abstract class AcanthisType<O> {
  /// The operations that the type should perform
  final IList<AcanthisOperation> operations;

  final bool isAsync;

  final String key;

  /// The constructor of the class
  const AcanthisType(
      {this.operations = const IList.empty(),
      this.isAsync = false,
      this.key = ''});

  /// The parse method to parse the value
  /// it returns a [AcanthisParseResult] with the parsed value and throws a [ValidationError] if the value is not valid
  AcanthisParseResult<O> parse(O value) {
    if (isAsync) {
      throw AsyncValidationException(
          'Cannot use tryParse with async operations');
    }
    O newValue = value;
    for (var operation in operations) {
      if (operation is AcanthisCheck) {
        if (!operation(newValue)) {
          throw ValidationError(operation.error);
        }
      }
      if (operation is AcanthisTransformation) {
        newValue = operation(newValue);
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
    O newValue = value;
    for (var operation in operations) {
      if (operation is AcanthisCheck) {
        if (!operation(newValue)) {
          errors[operation.name] = operation.error;
        }
      }
      if (operation is AcanthisTransformation) {
        newValue = operation(newValue);
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
    O newValue = value;
    for (var operation in operations) {
      if (operation is AcanthisCheck) {
        if (!operation(newValue)) {
          throw ValidationError(operation.error);
        }
      }
      if (operation is AcanthisAsyncCheck) {
        if (!await operation(newValue)) {
          throw ValidationError(operation.error);
        }
      }
      if (operation is AcanthisTransformation) {
        newValue = operation(newValue);
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
    O newValue = value;
    for (var operation in operations) {
      if (operation is AcanthisCheck) {
        if (!operation(newValue)) {
          errors[operation.name] = operation.error;
        }
      }
      if (operation is AcanthisAsyncCheck) {
        if (!await operation(newValue)) {
          errors[operation.name] = operation.error;
        }
      }
      if (operation is AcanthisTransformation) {
        newValue = operation(newValue);
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
    return withCheck(
        AcanthisCheck<O>(onCheck: onCheck, error: error, name: name));
  }

  /// Add a custom async check to the number
  AcanthisType<O> refineAsync(
      {required Future<bool> Function(O value) onCheck,
      required String error,
      required String name}) {
    return withAsyncCheck(
        AcanthisAsyncCheck<O>(onCheck: onCheck, error: error, name: name));
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

  Map<String, dynamic> toJsonSchema();

  AcanthisType<O> meta(MetadataEntry<O> metadata);

  String toJsonSchemaString({int indent = 2}) {
    final encoder = JsonEncoder.withIndent(' ' * indent);
    final json = toJsonSchema();
    return encoder.convert(json);
  }
}

/// A class that represents a check operation
@immutable
class AcanthisCheck<O> extends AcanthisOperation<O> {
  /// The function to check the value
  final bool Function(O value) onCheck;

  /// The error message of the check
  final String error;

  /// The name of the check
  final String name;

  /// The constructor of the class
  const AcanthisCheck({this.error = '', this.name = '', required this.onCheck});

  /// The call method to create a Callable class
  @override
  bool call(O value) {
    try {
      return onCheck(value);
    } catch (e) {
      return false;
    }
  }
}

/// A class that represents an async check operation
@immutable
class AcanthisAsyncCheck<O> extends AcanthisOperation<O> {
  /// The function to check the value asynchronously
  final Future<bool> Function(O value) onCheck;

  /// The error message of the check
  final String error;

  /// The name of the check
  final String name;

  /// The constructor of the class
  const AcanthisAsyncCheck(
      {this.error = '', this.name = '', required this.onCheck});

  @override
  Future<bool> call(O value) async {
    try {
      return await onCheck(value);
    } catch (e) {
      return false;
    }
  }
}

/// A class that represents a transformation operation
@immutable
class AcanthisTransformation<O> extends AcanthisOperation<O> {
  /// The transformation function
  final O Function(O value) transformation;

  /// The constructor of the class
  const AcanthisTransformation({required this.transformation});

  /// The call method to create a Callable class
  @override
  O call(O value) {
    return transformation(value);
  }
}

/// A class that represents an operation
@immutable
abstract class AcanthisOperation<O> {
  /// The constructor of the class
  const AcanthisOperation();

  /// The call method to create a Callable class
  dynamic call(O value);
}

@immutable
class AcanthisPipeline<O, T> {
  final AcanthisType<O> inType;

  final AcanthisType<T> outType;

  final T Function(O value) transform;

  const AcanthisPipeline(
      {required this.inType, required this.outType, required this.transform});

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

class ExactCheck<T> extends AcanthisCheck<T> {
  final T value;

  ExactCheck({required this.value})
      : super(
            onCheck: (v) => v == value,
            error: 'Value must be exactly $value',
            name: 'exact');
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
