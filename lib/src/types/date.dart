import '../registries/metadata_registry.dart';
import '../common/validation_scope.dart';

import 'package:acanthis/src/validators/date.dart';

import '../common/issue_sink.dart';
import '../common/operations.dart';
import '../common/results.dart';
import '../common/schema.dart';
import '../common/fast_schema.dart';
import 'list.dart';
import 'nullable.dart';

/// An immutable ordered string schema. Parsing contexts belong to invocations.
/// [parse] stops after the first failing operation; [tryParse] collects checks
/// on the current value, stopping at a transformation boundary after failure.
final class AcanthisDate extends Schema<DateTime, DateTime>
    with
        CheckableSchema<DateTime, DateTime>,
        TransformableSchema<DateTime, DateTime>,
        ValidationSchema<DateTime, DateTime>,
        AsyncSchema<DateTime, DateTime>,
        DefaultSchema<DateTime, DateTime>,
        ListableSchema<DateTime, DateTime>,
        NullableSchema<DateTime, DateTime>
    implements FastSchema<DateTime> {
  AcanthisDate({this.coercionEnabled = false, this.defaultValue})
    : _tail = null;

  AcanthisDate._(this._tail, this.coercionEnabled, this.defaultValue);

  final _OperationNode? _tail;
  final bool coercionEnabled;
  @override
  final DateTime? defaultValue;
  bool get isIdentity => _tail == null && !coercionEnabled && !hasDefault;
  late final bool _fastEligible =
      !coercionEnabled &&
      _steps.every((step) => step is _CheckStep && step.operation is DateCheck);
  @override
  bool get canFast => isIdentity || _fastEligible;
  @override
  DateTime? tryFast(Object? input) {
    if (!canFast) return null;
    input ??= defaultValue;
    if (input is! DateTime) return null;
    for (final step in _steps) {
      if (!((step as _CheckStep).operation as DateCheck).test(input)) {
        return null;
      }
    }
    return input;
  }

  // Fluent calls share immutable nodes. Only a schema that executes or exposes
  // its definition materializes the ordered fixed-length plan, once.
  late final List<_DateStep> _steps = _materialize(_tail);

  @override
  late final List<Check<DateTime>> checks = List.unmodifiable(
    _steps.whereType<_CheckStep>().map((step) => step.operation),
  );

  @override
  late final List<Transform<DateTime, DateTime>> transformations =
      List.unmodifiable(
        _steps.whereType<_TransformStep>().map((step) => step.operation),
      );

  late final List<AsyncCheck<DateTime>> asyncChecks = List.unmodifiable(
    _steps.whereType<_AsyncCheckStep>().map((step) => step.operation),
  );

  @override
  bool get isAsync => _tail?.isAsync ?? false;

  AcanthisDate _append(_DateStep step) => copySchemaMetadata(
    this,
    AcanthisDate._(_OperationNode(_tail, step), coercionEnabled, defaultValue),
  );

  @override
  AcanthisDate withCheck(Check<DateTime> check) => _append(_CheckStep(check));

  @override
  AcanthisDate refine({
    required bool Function(DateTime) onCheck,
    String? error,
    String name = 'custom',
  }) => withCheck(
    PredicateCheck<DateTime>.refinement(
      onCheck: onCheck,
      error: error,
      name: name,
    ),
  );

  AcanthisDate refineAsync(AsyncCheck<DateTime> check) =>
      _append(_AsyncCheckStep(check));

  @override
  AcanthisDate transform(DateTime Function(DateTime) onTransform) =>
      withTransform(CallbackTransform<DateTime, DateTime>(onTransform));

  @override
  AcanthisDate withTransform(Transform<DateTime, DateTime> transform) =>
      _append(_TransformStep(transform));

  AcanthisDate transformAsync(AsyncTransform<DateTime, DateTime> transform) =>
      _append(_AsyncTransformStep(transform));

  AcanthisDate coerce() =>
      copySchemaMetadata(this, AcanthisDate._(_tail, true, defaultValue));
  @override
  AcanthisDate meta(MetadataEntry<DateTime> metadata) => attachSchemaMetadata(
    copySchemaMetadata(
      this,
      AcanthisDate._(_tail, coercionEnabled, defaultValue),
    ),
    metadata,
  );

  AcanthisDate withDefault(DateTime value) =>
      copySchemaMetadata(this, AcanthisDate._(_tail, coercionEnabled, value));

  @override
  DateTime parse(Object? input) => parseOutcome(input).valueOrThrow;

  @override
  AcanthisOutcome<DateTime> parseOutcome(Object? input) =>
      _run(input, collect: false);

  @override
  AcanthisOutcome<DateTime> tryParse(Object? input) =>
      _run(input, collect: true);

  @override
  Future<DateTime> parseAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).valueOrThrow;

  @override
  Future<AcanthisOutcome<DateTime>> parseOutcomeAsync(Object? input) =>
      _runAsync(input, collect: false);

  @override
  Future<AcanthisOutcome<DateTime>> tryParseAsync(Object? input) =>
      _runAsync(input, collect: true);

  @override
  bool validate(Object? input) => parseOutcome(input).isValid;

  @override
  bool tryValidate(Object? input) => tryParse(input).isValid;

  Future<bool> validateAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).isValid;

  Future<bool> tryValidateAsync(Object? input) async =>
      (await tryParseAsync(input)).isValid;

  DateTime? _decodeInput(Object? input) {
    input ??= defaultValue;
    if (input is DateTime) return input;
    if (input is String) return DateTime.tryParse(input);
    if (coercionEnabled && (input is num)) {
      // DateTime supports at most 100,000,000 days on either side of the epoch.
      const maxMilliseconds = 8640000000000000;
      if (!input.isFinite ||
          input < -maxMilliseconds ||
          input > maxMilliseconds) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(input.toInt());
    }
    return null;
  }

  AcanthisOutcome<DateTime> _invalidInput() => AcanthisInvalid.withoutValue(
    IssueSink.single(
      'type',
      parameters: const {'expected': 'DateTime'},
    ).takeIssues(),
  );

  AcanthisOutcome<DateTime> _run(Object? input, {required bool collect}) {
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    collect = collect && scope.fieldPolicy == AcanthisCollectionPolicy.all;
    if (isAsync) throw StateError('This schema requires an async parse method');
    final decoded = _decodeInput(input);
    if (decoded == null) return _invalidInput();
    var value = decoded;
    if (_tail == null) return AcanthisValid(value);
    final run = _DateRun();
    for (final step in _steps) {
      scope.throwIfCancelled();
      switch (step) {
        case _CheckStep(:final operation):
          run.check(value, operation);
        case _TransformStep(:final operation):
          if (run.sink.isNotEmpty) return run.finish(value);
          final transformed = run.transform(value, operation);
          if (transformed == null) return run.finish(value);
          value = transformed;
        case _AsyncCheckStep() || _AsyncTransformStep():
          throw StateError('Async step in synchronous execution');
      }
      scope.throwIfCancelled();
      if (!collect && run.sink.isNotEmpty) break;
    }
    return run.finish(value);
  }

  Future<AcanthisOutcome<DateTime>> _runAsync(
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
    final run = _DateRun();
    for (final step in _steps) {
      scope.throwIfCancelled();
      switch (step) {
        case _CheckStep(:final operation):
          run.check(value, operation);
        case _AsyncCheckStep(:final operation):
          await operation.evaluate(value, run.context);
        case _TransformStep(:final operation):
          if (run.sink.isNotEmpty) return run.finish(value);
          final transformed = run.transform(value, operation);
          if (transformed == null) return run.finish(value);
          value = transformed;
        case _AsyncTransformStep(:final operation):
          if (run.sink.isNotEmpty) return run.finish(value);
          value = await operation.apply(value);
      }
      scope.throwIfCancelled();
      if (!collect && run.sink.isNotEmpty) break;
    }
    return run.finish(value);
  }

  /// Minimum date (inclusive) check;
  AcanthisDate min(DateTime value) => withCheck(MinDateCheck(value));

  /// Maximum date (inclusive) check;
  AcanthisDate max(DateTime value) => withCheck(MaxDateCheck(value));

  /// Minimum difference from now check;
  AcanthisDate differsFromNow(Duration difference) =>
      withCheck(DiffersFromNowCheck(difference));

  /// Minimum difference from a specific date check;
  AcanthisDate differsFrom(DateTime fromDate, Duration difference) =>
      withCheck(DiffersFromCheck(fromDate, difference));
}

/// Construct a strict date schema; opt into scalar/string coercion with coerce().
AcanthisDate date() => AcanthisDate();

final class _DateRun {
  final IssueSink sink = IssueSink();
  late final CheckContext context = CheckContext.createContext(sink);

  void check(DateTime value, Check<DateTime> operation) {
    if (operation is DateCheck) {
      if (!operation.test(value)) {
        sink.addIssue(operation.code, parameters: operation.parameters);
      }
    } else {
      operation.evaluate(value, context);
    }
  }

  DateTime? transform(DateTime value, Transform<DateTime, DateTime> operation) {
    return operation.apply(value);
  }

  AcanthisOutcome<DateTime> finish(DateTime value) => sink.isEmpty
      ? AcanthisValid(value)
      : AcanthisInvalid(sink.takeIssues(), value: value);
}

sealed class _DateStep {
  const _DateStep();
}

final class _CheckStep extends _DateStep {
  const _CheckStep(this.operation);
  final Check<DateTime> operation;
}

final class _AsyncCheckStep extends _DateStep {
  const _AsyncCheckStep(this.operation);
  final AsyncCheck<DateTime> operation;
}

final class _TransformStep extends _DateStep {
  const _TransformStep(this.operation);
  final Transform<DateTime, DateTime> operation;
}

final class _AsyncTransformStep extends _DateStep {
  const _AsyncTransformStep(this.operation);
  final AsyncTransform<DateTime, DateTime> operation;
}

final class _OperationNode {
  _OperationNode(this.previous, this.step)
    : length = (previous?.length ?? 0) + 1,
      isAsync =
          (previous?.isAsync ?? false) ||
          step is _AsyncCheckStep ||
          step is _AsyncTransformStep;
  final _OperationNode? previous;
  final _DateStep step;
  final int length;
  final bool isAsync;
}

List<_DateStep> _materialize(_OperationNode? tail) {
  if (tail == null) return const [];
  final steps = List<_DateStep>.filled(tail.length, tail.step, growable: false);
  _OperationNode? node = tail;
  for (var index = steps.length - 1; index >= 0; index--) {
    steps[index] = node!.step;
    node = node.previous;
  }
  return steps;
}
