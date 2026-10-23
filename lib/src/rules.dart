import 'common/issue.dart';
import 'common/validation_scope.dart';

final class AcanthisPath {
  AcanthisPath(Iterable<Object> segments)
    : segments = List.unmodifiable(segments) {
    if (this.segments.isEmpty ||
        this.segments.any(
          (s) => s is! String && s is! int || s is int && s < 0,
        )) {
      throw ArgumentError('Paths require strings or nonnegative integers');
    }
  }
  factory AcanthisPath.from(Object path) => switch (path) {
    AcanthisPath() => path,
    String() => AcanthisPath([path]),
    List<Object>() => AcanthisPath(path),
    _ => throw ArgumentError.value(
      path,
      'path',
      'Expected a field name or segment list',
    ),
  };
  final List<Object> segments;
  bool overlaps(AcanthisPath other) {
    final length = segments.length < other.segments.length
        ? segments.length
        : other.segments.length;
    for (var i = 0; i < length; i++) {
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

final class AcanthisFieldState {
  const AcanthisFieldState(this.status, {this.value, required this.submitted});
  final AcanthisFieldStatus status;
  final Object? value;
  final bool submitted;
}

final class AcanthisRuleInputs {
  AcanthisRuleInputs._(this._states);
  final Map<AcanthisPath, AcanthisFieldState> _states;
  AcanthisFieldState state(Object field) =>
      _states[AcanthisPath.from(field)] ??
      (throw ArgumentError('Undeclared rule input'));
  dynamic operator [](Object path) => value<dynamic>(path);
  T value<T>(Object path) {
    final selected = state(path);
    if (selected.status != AcanthisFieldStatus.valid) {
      throw StateError('Input is not valid');
    }
    return selected.value as T;
  }
}

/// Rules read parsed prerequisites and report only their declared output paths.
final class AcanthisRule<C> {
  AcanthisRule({
    required this.id,
    required Iterable<Object> inputs,
    required Iterable<Object> outputs,
    required this._check,
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
    Object? raw,
    Object? parsed,
    List<AcanthisIssue> issues,
  ) {
    final states = <AcanthisPath, AcanthisFieldState>{};
    for (final path in inputs) {
      if (issues.any(
        (issue) =>
            issue.path.isEmpty || path.overlaps(AcanthisPath(issue.path)),
      )) {
        return null;
      }
      final original = readRulePath(raw, path);
      final result = readRulePath(parsed, path);
      if (!result.present && !allowMissing) return null;
      states[path] = AcanthisFieldState(
        result.present
            ? AcanthisFieldStatus.valid
            : AcanthisFieldStatus.missing,
        value: result.value,
        submitted: original.present,
      );
    }
    final selected = AcanthisRuleInputs._(states);
    final scope = AcanthisValidationScope.current;
    scope.throwIfCancelled();
    if (_when != null && !_when(selected, scope.context as C)) return null;
    scope.throwIfCancelled();
    return selected;
  }

  List<AcanthisIssue> _verify(List<AcanthisIssue> issues) {
    AcanthisValidationScope.current.throwIfCancelled();
    for (final issue in issues) {
      if (issue.path.isEmpty || !outputs.contains(AcanthisPath(issue.path))) {
        throw StateError('Rule $id emitted an undeclared issue path');
      }
    }
    return List.unmodifiable(issues);
  }

  List<AcanthisIssue> evaluate(
    Object? raw,
    Object? parsed,
    List<AcanthisIssue> issues,
  ) {
    if (isAsync) throw StateError('Async rule requires async validation');
    final selected = _select(raw, parsed, issues);
    return selected == null
        ? const []
        : _verify(
            _check!(selected, AcanthisValidationScope.current.context as C),
          );
  }

  Future<List<AcanthisIssue>> evaluateAsync(
    Object? raw,
    Object? parsed,
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

({bool present, Object? value}) readRulePath(Object? value, AcanthisPath path) {
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

/// Legacy dependencies intentionally read raw values and do not gate on validity.
final class AcanthisFieldDependency {
  const AcanthisFieldDependency(this.dependent, this.dependsOn, this.check);
  final String dependent;
  final String dependsOn;
  final bool Function(dynamic, dynamic) check;
  Object? _read(Object? value, String query) {
    for (final part in query.split('.')) {
      if (value is Map) {
        value = value[part];
      } else if (value is List) {
        final index = int.tryParse(
          part.replaceAll('[', '').replaceAll(']', ''),
        );
        if (index == null || index < 0 || index >= value.length) return null;
        value = value[index];
      } else {
        return null;
      }
    }
    return value;
  }

  List<AcanthisIssue> evaluate(Object? raw) {
    final from = _read(raw, dependsOn);
    final to = _read(raw, dependent);
    final valid = from != null && to != null && check(from, to);
    AcanthisValidationScope.current.throwIfCancelled();
    return valid
        ? const []
        : [
            AcanthisIssue(
              path: [dependent],
              code: 'dependency',
              parameters: {'dependsOn': dependsOn},
            ),
          ];
  }
}
