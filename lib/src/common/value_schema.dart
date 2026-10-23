import 'package:meta/meta.dart';

import '../types/list.dart';
import '../types/nullable.dart';
import 'operations.dart';
import 'results.dart';
import 'schema.dart';
import 'schema_graph.dart';
import 'schema_operations.dart';
import 'validation_scope.dart';
import '../registries/metadata_registry.dart';

/// Persistent operation plumbing for scalar values and transparent wrappers.
@internal
abstract class ValueSchemaBase<T, Self extends Schema<Object?, T>>
    extends Schema<Object?, T>
    with
        CheckableSchema<Object?, T>,
        TransformableSchema<Object?, T>,
        ValidationSchema<Object?, T>,
        AsyncSchema<Object?, T>,
        DefaultSchema<Object?, T>,
        ListableSchema<Object?, T>,
        NullableSchema<Object?, T>
    implements SchemaGraphNode {
  ValueSchemaBase({
    SchemaOperations<T>? operations,
    this.configuredDefault,
    this.ownDefault = false,
  }) : operations = operations ?? SchemaOperations<T>();

  @protected
  final SchemaOperations<T> operations;
  @protected
  final T? configuredDefault;
  @protected
  final bool ownDefault;
  @internal
  bool get hasOperations => !operations.isEmpty;

  /// Finish a child outcome after composition-specific input conversion.
  @internal
  AcanthisOutcome<T> applyOperations(AcanthisOutcome<T> value, bool collect) =>
      operations.execute(value, collect);
  @internal
  Future<AcanthisOutcome<T>> applyOperationsAsync(
    AcanthisOutcome<T> value,
    bool collect,
  ) => operations.executeAsync(value, collect);
  @override
  T? get defaultValue => configuredDefault;
  @override
  bool get hasDefault => ownDefault;
  @override
  bool get isAsync => operations.isAsync;
  @override
  bool get hasLocalAsync => operations.isAsync;
  @override
  Iterable<Schema<Object?, Object?>> get schemaChildren => const [];
  @override
  List<Check<T>> get checks => operations.checks;
  @override
  List<Transform<T, T>> get transformations => operations.transformations;
  List<AsyncCheck<T>> get asyncChecks => operations.asyncChecks;

  @protected
  Self rebuild(
    SchemaOperations<T> operations,
    T? defaultValue,
    bool hasDefault,
  );
  @protected
  AcanthisOutcome<T> parseValue(Object? input, bool collect);
  @protected
  Future<AcanthisOutcome<T>> parseValueAsync(
    Object? input,
    bool collect,
  ) async => parseValue(input, collect);

  @protected
  AcanthisOutcome<T> parseInput(Object? input, bool collect) =>
      parseValue(_input(input), collect);
  @protected
  Future<AcanthisOutcome<T>> parseInputAsync(Object? input, bool collect) =>
      parseValueAsync(_input(input), collect);

  @override
  Self withCheck(Check<T> check) =>
      rebuild(operations.withCheck(check), configuredDefault, ownDefault);
  @override
  Self refine({
    required bool Function(T) onCheck,
    String? error,
    String name = 'custom',
  }) => withCheck(
    PredicateCheck<T>.refinement(onCheck: onCheck, error: error, name: name),
  );
  Self refineAsync(AsyncCheck<T> check) =>
      rebuild(operations.withAsyncCheck(check), configuredDefault, ownDefault);
  @override
  Self transform(T Function(T) onTransform) =>
      withTransform(CallbackTransform<T, T>(onTransform));
  @override
  Self withTransform(Transform<T, T> transform) => rebuild(
    operations.withTransform(transform),
    configuredDefault,
    ownDefault,
  );
  Self transformAsync(AsyncTransform<T, T> transform) => rebuild(
    operations.withAsyncTransform(transform),
    configuredDefault,
    ownDefault,
  );
  Self withDefault(T value) => rebuild(operations, value, true);
  @override
  Self meta(MetadataEntry<T> metadata) => attachSchemaMetadata(
    rebuild(operations, configuredDefault, ownDefault),
    metadata,
  );

  @override
  T parse(Object? input) => parseOutcome(input).valueOrThrow;
  @override
  AcanthisOutcome<T> parseOutcome(Object? input) {
    AcanthisValidationScope.current.throwIfCancelled();
    if (isAsync) throw StateError('This schema requires an async parse method');
    return operations.execute(parseInput(input, false), false);
  }

  @override
  AcanthisOutcome<T> tryParse(Object? input) {
    AcanthisValidationScope.current.throwIfCancelled();
    if (isAsync) throw StateError('This schema requires an async parse method');
    return operations.execute(parseInput(input, true), true);
  }

  Object? _input(Object? input) =>
      input == null && hasDefault ? defaultValue : input;
  @override
  Future<T> parseAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).valueOrThrow;
  @override
  Future<AcanthisOutcome<T>> parseOutcomeAsync(Object? input) async {
    AcanthisValidationScope.current.throwIfCancelled();
    if (!isAsync) return parseOutcome(input);
    return operations.executeAsync(await parseInputAsync(input, false), false);
  }

  @override
  Future<AcanthisOutcome<T>> tryParseAsync(Object? input) async {
    AcanthisValidationScope.current.throwIfCancelled();
    if (!isAsync) return tryParse(input);
    return operations.executeAsync(await parseInputAsync(input, true), true);
  }

  @override
  bool validate(Object? input) => parseOutcome(input).isValid;
  @override
  bool tryValidate(Object? input) => tryParse(input).isValid;
  Future<bool> validateAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).isValid;
  Future<bool> tryValidateAsync(Object? input) async =>
      (await tryParseAsync(input)).isValid;
}
