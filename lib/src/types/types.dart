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

  final MetadataEntry<O>? metadataEntry;

  final O? defaultValue;

  late final O Function(dynamic) compiledParseInternal;
  late final O Function(dynamic, Map<String, dynamic>)
  compiledTryParseInternal;

  /// The constructor of the class
  AcanthisType({
    List<AcanthisOperation<O>> operations = const [],
    this.isAsync = false,
    this.key = '',
    this.metadataEntry,
    this.defaultValue,
  }) : __operations = operations,
       compiledParseInternal = _compileParseOperations<O>(operations),
       compiledTryParseInternal = _compileTryParseOperations<O>(
         operations,
         defaultValue,
       );

  static O Function(dynamic) _compileParseOperations<O>(
    List<AcanthisOperation<O>> operations,
  ) {
    O Function(O) compiled = (value) => value;
    for (final operation in operations) {
      switch (operation) {
        case CustomCauseCheck<O>():
          final previous = compiled;
          final current = operation;
          compiled = (value) {
            final newValue = previous(value);
            final cause = current.cause(newValue);
            if (cause != null) {
              throw ValidationError(cause, key: current.name);
            }
            return newValue;
          };
          break;
        case AcanthisCheck<O>():
          final previous = compiled;
          final current = operation;
          compiled = (value) {
            final newValue = previous(value);
            if (!current(newValue)) {
              throw ValidationError(current.error, key: current.name);
            }
            return newValue;
          };
          break;
        case AcanthisTransformation<O>():
          final previous = compiled;
          final current = operation;
          compiled = (value) => current(previous(value));
          break;
        default:
          break;
      }
    }
    return (value) => compiled(value as O);
  }

  static O Function(dynamic, Map<String, dynamic>) _compileTryParseOperations<O>(
    List<AcanthisOperation<O>> operations,
    O? defaultValue,
  ) {
    O Function(O, Map<String, dynamic>) compiled = (value, _) => value;
    for (final operation in operations) {
      switch (operation) {
        case CustomCauseCheck<O>():
          final previous = compiled;
          final current = operation;
          compiled = (value, errors) {
            final newValue = previous(value, errors);
            final cause = current.cause(newValue);
            if (cause != null) {
              errors[current.name] = cause;
            }
            return newValue;
          };
          break;
        case AcanthisCheck<O>():
          final previous = compiled;
          final current = operation;
          compiled = (value, errors) {
            final newValue = previous(value, errors);
            if (!current(newValue)) {
              errors[current.name] = current.error;
            }
            return newValue;
          };
          break;
        case AcanthisTransformation<O>():
          final previous = compiled;
          final current = operation;
          compiled = (value, errors) => current(previous(value, errors));
          break;
        default:
          break;
      }
    }
    return (value, errors) {
      final typedValue = value as O;
      final initialErrorsLength = errors.length;
      final newValue = compiled(typedValue, errors);
      final hasLocalErrors = errors.length != initialErrorsLength;
      return hasLocalErrors ? (defaultValue ?? newValue) : newValue;
    };
  }

  bool get isPure => operations.whereType<AcanthisTransformation>().isEmpty;

  O parseInternal(dynamic value) {
    return compiledParseInternal(value);
  }

  /// The parse method to parse the value
  /// it returns a [AcanthisParseResult] with the parsed value and throws a [ValidationError] if the value is not valid
  AcanthisParseResult<O> parse(O value) {
    if (isAsync) {
      throw AsyncValidationException(
        'Cannot use tryParse with async operations',
      );
    }
    return AcanthisParseResult<O>(value: parseInternal(value), metadata: metadataEntry);
  }

  O tryParseInternal(dynamic value, {required Map<String, dynamic> errors}) {
    return compiledTryParseInternal(value, errors);
  }

  O mock([int? seed]);

  /// The tryParse method to try to parse the value
  /// it returns a [AcanthisParseResult]
  /// that has the following properties:
  /// - success: A boolean that indicates if the parsing was successful or not.
  /// - value: The value of the parsing. If the parsing was successful, this will contain the parsed value.
  /// - errors: The errors of the parsing. If the parsing was unsuccessful, this will contain the errors of the parsing.
  AcanthisParseResult<O> tryParse(O value) {
    if (isAsync) {
      throw AsyncValidationException(
        'Cannot use tryParse with async operations',
      );
    }
    final errors = <String, dynamic>{};
    final newValue = tryParseInternal(value, errors: errors);
    final success = errors.isEmpty;
    return AcanthisParseResult(
      value: success ? newValue : defaultValue ?? newValue,
      errors: errors,
      success: success,
      metadata: metadataEntry,
    );
  }

  /// The parseAsync method to parse the value that uses [AcanthisAsyncCheck]
  /// it returns a [AcanthisParseResult] with the parsed value and throws a [ValidationError] if the value is not valid
  Future<AcanthisParseResult<O>> parseAsync(O value) async {
    if (operations.isEmpty) {
      return AcanthisParseResult(
        value: value,
        errors: {},
        success: true,
        metadata: metadataEntry,
      );
    }
    O newValue = value;
    for (var operation in operations) {
      switch (operation) {
        case AcanthisCheck<O>():
          if (operation is CustomCauseCheck<O>) {
            final cause = operation.cause(newValue);
            if (cause != null) {
              throw ValidationError(cause, key: operation.name);
            }
            break;
          }
          if (!operation(newValue)) {
            throw ValidationError(operation.error, key: operation.name);
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
    return AcanthisParseResult<O>(value: newValue, metadata: metadataEntry);
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
        metadata: metadataEntry,
      );
    }
    O newValue = value;
    for (var operation in operations) {
      switch (operation) {
        case AcanthisCheck<O>():
          if (operation is CustomCauseCheck<O>) {
            final cause = operation.cause(newValue);
            if (cause != null) {
              errors[operation.name] = cause;
            }
            break;
          }
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
    final success = errors.isEmpty;
    return AcanthisParseResult(
      value: success ? newValue : defaultValue ?? newValue,
      errors: errors,
      success: errors.isEmpty,
      metadata: metadataEntry,
    );
  }

  /// Add a check to the type
  AcanthisType<O> withCheck(AcanthisCheck<O> check);

  /// Add an async check to the type
  AcanthisType<O> withAsyncCheck(AcanthisAsyncCheck<O> check);

  /// Make the type nullable
  AcanthisNullable nullable({O? defaultValue}) {
    return AcanthisNullable(this, defaultValue: defaultValue);
  }

  AcanthisType<O> withDefault(O value);

  /// Make the type a list of the type
  AcanthisList<O> list() {
    return AcanthisList<O>(this);
  }

  /// Make the type a tuple
  AcanthisTuple and(List<AcanthisType> elements) {
    return AcanthisTuple([this, ...elements]);
  }

  /// Make the type a union
  AcanthisUnion<T> or<T>(List<dynamic> elements) {
    return AcanthisUnion<T>([this, ...elements]);
  }

  /// Add a custom check to the number
  AcanthisType<O> refine({
    required bool Function(O value) onCheck,
    required String error,
    required String name,
  }) {
    return withCheck(CustomCheck<O>(onCheck, error: error, name: name));
  }

  /// Add a custom async check to the number
  AcanthisType<O> refineAsync({
    required Future<bool> Function(O value) onCheck,
    required String error,
    required String name,
  }) {
    return withAsyncCheck(
      CustomAsyncCheck<O>(onCheck, error: error, name: name),
    );
  }

  /// Add a pipe transformation to the type to transform the value to another type
  AcanthisPipeline<O, T> pipe<T>(
    AcanthisType<T> type, {
    required T Function(O value) transform,
    T? defaultValue,
  }) {
    return AcanthisPipeline(
      inType: this,
      outType: type,
      transform: transform,
      defaultValue: defaultValue,
    );
  }

  /// Add a transformation to the type
  AcanthisType<O> withTransformation(AcanthisTransformation<O> transformation);

  /// Add a typed transformation to the type. It does not transform the value if the type is not the same
  AcanthisType<O> transform(O Function(O value) transformation) {
    return withTransformation(
      AcanthisTransformation<O>(transformation: transformation),
    );
  }

  /// Convert the type to a JSON schema
  Map<String, dynamic> toJsonSchema();

  /// Add a metadata to the type
  AcanthisType<O> meta(MetadataEntry<O> metadata);

  /// Convert the type to a JSON schema and format it with [indent] spaces
  String toPrettyJsonSchema({int indent = 2}) {
    final encoder = JsonEncoder.withIndent(' ' * indent);
    return encoder.convert(toJsonSchema());
  }

  Map<String, dynamic> toOpenApiSchema();

  static AcanthisNumber number() => AcanthisNumber();

  static AcanthisInt integer() => AcanthisInt();

  static AcanthisDouble doubleType() => AcanthisDouble();

  static AcanthisString string() => AcanthisString();

  static AcanthisBoolean boolean() => AcanthisBoolean();

  static AcanthisDate date() => AcanthisDate();

  static AcanthisMap<dynamic> object(
    Map<String, AcanthisType<dynamic>> value,
  ) => AcanthisMap<dynamic>(value);

  static AcanthisLiteral<T> literal<T>(T value) => AcanthisLiteral<T>(value);

  static AcanthisTemplate template(List<dynamic> parts) =>
      AcanthisTemplate(parts);

  static AcanthisUnion<T> union<T>(List<dynamic> elements) =>
      AcanthisUnion<T>(elements);

  static AcanthisTuple tuple(List<AcanthisType> elements) =>
      AcanthisTuple(elements);

  static InstanceType<T> instance<T>() => InstanceType<T>();

  static ClassSchemaBuilder<I, T> classSchema<I, T>() =>
      ClassSchemaBuilder<I, T>();
}

@immutable
/// A class to represent a pipeline of transformations
class AcanthisPipeline<O, T> extends AcanthisType<T?> {
  /// The type of the input value
  final AcanthisType<O> inType;

  /// The type of the output value
  final AcanthisType<T> outType;

  /// The function that will be used to transform the value
  final T Function(O value) transformFn;

  /// The constructor of the class
  AcanthisPipeline({
    required this.inType,
    required this.outType,
    required T Function(O value) transform,
    super.defaultValue,
  }) : transformFn = transform;

  @override
  AcanthisParseResult<T?> parse(dynamic value) {
    var inResult = inType.parse(value);
    final T newValue;
    try {
      newValue = transformFn(inResult.value);
    } catch (e) {
      throw ValidationError('Error transforming the value from $O -> $T: $e');
    }
    var outResult = outType.parse(newValue);
    return outResult;
  }

  @override
  AcanthisParseResult<T?> tryParse(dynamic value) {
    var inResult = inType.tryParse(value);
    if (!inResult.success) {
      return AcanthisParseResult(
        value: defaultValue,
        errors: inResult.errors,
        success: false,
      );
    }
    final T newValue;
    try {
      newValue = transformFn(inResult.value);
    } catch (e) {
      return AcanthisParseResult(
        value: defaultValue,
        errors: {'transform': 'Error transforming the value from $O -> $T'},
        success: false,
      );
    }
    var outResult = outType.tryParse(newValue);
    return outResult;
  }

  @override
  Future<AcanthisParseResult<T?>> parseAsync(dynamic value) async {
    final inResult = await inType.parseAsync(value);
    final T newValue;
    try {
      newValue = transformFn(inResult.value);
    } catch (e) {
      throw ValidationError('Error transforming the value from $O -> $T: $e');
    }
    final outResult = await outType.parseAsync(newValue);
    return outResult;
  }

  @override
  Future<AcanthisParseResult<T?>> tryParseAsync(dynamic value) async {
    var inResult = await inType.tryParseAsync(value);
    if (!inResult.success) {
      return AcanthisParseResult(
        value: defaultValue,
        errors: inResult.errors,
        success: false,
      );
    }
    final T newValue;
    try {
      newValue = transformFn(inResult.value);
    } catch (e) {
      return AcanthisParseResult(
        value: defaultValue,
        errors: {'transform': 'Error transforming the value from $O -> $T'},
        success: false,
      );
    }
    var outResult = await outType.tryParseAsync(newValue);
    return outResult;
  }

  @override
  AcanthisType<T?> meta(MetadataEntry<T?> metadata) {
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    throw UnimplementedError();
  }

  @override
  Map<String, dynamic> toOpenApiSchema() {
    throw UnimplementedError();
  }

  @override
  AcanthisType<T?> withAsyncCheck(AcanthisAsyncCheck<T?> check) {
    throw UnimplementedError();
  }

  @override
  AcanthisType<T?> withCheck(AcanthisCheck<T?> check) {
    throw UnimplementedError();
  }

  @override
  AcanthisType<T?> withTransformation(
    AcanthisTransformation<T?> transformation,
  ) {
    throw UnimplementedError();
  }

  @override
  AcanthisType<T?> withDefault(T? value) {
    return AcanthisPipeline<O, T?>(
      inType: inType,
      outType: outType,
      transform: transformFn,
      defaultValue: value,
    );
  }
  
  @override
  T? mock([int? seed]) {
    final inResult = inType.mock(seed);
    final T newValue = transformFn(inResult);
    return newValue;
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
  const AcanthisParseResult({
    required this.value,
    this.errors = const {},
    this.success = true,
    this.metadata,
  });

  @override
  String toString() {
    return 'AcanthisParseResult<$O>{value: $value, errors: $errors, success: $success}';
  }
}
