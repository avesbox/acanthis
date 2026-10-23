import 'package:meta/meta.dart';

import 'issue_sink.dart';
import 'operations.dart';
import 'results.dart';
import 'schema.dart';
import 'validation_scope.dart';

/// Persistent ordered operations for native schemas.
@internal
final class SchemaOperations<T> {
  SchemaOperations() : _tail = null;
  SchemaOperations._(this._tail);
  final _Node<T>? _tail;
  bool get isEmpty => _tail == null;
  bool get isAsync => _tail?.isAsync ?? false;
  SchemaOperations<T> _append(_Step<T> step) =>
      SchemaOperations._(_Node(_tail, step));
  SchemaOperations<T> withCheck(Check<T> check) => _append(_CheckStep(check));
  SchemaOperations<T> withAsyncCheck(AsyncCheck<T> check) =>
      _append(_AsyncCheckStep(check));
  SchemaOperations<T> withTransform(Transform<T, T> transform) =>
      _append(_TransformStep(transform));
  SchemaOperations<T> withAsyncTransform(AsyncTransform<T, T> transform) =>
      _append(_AsyncTransformStep(transform));
  SchemaOperations<T> withField(
    String name,
    Object? Function(T) getter,
    Schema<Object?, Object?> schema, {
    required bool optional,
  }) => _append(_FieldStep(name, getter, schema, optional));
  late final List<_Step<T>> _steps = _materialize(_tail);
  late final List<Check<T>> checks = List.unmodifiable(
    _steps.whereType<_CheckStep<T>>().map((s) => s.operation),
  );
  late final List<Transform<T, T>> transformations = List.unmodifiable(
    _steps.whereType<_TransformStep<T>>().map((s) => s.operation),
  );
  late final List<AsyncCheck<T>> asyncChecks = List.unmodifiable(
    _steps.whereType<_AsyncCheckStep<T>>().map((s) => s.operation),
  );

  AcanthisOutcome<T> execute(AcanthisOutcome<T> child, bool collect) {
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    final collectFields = collect;
    collect = collect && scope.fieldPolicy == AcanthisCollectionPolicy.all;
    if (_tail == null ||
        (child is AcanthisInvalid<T> && (!collect || !child.hasValue))) {
      return child;
    }
    var value = child.value;
    final sink = IssueSink.fromIssues(child.issues);
    late final context = CheckContext.createContext(sink);
    for (final step in _steps) {
      scope.throwIfCancelled();
      switch (step) {
        case _CheckStep<T>(:final operation):
          operation.evaluate(value, context);
        case _TransformStep<T>(:final operation):
          if (sink.isNotEmpty) return _finish(value, sink);
          value = operation.apply(value);
        case _FieldStep<T>(
          :final getter,
          :final schema,
          :final optional,
          :final name,
        ):
          final input = getter(value);
          scope.throwIfCancelled();
          if (!optional || input != null) {
            final result = collectFields
                ? schema.tryParse(input)
                : schema.parseOutcome(input);
            for (final issue in result.issues) {
              sink.add(issue.prefixed(name));
            }
          }
        case _AsyncCheckStep<T>() || _AsyncTransformStep<T>():
          throw StateError('Async step in synchronous execution');
      }
      scope.throwIfCancelled();
      if (sink.isNotEmpty &&
          (step is _FieldStep<T>
              ? !collectFields ||
                    scope.objectPolicy == AcanthisCollectionPolicy.first
              : !collect)) {
        break;
      }
    }
    return _finish(value, sink);
  }

  Future<AcanthisOutcome<T>> executeAsync(
    AcanthisOutcome<T> child,
    bool collect,
  ) async {
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    final collectFields = collect;
    collect = collect && scope.fieldPolicy == AcanthisCollectionPolicy.all;
    if (!isAsync && !(_tail?.hasFields ?? false)) {
      return execute(child, collect);
    }
    if (child is AcanthisInvalid<T> && (!collect || !child.hasValue)) {
      return child;
    }
    var value = child.value;
    final sink = IssueSink.fromIssues(child.issues);
    late final context = CheckContext.createContext(sink);
    for (final step in _steps) {
      scope.throwIfCancelled();
      switch (step) {
        case _CheckStep<T>(:final operation):
          operation.evaluate(value, context);
        case _AsyncCheckStep<T>(:final operation):
          await operation.evaluate(value, context);
        case _TransformStep<T>(:final operation):
          if (sink.isNotEmpty) return _finish(value, sink);
          value = operation.apply(value);
        case _AsyncTransformStep<T>(:final operation):
          if (sink.isNotEmpty) return _finish(value, sink);
          value = await operation.apply(value);
        case _FieldStep<T>(
          :final getter,
          :final schema,
          :final optional,
          :final name,
        ):
          final input = getter(value);
          scope.throwIfCancelled();
          if (!optional || input != null) {
            final AcanthisOutcome<Object?> result;
            if (schema is AsyncSchema<Object?, Object?>) {
              result = await (collectFields
                  ? schema.tryParseAsync(input)
                  : schema.parseOutcomeAsync(input));
            } else {
              result = collectFields
                  ? schema.tryParse(input)
                  : schema.parseOutcome(input);
            }
            for (final issue in result.issues) {
              sink.add(issue.prefixed(name));
            }
          }
      }
      scope.throwIfCancelled();
      if (sink.isNotEmpty &&
          (step is _FieldStep<T>
              ? !collectFields ||
                    scope.objectPolicy == AcanthisCollectionPolicy.first
              : !collect)) {
        break;
      }
    }
    return _finish(value, sink);
  }

  AcanthisOutcome<T> _finish(T value, IssueSink sink) => sink.isEmpty
      ? AcanthisValid(value)
      : AcanthisInvalid(sink.takeIssues(), value: value);
}

sealed class _Step<T> {
  const _Step();
}

final class _CheckStep<T> extends _Step<T> {
  const _CheckStep(this.operation);
  final Check<T> operation;
}

final class _TransformStep<T> extends _Step<T> {
  const _TransformStep(this.operation);
  final Transform<T, T> operation;
}

final class _AsyncCheckStep<T> extends _Step<T> {
  const _AsyncCheckStep(this.operation);
  final AsyncCheck<T> operation;
}

final class _AsyncTransformStep<T> extends _Step<T> {
  const _AsyncTransformStep(this.operation);
  final AsyncTransform<T, T> operation;
}

final class _FieldStep<T> extends _Step<T> {
  const _FieldStep(this.name, this.getter, this.schema, this.optional);
  final String name;
  final Object? Function(T) getter;
  final Schema<Object?, Object?> schema;
  final bool optional;
}

final class _Node<T> {
  _Node(this.previous, this.step)
    : length = (previous?.length ?? 0) + 1,
      hasFields = (previous?.hasFields ?? false) || step is _FieldStep<T>,
      isAsync =
          (previous?.isAsync ?? false) ||
          step is _AsyncCheckStep<T> ||
          step is _AsyncTransformStep<T>;
  final _Node<T>? previous;
  final _Step<T> step;
  final int length;
  final bool hasFields;
  final bool isAsync;
}

List<_Step<T>> _materialize<T>(_Node<T>? tail) {
  if (tail == null) return const [];
  final steps = List<_Step<T>>.filled(tail.length, tail.step, growable: false);
  var index = steps.length - 1;
  for (_Node<T>? node = tail; node != null; node = node.previous) {
    steps[index--] = node.step;
  }
  return steps;
}
