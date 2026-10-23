import '../registries/metadata_registry.dart';
import '../common/validation_scope.dart';

import 'dart:core';
import 'dart:core' as core;

import '../common/issue_sink.dart';
import '../common/operations.dart';
import '../common/results.dart';
import '../common/schema.dart';
import '../common/fast_schema.dart';
import '../transformations/number.dart';
import '../validators/common.dart';
import '../validators/number.dart';
import 'list.dart';
import 'nullable.dart';

/// Typed numeric schemas share immutable definitions, never parsing state.
final class AcanthisNumeric<T extends num> extends Schema<T, T>
    with
        CheckableSchema<T, T>,
        TransformableSchema<T, T>,
        ValidationSchema<T, T>,
        AsyncSchema<T, T>,
        DefaultSchema<T, T>,
        ListableSchema<T, T>,
        NullableSchema<T, T>
    implements FastSchema<T> {
  AcanthisNumeric({this.coercionEnabled = false, this.defaultValue})
    : _tail = null;
  AcanthisNumeric._(this._tail, this.coercionEnabled, this.defaultValue);

  final _OperationNode<T>? _tail;
  final bool coercionEnabled;
  @override
  final T? defaultValue;
  bool get isIdentity => _tail == null && !coercionEnabled && !hasDefault;
  @override
  bool get canFast =>
      !coercionEnabled && (_tail == null || _nativeChecks != null);
  @override
  T? tryFast(Object? input) {
    if (coercionEnabled) return null;
    input ??= defaultValue;
    if (input is! T) return null;
    if (_tail == null) return input;
    final native = _nativeChecks;
    if (native == null) return null;
    for (final check in native) {
      if (!check.test(input)) return null;
    }
    return input;
  }

  late final List<_NumericStep<T>> _steps = _materialize(_tail);
  late final List<NumberCheck<T>>? _nativeChecks = _materializeNativeChecks(
    _tail,
  );

  @override
  late final List<Check<T>> checks = List.unmodifiable(
    _nativeChecks ??
        _steps.whereType<_CheckStep<T>>().map((step) => step.operation),
  );
  @override
  late final List<Transform<T, T>> transformations = List.unmodifiable(
    _steps.whereType<_TransformStep<T>>().map((step) => step.operation),
  );
  late final List<AsyncCheck<T>> asyncChecks = List.unmodifiable(
    _steps.whereType<_AsyncCheckStep<T>>().map((step) => step.operation),
  );

  @override
  bool get isAsync => _tail?.isAsync ?? false;

  AcanthisNumeric<T> _append(_NumericStep<T> step) => copySchemaMetadata(
    this,
    AcanthisNumeric<T>._(
      _OperationNode<T>(_tail, step),
      coercionEnabled,
      defaultValue,
    ),
  );
  @override
  AcanthisNumeric<T> withCheck(Check<T> check) => _append(_CheckStep<T>(check));

  @override
  AcanthisNumeric<T> refine({
    required bool Function(T) onCheck,
    String? error,
    String name = 'custom',
  }) => withCheck(
    PredicateCheck<T>.refinement(onCheck: onCheck, error: error, name: name),
  );
  AcanthisNumeric<T> refineAsync(AsyncCheck<T> check) =>
      _append(_AsyncCheckStep<T>(check));
  @override
  AcanthisNumeric<T> transform(T Function(T) onTransform) =>
      withTransform(CallbackTransform<T, T>(onTransform));
  @override
  AcanthisNumeric<T> withTransform(Transform<T, T> transform) =>
      _append(_TransformStep<T>(transform));
  AcanthisNumeric<T> transformAsync(AsyncTransform<T, T> transform) =>
      _append(_AsyncTransformStep<T>(transform));
  AcanthisNumeric<T> coerce() =>
      copySchemaMetadata(this, AcanthisNumeric<T>._(_tail, true, defaultValue));
  @override
  AcanthisNumeric<T> meta(MetadataEntry<T> metadata) => attachSchemaMetadata(
    copySchemaMetadata(
      this,
      AcanthisNumeric<T>._(_tail, coercionEnabled, defaultValue),
    ),
    metadata,
  );
  AcanthisNumeric<T> withDefault(T value) => copySchemaMetadata(
    this,
    AcanthisNumeric<T>._(_tail, coercionEnabled, value),
  );

  AcanthisNumeric<T> lte(T value) => withCheck(LteNumberCheck<T>(value));
  AcanthisNumeric<T> gte(T value) => withCheck(GteNumberCheck<T>(value));
  AcanthisNumeric<T> lt(T value) => withCheck(LtNumberCheck<T>(value));
  AcanthisNumeric<T> gt(T value) => withCheck(GtNumberCheck<T>(value));
  AcanthisNumeric<T> between(T min, T max) =>
      withCheck(BetweenNumberCheck<T>(min, max));
  AcanthisNumeric<T> positive() => withCheck(PositiveNumberCheck<T>());
  AcanthisNumeric<T> negative() => withCheck(NegativeNumberCheck<T>());
  AcanthisNumeric<T> nonPositive() => withCheck(NonPositiveNumberCheck<T>());
  AcanthisNumeric<T> nonNegative() => withCheck(NonNegativeNumberCheck<T>());
  AcanthisNumeric<T> integer() => withCheck(IntegerNumberCheck<T>());
  AcanthisNumeric<T> double() => withCheck(DoubleNumberCheck<T>());
  AcanthisNumeric<T> multipleOf(int value) =>
      withCheck(MultipleOfCheck<T>(value));
  AcanthisNumeric<T> finite() => withCheck(FiniteNumberCheck<T>());
  AcanthisNumeric<T> infinite() => withCheck(InfiniteNumberCheck<T>());
  AcanthisNumeric<T> nan() => withCheck(NaNNumberCheck<T>());
  AcanthisNumeric<T> notNaN() => withCheck(NotNaNNumberCheck<T>());
  AcanthisNumeric<T> enumerated(List<T> values) =>
      withCheck(EnumeratedNumberCheck<T>(values));
  AcanthisNumeric<T> exact(T value) => withCheck(ExactCheck<T>(value: value));
  AcanthisNumeric<T> pow(int exponent) =>
      withTransform(PowerNumberTransform<T>(exponent));

  @override
  T parse(Object? input) => parseOutcome(input).valueOrThrow;
  @override
  AcanthisOutcome<T> parseOutcome(Object? input) => _run(input, collect: false);
  @override
  AcanthisOutcome<T> tryParse(Object? input) => _run(input, collect: true);
  @override
  Future<T> parseAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).valueOrThrow;
  @override
  Future<AcanthisOutcome<T>> parseOutcomeAsync(Object? input) =>
      _runAsync(input, collect: false);
  @override
  Future<AcanthisOutcome<T>> tryParseAsync(Object? input) =>
      _runAsync(input, collect: true);
  @override
  bool validate(Object? input) => parseOutcome(input).isValid;
  @override
  bool tryValidate(Object? input) => tryParse(input).isValid;
  Future<bool> validateAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).isValid;
  Future<bool> tryValidateAsync(Object? input) async =>
      (await tryParseAsync(input)).isValid;

  static final _decimalInteger = RegExp(r'^[+-]?[0-9]+$');

  T? _decodeInput(Object? input) {
    input ??= defaultValue;
    if (input is T) return input;
    if (!coercionEnabled) return null;
    num? converted;
    if (T == int) {
      if (input is num) {
        converted = exactInteger(input);
      } else if (input is String) {
        final text = input.trim();
        converted = int.tryParse(text);
        if (converted == null) {
          // An overflowing integer string must not round through a double.
          if (_decimalInteger.hasMatch(text)) return null;
          final parsed = core.double.tryParse(text);
          if (parsed != null) converted = exactInteger(parsed);
        }
      }
    } else if (T == core.double) {
      if (input is num && input.isFinite) {
        converted = input.toDouble();
      } else if (input is String) {
        final parsed = core.double.tryParse(input.trim());
        if (parsed != null && parsed.isFinite) converted = parsed;
      }
    } else if (input is String) {
      converted = num.tryParse(input.trim());
    }
    return converted is T ? converted : null;
  }

  AcanthisOutcome<T> _invalidInput() => AcanthisInvalid<T>.withoutValue(
    IssueSink.single('type', parameters: {'expected': '$T'}).takeIssues(),
  );

  AcanthisOutcome<T> _run(Object? input, {required bool collect}) {
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    collect = collect && scope.fieldPolicy == AcanthisCollectionPolicy.all;
    if (isAsync) throw StateError('This schema requires an async parse method');
    final decoded = _decodeInput(input);
    if (decoded == null) return _invalidInput();
    var value = decoded;
    if (_tail == null) return AcanthisValid<T>(value);
    final nativeChecks = _nativeChecks;
    if (nativeChecks != null) {
      return _runNativeChecks(value, nativeChecks, collect: collect);
    }
    final run = _NumericRun<T>();
    for (final step in _steps) {
      scope.throwIfCancelled();
      switch (step) {
        case _CheckStep<T>(:final operation):
          run.check(value, operation);
        case _TransformStep<T>(:final operation):
          if (run.sink.isNotEmpty) return run.finish(value);
          final transformed = run.transform(value, operation);
          if (transformed == null) return run.finish(value);
          value = transformed;
        case _AsyncCheckStep<T>() || _AsyncTransformStep<T>():
          throw StateError('Async step in synchronous execution');
      }
      scope.throwIfCancelled();
      if (!collect && run.sink.isNotEmpty) break;
    }
    return run.finish(value);
  }

  Future<AcanthisOutcome<T>> _runAsync(
    Object? input, {
    required bool collect,
  }) async {
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    collect = collect && scope.fieldPolicy == AcanthisCollectionPolicy.all;
    if (!isAsync) return _run(input, collect: collect);
    final decoded = _decodeInput(input);
    if (decoded == null) return _invalidInput();
    var value = decoded;
    final run = _NumericRun<T>();
    for (final step in _steps) {
      scope.throwIfCancelled();
      switch (step) {
        case _CheckStep<T>(:final operation):
          run.check(value, operation);
        case _AsyncCheckStep<T>(:final operation):
          await operation.evaluate(value, run.context);
        case _TransformStep<T>(:final operation):
          if (run.sink.isNotEmpty) return run.finish(value);
          final transformed = run.transform(value, operation);
          if (transformed == null) return run.finish(value);
          value = transformed;
        case _AsyncTransformStep<T>(:final operation):
          if (run.sink.isNotEmpty) return run.finish(value);
          value = await operation.apply(value);
      }
      scope.throwIfCancelled();
      if (!collect && run.sink.isNotEmpty) break;
    }
    return run.finish(value);
  }
}

// Built-in checks neither change the value nor require callback context state.
// Keep their order and create an accumulator only when a predicate fails.
AcanthisOutcome<T> _runNativeChecks<T extends num>(
  T value,
  List<NumberCheck<T>> checks, {
  required bool collect,
}) {
  IssueSink? sink;
  for (final check in checks) {
    if (!check.test(value)) {
      (sink ??= IssueSink()).addIssue(check.code, parameters: check.parameters);
      if (!collect) break;
    }
  }
  return sink == null
      ? AcanthisValid<T>(value)
      : AcanthisInvalid<T>(sink.takeIssues(), value: value);
}

List<NumberCheck<T>>? _materializeNativeChecks<T extends num>(
  _OperationNode<T>? tail,
) {
  if (tail == null) return null;
  final last = tail.step;
  if (last is! _CheckStep<T>) return null;
  final lastOperation = last.operation;
  if (lastOperation is! NumberCheck<T>) return null;
  final checks = List<NumberCheck<T>>.filled(
    tail.length,
    lastOperation,
    growable: false,
  );
  var index = checks.length - 1;
  for (_OperationNode<T>? node = tail; node != null; node = node.previous) {
    final step = node.step;
    if (step is! _CheckStep<T>) return null;
    final operation = step.operation;
    if (operation is! NumberCheck<T>) return null;
    checks[index--] = operation;
  }
  return checks;
}

typedef AcanthisNumber = AcanthisNumeric<num>;
typedef AcanthisInt = AcanthisNumeric<int>;
typedef AcanthisDouble = AcanthisNumeric<core.double>;

AcanthisNumber number() => AcanthisNumber();
AcanthisInt integer() => AcanthisInt();
AcanthisDouble doubleType() => AcanthisDouble();

final class _NumericRun<T extends num> {
  final IssueSink sink = IssueSink();
  late final CheckContext context = CheckContext.createContext(sink);

  void check(T value, Check<T> operation) {
    if (operation is NumberCheck<T>) {
      if (!operation.test(value)) {
        sink.addIssue(operation.code, parameters: operation.parameters);
      }
    } else {
      operation.evaluate(value, context);
    }
  }

  T? transform(T value, Transform<T, T> operation) {
    if (operation is PowerNumberTransform<T>) {
      final result = operation.tryApply(value);
      if (result == null) {
        sink.addIssue(
          'transform',
          parameters: {'operation': 'pow', 'exponent': operation.exponent},
        );
      }
      return result;
    }
    return operation.apply(value);
  }

  AcanthisOutcome<T> finish(T value) => sink.isEmpty
      ? AcanthisValid<T>(value)
      : AcanthisInvalid<T>(sink.takeIssues(), value: value);
}

sealed class _NumericStep<T extends num> {
  const _NumericStep();
}

final class _CheckStep<T extends num> extends _NumericStep<T> {
  const _CheckStep(this.operation);
  final Check<T> operation;
}

final class _AsyncCheckStep<T extends num> extends _NumericStep<T> {
  const _AsyncCheckStep(this.operation);
  final AsyncCheck<T> operation;
}

final class _TransformStep<T extends num> extends _NumericStep<T> {
  const _TransformStep(this.operation);
  final Transform<T, T> operation;
}

final class _AsyncTransformStep<T extends num> extends _NumericStep<T> {
  const _AsyncTransformStep(this.operation);
  final AsyncTransform<T, T> operation;
}

final class _OperationNode<T extends num> {
  _OperationNode(this.previous, this.step)
    : length = (previous?.length ?? 0) + 1,
      isAsync =
          (previous?.isAsync ?? false) ||
          step is _AsyncCheckStep<T> ||
          step is _AsyncTransformStep<T>;
  final _OperationNode<T>? previous;
  final _NumericStep<T> step;
  final int length;
  final bool isAsync;
}

List<_NumericStep<T>> _materialize<T extends num>(_OperationNode<T>? tail) {
  if (tail == null) return const [];
  final steps = List<_NumericStep<T>>.filled(
    tail.length,
    tail.step,
    growable: false,
  );
  var index = steps.length - 1;
  for (_OperationNode<T>? node = tail; node != null; node = node.previous) {
    steps[index--] = node.step;
  }
  return steps;
}
