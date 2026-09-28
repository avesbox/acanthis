import 'dart:async';

import 'package:acanthis/acanthis.dart';

/// Independent collection policies for field operations and object children.
enum AcanthisCollectionPolicy { all, first }

/// Cooperative cancellation. Futures already running are not forcibly stopped.
class AcanthisCancellationSignal {
  bool _cancelled = false;
  final Completer<void> _done = Completer<void>();
  bool get isCancelled => _cancelled;
  Future<void> get whenCancelled => _done.future;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _done.complete();
  }
}

/// Per-call settings inherited by nested schemas and async continuations.
/// Context objects should be immutable; no process-wide state is changed.
class AcanthisValidationScope {
  const AcanthisValidationScope({
    this.context,
    this.fieldPolicy = AcanthisCollectionPolicy.all,
    this.objectPolicy = AcanthisCollectionPolicy.all,
    this.cancellation,
  });
  final Object? context;
  final AcanthisCollectionPolicy fieldPolicy;
  final AcanthisCollectionPolicy objectPolicy;
  final AcanthisCancellationSignal? cancellation;
  static final Object _key = Object();
  static AcanthisValidationScope get current =>
      Zone.current[_key] as AcanthisValidationScope? ??
      const AcanthisValidationScope();
  T contextAs<T>() => context as T;
  R run<R>(R Function() action) => runZoned(action, zoneValues: {_key: this});
}

/// Immutable data path. Integers address list elements; strings address keys.
class AcanthisPath {
  AcanthisPath(Iterable<Object> segments)
    : segments = List.unmodifiable(segments) {
    if (this.segments.isEmpty ||
        this.segments.any(
          (s) => s is! String && s is! int || s is int && s < 0,
        )) {
      throw ArgumentError('Paths require strings or nonnegative integers');
    }
  }

  /// Normalizes a field name, segment list, or an existing immutable path.
  /// Strings are literal keys: 'user.name' does not mean ['user', 'name'].
  factory AcanthisPath.from(Object path) => switch (path) {
    AcanthisPath() => path,
    String() => AcanthisPath([path]),
    List<Object>() => AcanthisPath(path),
    _ => throw ArgumentError.value(
      path,
      'path',
      'Expected a field name, segment list, or AcanthisPath',
    ),
  };

  final List<Object> segments;
  bool overlaps(AcanthisPath other) {
    final n = segments.length < other.segments.length
        ? segments.length
        : other.segments.length;
    for (var i = 0; i < n; i++) {
      if (segments[i] != other.segments[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is AcanthisPath &&
      segments.length == other.segments.length &&
      overlaps(other);
  @override
  int get hashCode => Object.hashAll(segments);
}

enum AcanthisFieldStatus { missing, invalid, pending, valid }

/// A selected parsed input with independent submitted-presence information.
class AcanthisFieldState {
  const AcanthisFieldState(this.status, {this.value, required this.submitted});
  final AcanthisFieldStatus status;
  final Object? value;
  final bool submitted;
}

/// Read access is restricted to the paths declared by the rule.
class AcanthisRuleInputs {
  AcanthisRuleInputs(this._states);
  final Map<AcanthisPath, AcanthisFieldState> _states;
  AcanthisFieldState state(Object field) {
    final path = AcanthisPath.from(field);
    if (!_states.containsKey(path)) {
      throw ArgumentError('Undeclared rule input');
    }
    return _states[path]!;
  }

  /// Reads a declared valid input. Use [state] to inspect optional presence.
  dynamic operator [](Object path) => value<dynamic>(path);

  T value<T>(Object path) {
    final selected = state(path);
    if (selected.status != AcanthisFieldStatus.valid) {
      throw StateError('Input is not valid');
    }
    return selected.value as T;
  }
}

/// Selected-field rule. Callbacks see parsed inputs and exceptions propagate.
/// Missing inputs skip ordinary rules; [allowMissing] enables presence rules.
/// Invalid prerequisites always skip. Rule issues never gate another rule.
class AcanthisRule<C> {
  AcanthisRule({
    required this.id,
    required Iterable<Object> inputs,
    required Iterable<Object> outputs,
    required List<AcanthisIssue> Function(AcanthisRuleInputs, C) this._check,
    this.allowMissing = false,
    this._when,
  }) : inputs = List.unmodifiable(inputs.map(AcanthisPath.from)),
       outputs = List.unmodifiable(outputs.map(AcanthisPath.from)),
       _asyncCheck = null;
  AcanthisRule.async({
    required this.id,
    required Iterable<Object> inputs,
    required Iterable<Object> outputs,
    required Future<List<AcanthisIssue>> Function(AcanthisRuleInputs, C) check,
    this.allowMissing = false,
    this._when,
  }) : inputs = List.unmodifiable(inputs.map(AcanthisPath.from)),
       outputs = List.unmodifiable(outputs.map(AcanthisPath.from)),
       _check = null,
       _asyncCheck = check;
  final String id;
  final List<AcanthisPath> inputs;
  final List<AcanthisPath> outputs;
  final bool allowMissing;
  final List<AcanthisIssue> Function(AcanthisRuleInputs, C)? _check;
  final Future<List<AcanthisIssue>> Function(AcanthisRuleInputs, C)?
  _asyncCheck;
  final bool Function(AcanthisRuleInputs, C)? _when;
  bool get isAsync => _asyncCheck != null;

  AcanthisRuleInputs? _select(
    Map<String, dynamic> raw,
    Map<String, dynamic> parsed,
    List<AcanthisIssue> issues,
  ) {
    final states = <AcanthisPath, AcanthisFieldState>{};
    for (final path in inputs) {
      final original = readPath(raw, path);
      final result = readPath(parsed, path);
      final invalid = issues.any(
        (issue) =>
            issue.path.isEmpty || path.overlaps(AcanthisPath(issue.path)),
      );
      final status = invalid
          ? AcanthisFieldStatus.invalid
          : result.present
          ? AcanthisFieldStatus.valid
          : AcanthisFieldStatus.missing;
      if (invalid || (!allowMissing && status == AcanthisFieldStatus.missing)) {
        return null;
      }
      states[path] = AcanthisFieldState(
        status,
        value: invalid ? null : result.value,
        submitted: original.present,
      );
    }
    final selected = AcanthisRuleInputs(states);
    if (_when != null &&
        !_when(selected, AcanthisValidationScope.current.context as C)) {
      return null;
    }
    return selected;
  }

  List<AcanthisIssue> _verify(List<AcanthisIssue> issues) {
    for (final issue in issues) {
      if (issue.path.isEmpty || !outputs.contains(AcanthisPath(issue.path))) {
        throw StateError('Rule $id emitted an undeclared issue path');
      }
    }
    return List.unmodifiable(issues);
  }

  /// Internal reference evaluator shared with live scheduling.
  List<AcanthisIssue> evaluate(
    Map<String, dynamic> raw,
    Map<String, dynamic> parsed,
    List<AcanthisIssue> issues,
  ) {
    final selected = _select(raw, parsed, issues);
    if (selected == null) return const [];
    if (isAsync) {
      throw AsyncValidationException('Async rule requires async validation');
    }
    return _verify(
      _check!(selected, AcanthisValidationScope.current.context as C),
    );
  }

  Future<List<AcanthisIssue>> evaluateAsync(
    Map<String, dynamic> raw,
    Map<String, dynamic> parsed,
    List<AcanthisIssue> issues,
  ) async {
    final selected = _select(raw, parsed, issues);
    if (selected == null) return const [];
    final context = AcanthisValidationScope.current.context as C;
    return _verify(
      isAsync
          ? await _asyncCheck!(selected, context)
          : _check!(selected, context),
    );
  }
}

/// Reads a path without conflating omission with explicit null.
({bool present, dynamic value}) readPath(dynamic value, AcanthisPath path) {
  for (final segment in path.segments) {
    if (value is Map && value.containsKey(segment)) {
      value = value[segment];
    } else if (value is List && segment is int && segment < value.length) {
      value = value[segment];
    } else {
      return (present: false, value: null);
    }
  }
  return (present: true, value: value);
}
