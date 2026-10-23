import 'package:meta/meta.dart';

import '../types/list.dart';
import '../types/nullable.dart';
import 'issue_sink.dart';
import 'operations.dart';
import 'results.dart';
import 'schema.dart';
import 'schema_operations.dart';
import 'validation_scope.dart';
import '../registries/metadata_registry.dart';
export 'schema_operations.dart' show SchemaOperations;

/// Shared operation plumbing; object and record traversal remain separate.
@internal
abstract class MapSchemaBase<K, V, Self extends Schema<Map<K, V>, Map<K, V>>>
    extends Schema<Map<K, V>, Map<K, V>>
    with
        CheckableSchema<Map<K, V>, Map<K, V>>,
        TransformableSchema<Map<K, V>, Map<K, V>>,
        ValidationSchema<Map<K, V>, Map<K, V>>,
        AsyncSchema<Map<K, V>, Map<K, V>>,
        DefaultSchema<Map<K, V>, Map<K, V>>,
        ListableSchema<Map<K, V>, Map<K, V>>,
        NullableSchema<Map<K, V>, Map<K, V>> {
  MapSchemaBase({MapOperations<K, V>? operations, this.defaultValue})
    : operations = operations ?? MapOperations<K, V>();

  @protected
  final MapOperations<K, V> operations;
  @internal
  bool get hasOperations => !operations.isEmpty;
  @override
  final Map<K, V>? defaultValue;

  @protected
  bool get childrenAreAsync;
  @protected
  Self rebuild(MapOperations<K, V> operations, Map<K, V>? defaultValue);
  @protected
  AcanthisOutcome<Map<K, V>> parseChildren(Object? input, bool collect);
  @protected
  Future<AcanthisOutcome<Map<K, V>>> parseChildrenAsync(
    Object? input,
    bool collect,
  );

  @override
  bool get isAsync => operations.isAsync || childrenAreAsync;
  @override
  List<Check<Map<K, V>>> get checks => operations.checks;
  @override
  List<Transform<Map<K, V>, Map<K, V>>> get transformations =>
      operations.transformations;
  List<AsyncCheck<Map<K, V>>> get asyncChecks => operations.asyncChecks;

  @override
  Self withCheck(Check<Map<K, V>> check) =>
      rebuild(operations.withCheck(check), defaultValue);
  @override
  Self refine({
    required bool Function(Map<K, V>) onCheck,
    String? error,
    String name = 'custom',
  }) => withCheck(
    PredicateCheck<Map<K, V>>.refinement(
      onCheck: onCheck,
      error: error,
      name: name,
    ),
  );
  Self refineAsync(AsyncCheck<Map<K, V>> check) =>
      rebuild(operations.withAsyncCheck(check), defaultValue);
  @override
  Self transform(Map<K, V> Function(Map<K, V>) onTransform) =>
      withTransform(CallbackTransform(onTransform));
  @override
  Self withTransform(Transform<Map<K, V>, Map<K, V>> transform) =>
      rebuild(operations.withTransform(transform), defaultValue);
  Self transformAsync(AsyncTransform<Map<K, V>, Map<K, V>> transform) =>
      rebuild(operations.withAsyncTransform(transform), defaultValue);
  Self withDefault(Map<K, V> value) =>
      rebuild(operations, Map<K, V>.unmodifiable(value));
  @override
  Self meta(MetadataEntry<Map<K, V>> metadata) =>
      attachSchemaMetadata(rebuild(operations, defaultValue), metadata);

  @override
  Map<K, V> parse(Object? input) => parseOutcome(input).valueOrThrow;
  @override
  AcanthisOutcome<Map<K, V>> parseOutcome(Object? input) => _run(input, false);
  @override
  AcanthisOutcome<Map<K, V>> tryParse(Object? input) => _run(input, true);
  @override
  Future<Map<K, V>> parseAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).valueOrThrow;
  @override
  Future<AcanthisOutcome<Map<K, V>>> parseOutcomeAsync(Object? input) =>
      _runAsync(input, false);
  @override
  Future<AcanthisOutcome<Map<K, V>>> tryParseAsync(Object? input) =>
      _runAsync(input, true);
  @override
  bool validate(Object? input) => parseOutcome(input).isValid;
  @override
  bool tryValidate(Object? input) => tryParse(input).isValid;
  Future<bool> validateAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).isValid;
  Future<bool> tryValidateAsync(Object? input) async =>
      (await tryParseAsync(input)).isValid;

  AcanthisOutcome<Map<K, V>> _run(Object? input, bool collect) {
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    if (isAsync) throw StateError('This schema requires an async parse method');
    final result = parseChildren(input ?? defaultValue, collect);
    scope.throwIfCancelled();
    return operations.isEmpty ? result : operations.execute(result, collect);
  }

  Future<AcanthisOutcome<Map<K, V>>> _runAsync(
    Object? input,
    bool collect,
  ) async {
    AcanthisValidationScope.current.throwIfCancelled();
    if (!isAsync) return _run(input, collect);
    return operations.executeAsync(
      await parseChildrenAsync(input ?? defaultValue, collect),
      collect,
    );
  }
}

@internal
typedef MapOperations<K, V> = SchemaOperations<Map<K, V>>;
@internal
bool schemaIsAsync<T>(Schema<Object?, T> schema) =>
    schema is AsyncSchema<Object?, T> && schema.isAsync;

@internal
Future<AcanthisOutcome<T>> parseMapChildAsync<T>(
  Schema<Object?, T> schema,
  Object? input,
  bool collect,
) {
  if (schema is AsyncSchema<Object?, T>) {
    return collect
        ? schema.tryParseAsync(input)
        : schema.parseOutcomeAsync(input);
  }
  return Future.value(
    collect ? schema.tryParse(input) : schema.parseOutcome(input),
  );
}

/// Invocation-local child assembly. Missing recovery never becomes a partial map.
@internal
final class MapParseState<K, V> {
  final output = <K, V>{};
  Map<K, Object?>? _partial;
  Object get ruleOutput =>
      _partial == null ? output : {...output, ..._partial!};
  IssueSink? _sink;
  IssueSink get sink => _sink ??= IssueSink();
  bool hasValue = true;

  bool addChild<T>(Object path, AcanthisOutcome<T> child) {
    for (final issue in child.issues) {
      sink.add(issue.prefixed(path));
    }
    if (child is AcanthisInvalid<T> && !child.hasValue) {
      hasValue = false;
      if (child.partialValue != null && path is K) {
        (_partial ??= {})[path as K] = child.partialValue;
      }
      return false;
    }
    return true;
  }

  AcanthisOutcome<Map<K, V>> finish({
    bool complete = true,
    Object? reuseInput,
  }) {
    if (!hasValue || !complete) {
      return AcanthisInvalid<Map<K, V>>.withoutValue(
        sink.takeIssues(),
        partialValue: complete ? ruleOutput : null,
      );
    }
    if (_sink?.isNotEmpty ?? false) {
      return AcanthisInvalid(sink.takeIssues(), value: output);
    }
    if (reuseInput is Map<K, V> && reuseInput.length == output.length) {
      var unchanged = true;
      for (final entry in output.entries) {
        if (!reuseInput.containsKey(entry.key) ||
            !identical(reuseInput[entry.key], entry.value)) {
          unchanged = false;
          break;
        }
      }
      if (unchanged) return AcanthisValid(reuseInput);
    }
    return AcanthisValid(output);
  }
}
