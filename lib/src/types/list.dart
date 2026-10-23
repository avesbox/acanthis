import '../registries/metadata_registry.dart';
import '../common/validation_scope.dart';
import '../common/issue_sink.dart';
import '../common/issue.dart';
import '../common/operations.dart';
import '../common/results.dart';
import '../common/schema.dart';
import '../common/schema_graph.dart';
import '../common/fast_schema.dart';
import '../validators/list.dart';
import '../validators/string.dart';
import 'nullable.dart';
import 'string.dart';

/// An ordered, immutable list definition with invocation-local parsing state.
final class AcanthisList<T> extends Schema<List<T>, List<T>>
    with
        CheckableSchema<List<T>, List<T>>,
        TransformableSchema<List<T>, List<T>>,
        ValidationSchema<List<T>, List<T>>,
        AsyncSchema<List<T>, List<T>>,
        DefaultSchema<List<T>, List<T>>,
        NullableSchema<List<T>, List<T>>
    implements SchemaGraphNode, FastSchema<List<T>> {
  AcanthisList(this.element) : _tail = null, defaultValue = null;
  AcanthisList._(this.element, this._tail, this.defaultValue);
  final Schema<Object?, T> element;
  final _Node<T>? _tail;
  @override
  final List<T>? defaultValue;
  late final List<_Step<T>> _steps = _materialize(_tail);
  @override
  late final List<Check<List<T>>> checks = List.unmodifiable(
    _steps.whereType<_CheckStep<T>>().map((s) => s.operation),
  );
  @override
  late final List<Transform<List<T>, List<T>>> transformations =
      List.unmodifiable(
        _steps.whereType<_TransformStep<T>>().map((s) => s.operation),
      );
  late final List<AsyncCheck<List<T>>> asyncChecks = List.unmodifiable(
    _steps.whereType<_AsyncCheckStep<T>>().map((s) => s.operation),
  );
  @override
  late final bool isAsync = schemaGraphIsAsync(this);
  @override
  bool get hasLocalAsync => _tail?.isAsync ?? false;
  @override
  Iterable<Schema<Object?, Object?>> get schemaChildren => [element];
  AcanthisList<T> _append(_Step<T> step) => copySchemaMetadata(
    this,
    AcanthisList<T>._(element, _Node(_tail, step), defaultValue),
  );
  @override
  AcanthisList<T> withCheck(Check<List<T>> check) => _append(_CheckStep(check));
  @override
  AcanthisList<T> refine({
    required bool Function(List<T>) onCheck,
    String? error,
    String name = 'custom',
  }) => withCheck(
    PredicateCheck<List<T>>.refinement(
      onCheck: onCheck,
      error: error,
      name: name,
    ),
  );
  AcanthisList<T> refineAsync(AsyncCheck<List<T>> check) =>
      _append(_AsyncCheckStep(check));
  @override
  AcanthisList<T> transform(List<T> Function(List<T>) onTransform) =>
      withTransform(CallbackTransform<List<T>, List<T>>(onTransform));
  @override
  AcanthisList<T> withTransform(Transform<List<T>, List<T>> transform) =>
      _append(_TransformStep(transform));
  AcanthisList<T> transformAsync(AsyncTransform<List<T>, List<T>> transform) =>
      _append(_AsyncTransformStep(transform));
  AcanthisList<T> withDefault(List<T> value) => copySchemaMetadata(
    this,
    AcanthisList<T>._(element, _tail, List<T>.unmodifiable(value)),
  );
  AcanthisList<T> min(int length) => withCheck(MinItemsListCheck<T>(length));
  AcanthisList<T> max(int length) => withCheck(MaxItemsListCheck<T>(length));
  AcanthisList<T> length(int length) => withCheck(LengthListCheck<T>(length));
  AcanthisList<T> unique() => withCheck(UniqueItemsListCheck<T>());
  AcanthisList<T> contains(T value) => withCheck(ContainsListCheck<T>(value));
  AcanthisList<T> anyOf(List<T> values) => withCheck(AnyOfListCheck<T>(values));
  AcanthisList<T> everyOf(List<T> values) =>
      withCheck(EveryOfListCheck<T>(values));
  Schema<Object?, T> unwrap() => element;
  @override
  AcanthisList<T> meta(MetadataEntry<List<T>> metadata) => attachSchemaMetadata(
    copySchemaMetadata(this, AcanthisList<T>._(element, _tail, defaultValue)),
    metadata,
  );
  @override
  List<T> parse(Object? input) => parseOutcome(input).valueOrThrow;
  @override
  AcanthisOutcome<List<T>> parseOutcome(Object? input) => _run(input, false);
  @override
  AcanthisOutcome<List<T>> tryParse(Object? input) => _run(input, true);
  @override
  Future<List<T>> parseAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).valueOrThrow;
  @override
  Future<AcanthisOutcome<List<T>>> parseOutcomeAsync(Object? input) =>
      _runAsync(input, false);
  @override
  Future<AcanthisOutcome<List<T>>> tryParseAsync(Object? input) =>
      _runAsync(input, true);
  @override
  bool validate(Object? input) => parseOutcome(input).isValid;
  @override
  bool tryValidate(Object? input) => tryParse(input).isValid;
  @override
  late final bool canFast =
      _tail == null &&
      element is FastSchema<T> &&
      (element as FastSchema<T>).canFast;
  late final List<StringCheck>? _stringChecks =
      element is AcanthisString && (element as AcanthisString).canFast
      ? (element as AcanthisString).checks.cast<StringCheck>().toList(
          growable: false,
        )
      : null;
  late final List<AcanthisIssue> _stringIssues = [
    for (final check in _stringChecks!)
      AcanthisIssue(
        path: const [],
        code: check.code,
        parameters: check.parameters,
      ),
  ];
  @override
  List<T>? tryFast(Object? input) {
    if (!canFast || isAsync) return null;
    input ??= defaultValue;
    if (input is! List<Object?>) return null;
    final child = element as FastSchema<T>;
    final scope = AcanthisValidationScope.current;
    final original = input is List<T> ? input : null;
    List<T>? output = original;
    final building = original == null ? <T>[] : null;
    for (var i = 0; i < input.length; i++) {
      scope.throwIfCancelled();
      final value = child.tryFast(input[i]);
      if (value == null) return null;
      if (building != null) {
        building.add(value);
      } else if (!identical(value, input[i])) {
        if (identical(output, original)) output = List<T>.of(original!);
        output![i] = value;
      }
    }
    return building ?? output;
  }

  Future<bool> validateAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).isValid;
  Future<bool> tryValidateAsync(Object? input) async =>
      (await tryParseAsync(input)).isValid;

  AcanthisOutcome<List<T>> _invalidInput() =>
      AcanthisInvalid<List<T>>.withoutValue(
        IssueSink.single(
          'type',
          parameters: const {'expected': 'List'},
        ).takeIssues(),
      );

  AcanthisOutcome<List<T>> _run(Object? input, bool collect) {
    AcanthisValidationScope.current.throwIfCancelled();
    if (isAsync) throw StateError('This schema requires an async parse method');
    input ??= defaultValue;
    if (input is List<String>) {
      final checks = _stringChecks;
      if (checks != null) return _runStrings(input, checks, collect);
    }
    final fast = tryFast(input);
    if (fast != null) return AcanthisValid(fast);
    if (input is! List<Object?>) return _invalidInput();
    final run = _ListRun<T>(input);
    for (var i = 0; i < input.length; i++) {
      AcanthisValidationScope.current.throwIfCancelled();
      final result = collect
          ? element.tryParse(input[i])
          : element.parseOutcome(input[i]);
      AcanthisValidationScope.current.throwIfCancelled();
      run.child(i, result);
      if (!collect && !result.isValid) {
        return run.finishChildren(complete: false);
      }
    }
    final value = run.values.value;
    if (value == null) return run.finishChildren(complete: true);
    return _execute(value, run, collect);
  }

  // Native string checks cannot replace values; share one sink for the batch.
  AcanthisOutcome<List<T>> _runStrings(
    List<String> input,
    List<StringCheck> checks,
    bool collect,
  ) {
    final scope = AcanthisValidationScope.current;
    final collectChecks =
        collect && scope.fieldPolicy == AcanthisCollectionPolicy.all;
    IssueSink? sink;
    for (var i = 0; i < input.length; i++) {
      scope.throwIfCancelled();
      final value = input[i];
      for (var j = 0; j < checks.length; j++) {
        final check = checks[j];
        if (!check.test(value)) {
          (sink ??= IssueSink()).add(_stringIssues[j].prefixed(i));
          if (!collectChecks) break;
        }
      }
      scope.throwIfCancelled();
      if (!collect && sink != null) break;
    }
    final value = input as List<T>;
    if (_tail == null || (!collect && sink != null)) {
      return sink == null
          ? AcanthisValid(value)
          : AcanthisInvalid(sink.takeIssues(), value: value);
    }
    return _execute(value, _ListRun<T>(input).._sink = sink, collect);
  }

  AcanthisOutcome<List<T>> _execute(
    List<T> value,
    _ListRun<T> run,
    bool collect,
  ) {
    final operationScope = AcanthisValidationScope.current;
    final collectOperations =
        collect && operationScope.fieldPolicy == AcanthisCollectionPolicy.all;
    for (final step in _steps) {
      operationScope.throwIfCancelled();
      switch (step) {
        case _CheckStep<T>(:final operation):
          run.check(value, operation);
        case _TransformStep<T>(:final operation):
          if (run.hasIssues) return run.finish(value);
          value = operation.apply(value);
        case _AsyncCheckStep<T>() || _AsyncTransformStep<T>():
          throw StateError('Async step in synchronous execution');
      }
      operationScope.throwIfCancelled();
      if (!collectOperations && run.hasIssues) break;
    }
    return run.finish(value);
  }

  Future<AcanthisOutcome<List<T>>> _runAsync(
    Object? input,
    bool collect,
  ) async {
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    if (!isAsync) return _run(input, collect);
    input ??= defaultValue;
    if (input is! List<Object?>) return _invalidInput();
    final run = _ListRun<T>(input);
    final child = element;
    for (var i = 0; i < input.length; i++) {
      AcanthisValidationScope.current.throwIfCancelled();
      final AcanthisOutcome<T> result;
      if (child is AsyncSchema<Object?, T>) {
        result = await (collect
            ? child.tryParseAsync(input[i])
            : child.parseOutcomeAsync(input[i]));
      } else {
        result = collect
            ? child.tryParse(input[i])
            : child.parseOutcome(input[i]);
      }
      AcanthisValidationScope.current.throwIfCancelled();
      run.child(i, result);
      if (!collect && !result.isValid) {
        return run.finishChildren(complete: false);
      }
    }
    final childValues = run.values.value;
    if (childValues == null) return run.finishChildren(complete: true);
    List<T> value = childValues;
    final operationScope = AcanthisValidationScope.current;
    final collectOperations =
        collect && operationScope.fieldPolicy == AcanthisCollectionPolicy.all;
    for (final step in _steps) {
      operationScope.throwIfCancelled();
      switch (step) {
        case _CheckStep<T>(:final operation):
          run.check(value, operation);
        case _AsyncCheckStep<T>(:final operation):
          await operation.evaluate(value, run.context);
        case _TransformStep<T>(:final operation):
          if (run.hasIssues) return run.finish(value);
          value = operation.apply(value);
        case _AsyncTransformStep<T>(:final operation):
          if (run.hasIssues) return run.finish(value);
          value = await operation.apply(value);
      }
      operationScope.throwIfCancelled();
      if (!collectOperations && run.hasIssues) break;
    }
    return run.finish(value);
  }
}

AcanthisList<T> list<T>(Schema<Object?, T> element) => AcanthisList<T>(element);

extension ListSchemaComposition<I, O> on Schema<I, O> {
  AcanthisList<O> list() => AcanthisList<O>(this);
}

final class _ListValues<T> {
  _ListValues(this.raw) : original = raw is List<T> ? raw : null {
    if (original == null) _changed = <T>[];
  }
  final List<Object?> raw;
  final List<T>? original;
  List<T>? _changed;
  bool hasValue = true;
  void put(int index, T value) {
    final typed = original;
    if (typed == null) {
      _changed!.add(value);
    } else if (!identical(value, raw[index])) {
      (_changed ??= List<T>.of(typed))[index] = value;
    }
  }

  List<T>? get value => hasValue ? (_changed ?? original) : null;
}

final class _ListRun<T> {
  _ListRun(List<Object?> raw) : values = _ListValues<T>(raw);
  final _ListValues<T> values;
  List<Object?>? _partial;
  IssueSink? _sink;
  IssueSink get sink => _sink ??= IssueSink();
  bool get hasIssues => _sink?.isNotEmpty ?? false;
  late final CheckContext context = CheckContext.createContext(sink);
  void child(int index, AcanthisOutcome<T> result) {
    if (result is AcanthisInvalid<T> && !result.hasValue) {
      _partial ??= [
        for (var i = 0; i < values.raw.length; i++)
          i < (values._changed?.length ?? 0)
              ? values._changed![i]
              : values.raw[i],
      ];
      _partial![index] = result.partialValue;
      values.hasValue = false;
    } else {
      values.put(index, result.value);
      if (_partial != null) _partial![index] = result.value;
    }
    for (final issue in result.issues) {
      sink.add(issue.prefixed(index));
    }
  }

  void check(List<T> value, Check<List<T>> operation) {
    if (operation is ListCheck<T>) {
      if (!operation.test(value)) {
        sink.addIssue(operation.code, parameters: operation.parameters);
      }
    } else {
      operation.evaluate(value, context);
    }
  }

  AcanthisOutcome<List<T>> finishChildren({required bool complete}) {
    final value = values.value;
    if (value == null || (!complete && values.original == null)) {
      return AcanthisInvalid<List<T>>.withoutValue(
        sink.takeIssues(),
        partialValue: complete ? _partial : null,
      );
    }
    return finish(value);
  }

  AcanthisOutcome<List<T>> finish(List<T> value) => !hasIssues
      ? AcanthisValid(value)
      : AcanthisInvalid(sink.takeIssues(), value: value);
}

sealed class _Step<T> {
  const _Step();
}

final class _CheckStep<T> extends _Step<T> {
  const _CheckStep(this.operation);
  final Check<List<T>> operation;
}

final class _TransformStep<T> extends _Step<T> {
  const _TransformStep(this.operation);
  final Transform<List<T>, List<T>> operation;
}

final class _AsyncCheckStep<T> extends _Step<T> {
  const _AsyncCheckStep(this.operation);
  final AsyncCheck<List<T>> operation;
}

final class _AsyncTransformStep<T> extends _Step<T> {
  const _AsyncTransformStep(this.operation);
  final AsyncTransform<List<T>, List<T>> operation;
}

final class _Node<T> {
  _Node(this.previous, this.step)
    : length = (previous?.length ?? 0) + 1,
      isAsync =
          (previous?.isAsync ?? false) ||
          step is _AsyncCheckStep<T> ||
          step is _AsyncTransformStep<T>;
  final _Node<T>? previous;
  final _Step<T> step;
  final int length;
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

mixin ListableSchema<I, O> on Schema<I, O> {
  AcanthisList<O> list() => AcanthisList<O>(this);
}
