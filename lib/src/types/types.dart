import 'package:acanthis/src/issue_sink.dart';

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

  /// Internal eligibility check that avoids allocating a public list view.
  @internal
  bool get hasOperations => __operations.isNotEmpty;

  Type get elementType => O;

  /// A boolean that indicates if the type is async or not
  final bool isAsync;

  /// A string that indicates the key of the type
  final String key;

  final MetadataEntry<O>? metadataEntry;

  final O? defaultValue;

  /// Whether omission can be filled by this schema.
  bool get hasDefault => defaultValue != null;

  /// Compiled executors are lazy because fluent schema definitions often
  /// create intermediate instances which are never parsed.
  late final O Function(O) compiledParseInternal = _compileParseOperations<O>(
    __operations,
  );
  late final O Function(O, Map<String, dynamic>) compiledTryParseInternal =
      _compileTryParseOperations<O>(__operations, defaultValue);

  /// The constructor of the class
  AcanthisType({
    List<AcanthisOperation<O>> operations = const [],
    this.isAsync = false,
    this.key = '',
    this.metadataEntry,
    this.defaultValue,
  }) : __operations = operations.isEmpty
           ? const []
           : List.unmodifiable(operations);

  static O Function(O) _compileParseOperations<O>(
    List<AcanthisOperation<O>> operations,
  ) {
    // The common one-check schema needs no preceding identity executor.
    if (operations.length == 1) {
      final operation = operations.single;
      if (operation is AcanthisCheck<O> && operation is! CustomCauseCheck<O>) {
        return (value) {
          if (!operation(value)) {
            throw ValidationError.diagnostic(
              operation.error,
              key: operation.name,
              code: operation.code,
              parameters: operation.parameters,
            );
          }
          return value;
        };
      }
    }
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
              throw ValidationError.diagnostic(
                cause,
                key: current.name,
                code: current.code,
                parameters: current.parameters,
              );
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
              throw ValidationError.diagnostic(
                current.error,
                key: current.name,
                code: current.code,
                parameters: current.parameters,
              );
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
    return compiled;
  }

  static O Function(O, Map<String, dynamic>) _compileTryParseOperations<O>(
    List<AcanthisOperation<O>> operations,
    O? defaultValue,
  ) {
    if (defaultValue == null && operations.length == 1) {
      final operation = operations.single;
      if (operation is AcanthisCheck<O> && operation is! CustomCauseCheck<O>) {
        return (value, errors) {
          if (!operation(value)) {
            errors.addIssue(
              operation.code,
              operation.error,
              parameters: operation.parameters,
            );
          }
          return value;
        };
      }
    }
    O Function(O, Map<String, dynamic>) compiled = (value, _) => value;
    for (final operation in operations) {
      switch (operation) {
        case CustomCauseCheck<O>():
          final previous = compiled;
          final current = operation;
          compiled = (value, errors) {
            final newValue = previous(value, errors);
            if (errors.isNotEmpty &&
                AcanthisValidationScope.current.fieldPolicy ==
                    AcanthisCollectionPolicy.first) {
              return newValue;
            }
            final cause = current.cause(newValue);
            if (cause != null) {
              errors.addIssue(
                current.code,
                cause,
                parameters: current.parameters,
              );
            }
            return newValue;
          };
          break;
        case AcanthisCheck<O>():
          final previous = compiled;
          final current = operation;
          compiled = (value, errors) {
            final newValue = previous(value, errors);
            if (errors.isNotEmpty &&
                AcanthisValidationScope.current.fieldPolicy ==
                    AcanthisCollectionPolicy.first) {
              return newValue;
            }
            if (!current(newValue)) {
              errors.addIssue(
                current.code,
                current.error,
                parameters: current.parameters,
              );
            }
            return newValue;
          };
          break;
        case AcanthisTransformation<O>():
          final previous = compiled;
          final current = operation;
          compiled = (value, errors) {
            final parsed = previous(value, errors);
            if (errors.isNotEmpty &&
                AcanthisValidationScope.current.fieldPolicy ==
                    AcanthisCollectionPolicy.first) {
              return parsed;
            }
            return current(parsed);
          };
          break;
        default:
          break;
      }
    }
    // Without a default, the executor already returns the final value.
    // Avoid a closure call and two error-count reads for every child value.
    if (defaultValue == null) return compiled;
    return (typedValue, errors) {
      final initialErrorsLength = errors.issueCount;
      final newValue = compiled(typedValue, errors);
      final hasLocalErrors = errors.issueCount != initialErrorsLength;
      return hasLocalErrors ? defaultValue : newValue;
    };
  }

  late final bool _isPure =
      __operations.isEmpty ||
      !__operations.any((operation) => operation is AcanthisTransformation<O>);

  bool get isPure => _isPure;

  @protected
  O coerceInput(dynamic value) {
    return value as O;
  }

  @protected
  String get inputErrorKey => 'type';

  @protected
  O valueOnFailure(dynamic value) {
    if (defaultValue != null) {
      return defaultValue as O;
    }
    if (value is O) {
      return value;
    }
    return mock(0);
  }

  String _invalidTypeMessage(dynamic value) {
    return 'Invalid type: ${value.runtimeType}, expected $O';
  }

  O parseInternal(dynamic value) {
    value ??= defaultValue;
    if (__operations.isEmpty) return coerceInput(value);
    return compiledParseInternal(coerceInput(value ?? defaultValue));
  }

  /// Returns null on success or the first [ValidationError.message] on failure.
  ///
  /// Runs synchronous parsing, including coercion and transformations, but
  /// discards the parsed value. Use [parse] to retrieve that value or [tryParse]
  /// to collect structured issues. Non-validation exceptions propagate.
  /// For a Flutter text field, use `(value) => schema.validate(value ?? '')`
  /// to treat a null value as empty input on a non-nullable string schema.
  String? validate(dynamic value, {AcanthisMessageResolver? resolver}) {
    if (isAsync) {
      throw AsyncValidationException(
        'Cannot use validate with async operations',
      );
    }
    try {
      parseInternal(value);
      return null;
    } on ValidationError catch (e) {
      return e.formatMessage(resolver: resolver);
    }
  }

  /// Returns null on success or the first asynchronous validation error message.
  Future<String?> validateAsync(
    dynamic value, {
    AcanthisMessageResolver? resolver,
  }) async {
    try {
      await parseAsync(value);
      return null;
    } on ValidationError catch (error) {
      return error.formatMessage(resolver: resolver);
    }
  }

  /// Returns the parsed value or throws [ValidationError] on failure.
  O parse(dynamic value) {
    value ??= defaultValue;
    if (isAsync) {
      throw AsyncValidationException('Cannot use parse with async operations');
    }
    return parseInternal(value);
  }

  O tryParseInternal(dynamic value, {required Map<String, dynamic> errors}) {
    value ??= defaultValue;
    try {
      if (__operations.isEmpty) return coerceInput(value);
      return compiledTryParseInternal(
        coerceInput(value ?? defaultValue),
        errors,
      );
    } on ValidationError catch (e) {
      errors.addIssue(e.key.isNotEmpty ? e.key : inputErrorKey, e.message);
      return valueOnFailure(value);
    } on TypeError {
      errors.addIssue(inputErrorKey, _invalidTypeMessage(value));
      return valueOnFailure(value);
    }
  }

  O mock([int? seed]);

  /// Returns [AcanthisValid] with the parsed value or [AcanthisInvalid]
  /// with ordered issues and a recovery value. Async schemas require [tryParseAsync].
  AcanthisOutcome<O> tryParse(dynamic value) {
    value ??= defaultValue;
    if (isAsync) {
      throw AsyncValidationException(
        'Cannot use tryParse with async operations',
      );
    }
    final errors = IssueSink();
    final newValue = tryParseInternal(value, errors: errors);
    final success = errors.isEmpty;
    return outcomeFromDiagnostics(
      value: success ? newValue : defaultValue ?? newValue,
      errors: errors,
      metadata: metadataEntry,
    );
  }

  /// Returns the parsed value after awaiting checks, or throws [ValidationError].
  Future<O> parseAsync(dynamic value) async {
    value ??= defaultValue;
    if (!isAsync) {
      return parse(value);
    }
    final typedValue = coerceInput(value ?? defaultValue);
    if (operations.isEmpty) {
      return typedValue;
    }
    O newValue = typedValue;
    for (var operation in operations) {
      switch (operation) {
        case AcanthisCheck<O>():
          if (operation is CustomCauseCheck<O>) {
            final cause = operation.cause(newValue);
            if (cause != null) {
              throw ValidationError.diagnostic(
                cause,
                key: operation.name,
                code: operation.code,
                parameters: operation.parameters,
              );
            }
            break;
          }
          if (!operation(newValue)) {
            throw ValidationError.diagnostic(
              operation.error,
              key: operation.name,
              code: operation.code,
              parameters: operation.parameters,
            );
          }
          break;
        case AcanthisAsyncCheck<O>():
          if (!await operation(newValue)) {
            throw ValidationError.diagnostic(
              operation.error,
              code: operation.code,
              parameters: operation.parameters,
            );
          }
          break;
        case AcanthisTransformation<O>():
          newValue = operation(newValue);
          break;
        default:
          break;
      }
    }
    return newValue;
  }

  /// Returns a typed outcome after awaiting all applicable checks.
  Future<AcanthisOutcome<O>> tryParseAsync(dynamic value) async {
    value ??= defaultValue;
    if (!isAsync) {
      return tryParse(value);
    }
    return tryParseAsyncOperations(value);
  }

  /// Runs only this schema's operations; composition validates children first.
  @protected
  Future<AcanthisOutcome<O>> tryParseAsyncOperations(dynamic value) async {
    final errors = IssueSink();
    try {
      final typedValue = coerceInput(value ?? defaultValue);
      if (operations.isEmpty) {
        return outcomeFromDiagnostics(
          value: typedValue,
          errors: errors,
          metadata: metadataEntry,
        );
      }
      O newValue = typedValue;
      for (var operation in operations) {
        if (errors.isNotEmpty &&
            AcanthisValidationScope.current.fieldPolicy ==
                AcanthisCollectionPolicy.first) {
          break;
        }
        switch (operation) {
          case AcanthisCheck<O>():
            if (operation is CustomCauseCheck<O>) {
              final cause = operation.cause(newValue);
              if (cause != null) {
                errors.addIssue(
                  operation.code,
                  cause,
                  parameters: operation.parameters,
                );
              }
              break;
            }
            if (!operation(newValue)) {
              errors.addIssue(
                operation.code,
                operation.error,
                parameters: operation.parameters,
              );
            }
            break;
          case AcanthisAsyncCheck<O>():
            if (!await operation(newValue)) {
              errors.addIssue(
                operation.code,
                operation.error,
                parameters: operation.parameters,
              );
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
      return outcomeFromDiagnostics(
        value: success ? newValue : defaultValue ?? newValue,
        errors: errors,
        metadata: metadataEntry,
      );
    } on ValidationError catch (e) {
      errors.addIssue(e.key.isNotEmpty ? e.key : inputErrorKey, e.message);
      return outcomeFromDiagnostics(
        value: valueOnFailure(value),
        errors: errors,
        metadata: metadataEntry,
      );
    } on TypeError {
      errors.addIssue(inputErrorKey, _invalidTypeMessage(value));
      return outcomeFromDiagnostics(
        value: valueOnFailure(value),
        errors: errors,
        metadata: metadataEntry,
      );
    }
  }

  /// Add a check to the type
  AcanthisType<O> withCheck(AcanthisCheck<O> check);

  /// Add an async check to the type
  AcanthisType<O> withAsyncCheck(AcanthisAsyncCheck<O> check);

  /// Make the type nullable
  AcanthisNullable<O> nullable({O? defaultValue}) {
    return AcanthisNullable<O>(this, defaultValue: defaultValue);
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
    Map<String, Object?> parameters = const {},
  }) {
    return withCheck(
      CustomCheck<O>(onCheck, error: error, name: name, parameters: parameters),
    );
  }

  /// Add a custom async check to the number
  AcanthisType<O> refineAsync({
    required Future<bool> Function(O value) onCheck,
    required String error,
    required String name,
    Map<String, Object?> parameters = const {},
  }) {
    return withAsyncCheck(
      CustomAsyncCheck<O>(
        onCheck,
        error: error,
        name: name,
        parameters: parameters,
      ),
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
  }) : transformFn = transform,
       super(isAsync: inType.isAsync || outType.isAsync);

  @override
  bool get isPure => false;

  @override
  T? parseInternal(dynamic value) {
    if (value == null && hasDefault) return outType.parse(defaultValue);
    final inResult = inType.parse(value);
    final T newValue;
    try {
      newValue = transformFn(inResult);
    } catch (e) {
      throw ValidationError.diagnostic(
        'Error transforming the value from $O -> $T: $e',
        code: 'transform',
      );
    }
    return outType.parse(newValue);
  }

  @override
  T? tryParseInternal(dynamic value, {required Map<String, dynamic> errors}) {
    if (value == null && hasDefault) {
      final result = outType.tryParse(defaultValue);
      errors.addAll(result.errors);
      return result.value;
    }
    final inResult = inType.tryParse(value);
    if (!inResult.isValid) {
      errors.addAll(inResult.errors);
      return defaultValue;
    }
    final T newValue;
    try {
      newValue = transformFn(inResult.value);
    } catch (e) {
      errors.addIssue(
        'transform',
        'Error transforming the value from $O -> $T',
      );
      return defaultValue;
    }
    final outResult = outType.tryParse(newValue);
    if (outResult.errors.isNotEmpty) {
      errors.addAll(outResult.errors);
    }
    return outResult.value;
  }

  @override
  T? parse(dynamic value) {
    if (isAsync) {
      throw AsyncValidationException('Cannot use parse with async operations');
    }
    return parseInternal(value);
  }

  @override
  AcanthisOutcome<T?> tryParse(dynamic value) {
    if (isAsync) {
      throw AsyncValidationException(
        'Cannot use tryParse with async operations',
      );
    }
    final errors = IssueSink();
    final parsed = tryParseInternal(value, errors: errors);
    return outcomeFromDiagnostics(
      value: parsed,
      errors: errors,
      metadata: metadataEntry,
    );
  }

  @override
  Future<T?> parseAsync(dynamic value) async {
    if (value == null && hasDefault) return outType.parseAsync(defaultValue);
    final inResult = await inType.parseAsync(value);
    final T newValue;
    try {
      newValue = transformFn(inResult);
    } catch (e) {
      throw ValidationError.diagnostic(
        'Error transforming the value from $O -> $T: $e',
        code: 'transform',
      );
    }
    final outResult = await outType.parseAsync(newValue);
    return outResult;
  }

  @override
  Future<AcanthisOutcome<T?>> tryParseAsync(dynamic value) async {
    if (value == null && hasDefault) return outType.tryParseAsync(defaultValue);
    var inResult = await inType.tryParseAsync(value);
    if (!inResult.isValid) {
      return outcomeFromDiagnostics(
        value: defaultValue,
        errors: inResult.errors,
      );
    }
    final T newValue;
    try {
      newValue = transformFn(inResult.value);
    } catch (e) {
      return outcomeFromDiagnostics(
        value: defaultValue,
        errors: IssueSink.single(
          'transform',
          'Error transforming the value from $O -> $T',
        ),
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
