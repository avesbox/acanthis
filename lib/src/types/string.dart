import '../registries/metadata_registry.dart';
import '../common/validation_scope.dart';
import '../common/issue_sink.dart';
import '../common/operations.dart';
import '../common/results.dart';
import '../common/schema.dart';
import '../common/fast_schema.dart';
import '../transformations/string.dart';
import '../validators/common.dart';
import '../validators/string.dart';
import 'list.dart';
import 'nullable.dart';

/// An immutable ordered string schema. Parsing contexts belong to invocations.
/// [parse] stops after the first failing operation; [tryParse] collects checks
/// on the current value, stopping at a transformation boundary after failure.
final class AcanthisString extends Schema<String, String>
    with
        CheckableSchema<String, String>,
        TransformableSchema<String, String>,
        ValidationSchema<String, String>,
        AsyncSchema<String, String>,
        DefaultSchema<String, String>,
        ListableSchema<String, String>,
        NullableSchema<String, String>
    implements FastSchema<String> {
  AcanthisString({this.coercionEnabled = false, this.defaultValue})
    : _tail = null;

  AcanthisString._(this._tail, this.coercionEnabled, this.defaultValue);

  final _OperationNode? _tail;
  final bool coercionEnabled;
  @override
  final String? defaultValue;
  bool get isIdentity => _tail == null && !coercionEnabled && !hasDefault;
  late final bool _fastEligible =
      !coercionEnabled &&
      _steps.every(
        (step) => step is _CheckStep && step.operation is StringCheck,
      );
  @override
  bool get canFast => isIdentity || _fastEligible;
  @override
  String? tryFast(Object? input) {
    if (!canFast) return null;
    input ??= defaultValue;
    if (input is! String) return null;
    for (final step in _steps) {
      if (!((step as _CheckStep).operation as StringCheck).test(input)) {
        return null;
      }
    }
    return input;
  }

  // Fluent calls share immutable nodes. Only a schema that executes or exposes
  // its definition materializes the ordered fixed-length plan, once.
  late final List<_StringStep> _steps = _materialize(_tail);

  @override
  late final List<Check<String>> checks = List.unmodifiable(
    _steps.whereType<_CheckStep>().map((step) => step.operation),
  );

  @override
  late final List<Transform<String, String>> transformations =
      List.unmodifiable(
        _steps.whereType<_TransformStep>().map((step) => step.operation),
      );

  late final List<AsyncCheck<String>> asyncChecks = List.unmodifiable(
    _steps.whereType<_AsyncCheckStep>().map((step) => step.operation),
  );

  @override
  bool get isAsync => _tail?.isAsync ?? false;

  AcanthisString _append(_StringStep step) => copySchemaMetadata(
    this,
    AcanthisString._(
      _OperationNode(_tail, step),
      coercionEnabled,
      defaultValue,
    ),
  );

  @override
  AcanthisString withCheck(Check<String> check) => _append(_CheckStep(check));

  @override
  AcanthisString refine({
    required bool Function(String) onCheck,
    String? error,
    String name = 'custom',
  }) => withCheck(
    PredicateCheck<String>.refinement(
      onCheck: onCheck,
      error: error,
      name: name,
    ),
  );

  AcanthisString refineAsync(AsyncCheck<String> check) =>
      _append(_AsyncCheckStep(check));

  @override
  AcanthisString transform(String Function(String) onTransform) =>
      withTransform(CallbackTransform<String, String>(onTransform));

  @override
  AcanthisString withTransform(Transform<String, String> transform) =>
      _append(_TransformStep(transform));

  AcanthisString transformAsync(AsyncTransform<String, String> transform) =>
      _append(_AsyncTransformStep(transform));

  AcanthisString coerce() =>
      copySchemaMetadata(this, AcanthisString._(_tail, true, defaultValue));
  @override
  AcanthisString meta(MetadataEntry<String> metadata) => attachSchemaMetadata(
    copySchemaMetadata(
      this,
      AcanthisString._(_tail, coercionEnabled, defaultValue),
    ),
    metadata,
  );

  AcanthisString withDefault(String value) =>
      copySchemaMetadata(this, AcanthisString._(_tail, coercionEnabled, value));

  AcanthisString email() => withCheck(EmailStringCheck());
  AcanthisString min(int length) => withCheck(MinStringLengthCheck(length));
  AcanthisString max(int length) => withCheck(MaxStringLengthCheck(length));
  AcanthisString length(int length) =>
      withCheck(ExactStringLengthCheck(length));
  AcanthisString pattern(Pattern pattern) =>
      withCheck(PatternStringCheck(pattern));
  AcanthisString letters({bool strict = true}) =>
      withCheck(PatternLettersStringChecks(strict: strict));
  AcanthisString digits({bool strict = true}) =>
      withCheck(PatternDigitsStringChecks(strict: strict));
  AcanthisString alphanumeric({bool strict = true}) =>
      withCheck(PatternAlphanumericStringChecks(strict: strict));
  AcanthisString alphanumericWithSpaces({bool strict = true}) =>
      withCheck(PatternAlphanumericWithSpacesStringChecks(strict: strict));
  AcanthisString specialCharacters({bool strict = true}) =>
      withCheck(PatternSpecialCharactersStringChecks(strict: strict));
  AcanthisString allCharacters({bool strict = true}) =>
      withCheck(PatternAllCharactersStringChecks(strict: strict));
  AcanthisString upperCase() => withCheck(UpperCaseStringCheck());
  AcanthisString lowerCase() => withCheck(LowerCaseStringCheck());
  AcanthisString mixedCase() => withCheck(MixedCaseStringCheck());
  AcanthisString dateTime() => withCheck(DateTimeStringCheck());
  AcanthisString time() => withCheck(PatternTimeStringChecks());
  AcanthisString hexColor() => withCheck(PatternHexColorStringChecks());
  AcanthisString uri() => withCheck(UriStringCheck());
  AcanthisString url() => withCheck(UrlStringCheck());
  AcanthisString uncompromised({PasswordRangeLookup? lookup}) =>
      refineAsync(UncompromisedStringCheck(lookup: lookup));
  AcanthisString required() => withCheck(RequiredStringCheck());
  AcanthisString notEmpty() => withCheck(NotEmptyStringCheck());
  AcanthisString contains(String value) =>
      withCheck(ContainsStringCheck(value));
  AcanthisString startsWith(String value) =>
      withCheck(StartsWithStringCheck(value));
  AcanthisString endsWith(String value) =>
      withCheck(EndsWithStringCheck(value));
  AcanthisString card() => withCheck(CardStringCheck());
  AcanthisString enumerated<T extends Enum>(
    List<T> values, {
    String Function(String)? nameTransformer,
  }) => withCheck(
    EnumeratedStringCheck(enumValues: values, nameTransformer: nameTransformer),
  );
  AcanthisString contained(Iterable<String> values) =>
      withCheck(ContainedStringCheck(values: values));
  AcanthisString cuid() => withCheck(PatternCuidStringChecks());
  AcanthisString cuid2() => withCheck(PatternCuid2StringChecks());
  AcanthisString ulid() => withCheck(PatternUlidStringChecks());
  AcanthisString uuid() => withCheck(PatternUuidStringChecks());
  AcanthisString nanoid() => withCheck(PatternNanoidStringChecks());
  AcanthisString jwt() => withCheck(PatternJwtStringChecks());
  AcanthisString base64() => withCheck(PatternBase64StringChecks());
  AcanthisString exact(String value) =>
      withCheck(ExactCheck<String>(value: value));

  AcanthisString encode() => withTransform(const EncodeStringTransform());
  AcanthisString decode() => withTransform(const DecodeStringTransform());
  AcanthisString toUpperCase() =>
      withTransform(const UpperCaseStringTransform());
  AcanthisString toLowerCase() =>
      withTransform(const LowerCaseStringTransform());
  AcanthisString trim() => withTransform(const TrimStringTransform());

  @override
  String parse(Object? input) => parseOutcome(input).valueOrThrow;

  @override
  AcanthisOutcome<String> parseOutcome(Object? input) =>
      _run(input, collect: false);

  @override
  AcanthisOutcome<String> tryParse(Object? input) => _run(input, collect: true);

  @override
  Future<String> parseAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).valueOrThrow;

  @override
  Future<AcanthisOutcome<String>> parseOutcomeAsync(Object? input) =>
      _runAsync(input, collect: false);

  @override
  Future<AcanthisOutcome<String>> tryParseAsync(Object? input) =>
      _runAsync(input, collect: true);

  @override
  bool validate(Object? input) => parseOutcome(input).isValid;

  @override
  bool tryValidate(Object? input) => tryParse(input).isValid;

  Future<bool> validateAsync(Object? input) async =>
      (await parseOutcomeAsync(input)).isValid;

  Future<bool> tryValidateAsync(Object? input) async =>
      (await tryParseAsync(input)).isValid;

  String? _decodeInput(Object? input) {
    input ??= defaultValue;
    if (input is String) return input;
    if (coercionEnabled &&
        (input is num || input is bool || input is DateTime)) {
      return input.toString();
    }
    return null;
  }

  AcanthisOutcome<String> _invalidInput() => AcanthisInvalid.withoutValue(
    IssueSink.single(
      'type',
      parameters: const {'expected': 'String'},
    ).takeIssues(),
  );

  AcanthisOutcome<String> _run(Object? input, {required bool collect}) {
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    collect = collect && scope.fieldPolicy == AcanthisCollectionPolicy.all;
    if (isAsync) throw StateError('This schema requires an async parse method');
    final decoded = _decodeInput(input);
    if (decoded == null) return _invalidInput();
    var value = decoded;
    if (_tail == null) return AcanthisValid(value);
    final run = _StringRun();
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

  Future<AcanthisOutcome<String>> _runAsync(
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
    final run = _StringRun();
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
}

/// Construct a strict string schema; opt into scalar/date coercion with coerce().
AcanthisString string() => AcanthisString();

final class _StringRun {
  final IssueSink sink = IssueSink();
  late final CheckContext context = CheckContext.createContext(sink);

  void check(String value, Check<String> operation) {
    if (operation is StringCheck) {
      if (!operation.test(value)) {
        sink.addIssue(operation.code, parameters: operation.parameters);
      }
    } else {
      operation.evaluate(value, context);
    }
  }

  String? transform(String value, Transform<String, String> operation) {
    if (operation is DecodeStringTransform) {
      try {
        return operation.apply(value);
      } on FormatException {
        sink.addIssue('transform', parameters: const {'operation': 'decode'});
        return null;
      }
    }
    return operation.apply(value);
  }

  AcanthisOutcome<String> finish(String value) => sink.isEmpty
      ? AcanthisValid(value)
      : AcanthisInvalid(sink.takeIssues(), value: value);
}

sealed class _StringStep {
  const _StringStep();
}

final class _CheckStep extends _StringStep {
  const _CheckStep(this.operation);
  final Check<String> operation;
}

final class _AsyncCheckStep extends _StringStep {
  const _AsyncCheckStep(this.operation);
  final AsyncCheck<String> operation;
}

final class _TransformStep extends _StringStep {
  const _TransformStep(this.operation);
  final Transform<String, String> operation;
}

final class _AsyncTransformStep extends _StringStep {
  const _AsyncTransformStep(this.operation);
  final AsyncTransform<String, String> operation;
}

final class _OperationNode {
  _OperationNode(this.previous, this.step)
    : length = (previous?.length ?? 0) + 1,
      isAsync =
          (previous?.isAsync ?? false) ||
          step is _AsyncCheckStep ||
          step is _AsyncTransformStep;
  final _OperationNode? previous;
  final _StringStep step;
  final int length;
  final bool isAsync;
}

List<_StringStep> _materialize(_OperationNode? tail) {
  if (tail == null) return const [];
  final steps = List<_StringStep>.filled(
    tail.length,
    tail.step,
    growable: false,
  );
  _OperationNode? node = tail;
  for (var index = steps.length - 1; index >= 0; index--) {
    steps[index] = node!.step;
    node = node.previous;
  }
  return steps;
}
