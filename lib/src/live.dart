import 'dart:async';
import 'dart:collection';

import 'common/issue.dart';
import 'common/object_evaluation.dart';
import 'common/results.dart';
import 'common/validation_scope.dart';
import 'rules.dart';
import 'types/object.dart';

/// A set or removal in a batch. List removal shifts subsequent indices.
class AcanthisEdit {
  AcanthisEdit.set(Object path, this.value)
    : path = AcanthisPath.from(path),
      remove = false;
  AcanthisEdit.remove(Object path)
    : path = AcanthisPath.from(path),
      value = null,
      remove = true;
  final AcanthisPath path;
  final dynamic value;
  final bool remove;
}

/// A revision-specific result. Superseded or disposed revisions are not settled.
class AcanthisValidationDelta {
  const AcanthisValidationDelta({
    required this.changedIssues,
    required this.executedFields,
    required this.fullValidation,
    required this.validated,
    this.addedIssues = const [],
    this.removedIssues = const [],
    this.executedRules = const {},
    this.issues = const [],
    this.input = const {},
    this.revision = 0,
    this.isCurrent = true,
    this.settled = true,
  });
  final List<AcanthisIssue> changedIssues;
  final List<AcanthisIssue> addedIssues;
  final List<AcanthisIssue> removedIssues;
  final List<AcanthisIssue> issues;
  final Set<String> executedFields;
  final Set<String> executedRules;
  final bool fullValidation;
  final Map<String, Object?>? validated;
  final Map<String, dynamic> input;
  final int revision;
  final bool isCurrent;
  final bool settled;
}

// JSON-like collections are copied on entry and frozen on publication. Domain
// objects are opaque: callers must treat them and context as immutable.
dynamic _copy(dynamic value, {bool freeze = false}) {
  final active = HashSet<Object>.identity();
  var nodes = 0;
  dynamic visit(dynamic value, int depth) {
    if (++nodes > 100000 || depth > 128) {
      throw ArgumentError('Live input exceeds the snapshot limit');
    }
    if (value is! Map && value is! List) return value;
    if (!active.add(value)) throw ArgumentError('Live input contains a cycle');
    try {
      if (value is Map) {
        final result = value is Map<String, dynamic>
            ? <String, dynamic>{
                for (final key in value.keys) key: visit(value[key], depth + 1),
              }
            : <dynamic, dynamic>{
                for (final key in value.keys) key: visit(value[key], depth + 1),
              };
        return freeze
            ? (result is Map<String, dynamic>
                  ? Map<String, dynamic>.unmodifiable(result)
                  : Map<dynamic, dynamic>.unmodifiable(result))
            : result;
      }
      final result = [for (final item in value as List) visit(item, depth + 1)];
      return freeze ? List<dynamic>.unmodifiable(result) : result;
    } finally {
      active.remove(value);
    }
  }

  return visit(value, 0);
}

// Preserve the runtime types of schema outputs (including List<int>, DTOs).
// Parsed values follow the schema's ordinary ownership contract.
Map<String, Object?> _freeze(Map<String, Object?> value) =>
    Map<String, Object?>.unmodifiable(value);

Map<String, dynamic> _freezeInput(Map<String, dynamic> value) =>
    _copy(value, freeze: true) as Map<String, dynamic>;

Map<String, dynamic> _apply(
  Map<String, dynamic> input,
  List<AcanthisEdit> edits,
) {
  final next = _copy(input) as Map<String, dynamic>;
  for (final edit in edits) {
    dynamic node = next;
    final segments = edit.path.segments;
    for (final segment in segments.take(segments.length - 1)) {
      if (node is Map && node.containsKey(segment)) {
        node = node[segment];
      } else if (node is List && segment is int && segment < node.length) {
        node = node[segment];
      } else {
        throw ArgumentError('Edit parent does not exist');
      }
    }
    final key = segments.last;
    if (node is Map && key is String) {
      if (edit.remove) {
        node.remove(key);
      } else {
        node[key] = _copy(edit.value);
      }
    } else if (node is List && key is int && key < node.length) {
      if (edit.remove) {
        node.removeAt(key);
      } else {
        node[key] = _copy(edit.value);
      }
    } else if (node is List && key == node.length && !edit.remove) {
      node.add(_copy(edit.value));
    } else {
      throw ArgumentError('Invalid edit destination');
    }
  }
  return _copy(next) as Map<String, dynamic>;
}

class _SessionState {
  _SessionState(this.schema, Map<String, dynamic> initial, this.scope)
    : input = _copy(initial) as Map<String, dynamic>;
  final ObjectSchema schema;
  AcanthisValidationScope scope;
  Map<String, dynamic> input;
  int revision = 0;
  List<AcanthisIssue> issues = const [];
  Map<String, Object?>? validated;
  Map<String, AcanthisOutcome<dynamic>> fields = {};
  Map<String, List<AcanthisIssue>> rules = {};
  Set<String> executed = {};
  bool full = true;
  final Set<AcanthisPath> dirty = {};
  bool contextChanged = false;

  bool get fallback =>
      schema.hasOperations ||
      schema.hasCrossFieldDependencies ||
      scope.objectPolicy == AcanthisCollectionPolicy.first;

  void edit(List<AcanthisEdit> edits) {
    input = _apply(
      input,
      edits,
    ); // Validate the entire batch before committing.
    dirty.addAll(edits.map((edit) => edit.path));
    revision++;
  }

  void invalidate(
    Map<String, AcanthisOutcome<dynamic>> fields,
    Map<String, List<AcanthisIssue>> rules,
  ) {
    if (contextChanged || fallback) {
      fields.clear();
      rules.clear();
      return;
    }
    fields.removeWhere(
      (key, _) => dirty.any((path) => path.segments.first == key),
    );
    for (final rule in schema.rules) {
      if (dirty.any(
        (changed) => rule.inputs.any(
          (input) => input.segments.first == changed.segments.first,
        ),
      )) {
        rules.remove(rule.id);
      }
    }
  }

  AcanthisValidationDelta result(
    AcanthisOutcome<Map<String, Object?>> outcome,
    Map<String, dynamic> raw,
    int revision,
    List<AcanthisIssue> before,
    Set<String> executedFields,
    Set<String> executedRules,
    Map<String, AcanthisOutcome<dynamic>> fieldCache,
    Map<String, List<AcanthisIssue>> ruleCache,
  ) {
    final after = outcome is AcanthisInvalid<Map<String, Object?>>
        ? outcome.issues
        : <AcanthisIssue>[];
    final parsed = outcome.isValid ? _freeze(outcome.value) : null;
    final current = revision == this.revision;
    final delta = _delta(
      before,
      after,
      executedFields,
      executedRules,
      fallback,
      parsed,
      raw,
      revision,
      current,
    );
    if (current) {
      issues = List.unmodifiable(after);
      validated = parsed;
      fields = fieldCache;
      rules = ruleCache;
      executed = Set.unmodifiable(executedFields);
      full = fallback;
      dirty.clear();
      contextChanged = false;
    }
    return delta;
  }
}

/// Synchronous editing with dependency-aware field/rule reuse.
class AcanthisLiveSession {
  AcanthisLiveSession._(
    ObjectSchema schema,
    Map<String, dynamic> initial,
    AcanthisValidationScope scope,
  ) : _state = _SessionState(schema, initial, scope) {
    if (schema.isAsync) throw ArgumentError('Use watchAsync for async schemas');
    _validate();
  }
  final _SessionState _state;
  bool _validating = false;
  ObjectSchema get schema => _state.schema;
  Map<String, dynamic> get input => _freezeInput(_state.input);
  Map<String, Object?>? get validated => _state.validated;
  List<AcanthisIssue> get issues => _state.issues;
  int get revision => _state.revision;

  String explain(String field) => !_state.executed.contains(field)
      ? '$field was not affected by the latest update.'
      : _state.full
      ? '$field was rerun because this schema has object-level or cross-field rules.'
      : '$field was rerun because its value changed.';

  AcanthisValidationDelta set(String field, dynamic value) =>
      setPath(AcanthisPath([field]), value);
  AcanthisValidationDelta setPath(Object path, dynamic value) =>
      batch([AcanthisEdit.set(path, value)]);
  AcanthisValidationDelta remove(String field) =>
      removePath(AcanthisPath([field]));
  AcanthisValidationDelta removePath(Object path) =>
      batch([AcanthisEdit.remove(path)]);
  AcanthisValidationDelta batch(List<AcanthisEdit> edits) {
    if (_validating) {
      throw StateError('Cannot edit during synchronous validation');
    }
    _state.scope.throwIfCancelled();
    _state.edit(edits);
    return _validate();
  }

  /// Context changes also invalidate nested checks, whose dependencies are unknown.
  AcanthisValidationDelta updateContext(Object? context) {
    if (_validating) {
      throw StateError('Cannot edit during synchronous validation');
    }
    _state.scope.throwIfCancelled();
    _state.scope = _withContext(_state.scope, context);
    _state.contextChanged = true;
    _state.revision++;
    return _validate();
  }

  AcanthisValidationDelta _validate() {
    _validating = true;
    _state.validated = null;
    final raw = _copy(_state.input) as Map<String, dynamic>;
    final fields = Map<String, AcanthisOutcome<dynamic>>.of(_state.fields);
    final rules = Map<String, List<AcanthisIssue>>.of(_state.rules);
    _state.invalidate(fields, rules);
    final evaluation = ObjectEvaluation(fields, rules);
    try {
      final result = _state.scope.run(() {
        return schema.evaluateObject(raw, evaluation);
      });
      return _state.result(
        result,
        raw,
        revision,
        issues,
        evaluation.executedFields,
        evaluation.executedRules,
        fields,
        rules,
      );
    } finally {
      _validating = false;
    }
  }
}

/// Async editing with debounce, cooperative cancellation, and revision guards.
/// A newer edit cancels the previous signal; stale work cannot publish state.
class AcanthisAsyncLiveSession {
  AcanthisAsyncLiveSession._(
    ObjectSchema schema,
    Map<String, dynamic> initial,
    AcanthisValidationScope scope,
    this.debounce,
  ) : _state = _SessionState(schema, initial, scope);
  final _SessionState _state;
  final Duration debounce;
  AcanthisCancellationSignal? _signal;
  bool _disposed = false;
  Set<String> _pending = const {};
  ObjectSchema get schema => _state.schema;
  int get revision => _state.revision;
  Map<String, dynamic> get input => _freezeInput(_state.input);
  Map<String, Object?>? get validated => _state.validated;
  List<AcanthisIssue> get issues => _state.issues;
  Set<String> get pendingFields => _pending;

  static Future<AcanthisAsyncLiveSession> create(
    ObjectSchema schema,
    Map<String, dynamic> initial, {
    AcanthisValidationScope? scope,
    Duration debounce = Duration.zero,
  }) async {
    if (debounce.isNegative) throw ArgumentError('Debounce cannot be negative');
    final session = AcanthisAsyncLiveSession._(
      schema,
      initial,
      scope ?? AcanthisValidationScope.current,
      debounce,
    );
    await session._validate(delay: false);
    return session;
  }

  Future<AcanthisValidationDelta> set(String field, dynamic value) =>
      setPath(AcanthisPath([field]), value);
  Future<AcanthisValidationDelta> setPath(Object path, dynamic value) =>
      batch([AcanthisEdit.set(path, value)]);
  Future<AcanthisValidationDelta> remove(String field) =>
      removePath(AcanthisPath([field]));
  Future<AcanthisValidationDelta> removePath(Object path) =>
      batch([AcanthisEdit.remove(path)]);
  Future<AcanthisValidationDelta> batch(List<AcanthisEdit> edits) {
    if (_disposed) throw StateError('Session is disposed');
    _state.scope.throwIfCancelled();
    _state.edit(edits);
    return _validate();
  }

  Future<AcanthisValidationDelta> updateContext(Object? context) {
    if (_disposed) throw StateError('Session is disposed');
    _state.scope.throwIfCancelled();
    _state.scope = _withContext(_state.scope, context);
    _state.contextChanged = true;
    _state.revision++;
    return _validate();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _state.validated = null;
    _signal?.cancel();
    _pending = const {};
    _state.revision++;
  }

  Future<AcanthisValidationDelta> _validate({bool delay = true}) async {
    _signal?.cancel();
    final signal = _signal = AcanthisCancellationSignal();
    final unlink = linkCancellation(_state.scope.cancellation, signal);
    final revision = _state.revision;
    final raw = _copy(_state.input) as Map<String, dynamic>;
    final before = _state.issues;
    final full = _state.fallback;
    final fields = Map<String, AcanthisOutcome<dynamic>>.of(_state.fields);
    final rules = Map<String, List<AcanthisIssue>>.of(_state.rules);
    _state.invalidate(fields, rules);
    _pending = Set.unmodifiable(
      schema.fields.keys.where((key) => !fields.containsKey(key)),
    );
    _state.validated = null;
    final scope = AcanthisValidationScope(
      context: _state.scope.context,
      fieldPolicy: _state.scope.fieldPolicy,
      objectPolicy: _state.scope.objectPolicy,
      cancellation: signal,
    );
    final evaluation = ObjectEvaluation(
      fields,
      rules,
      onFieldSettled: (field) {
        if (revision == _state.revision) {
          _pending = Set.unmodifiable(_pending.where((key) => key != field));
        }
      },
    );
    Timer? timer;
    try {
      if (delay && debounce > Duration.zero) {
        final ready = Completer<void>();
        timer = Timer(debounce, ready.complete);
        await Future.any([ready.future, signal.whenCancelled]);
      }
      signal.throwIfCancelled();
      final outcome = await scope.run(() {
        return schema.evaluateObjectAsync(raw, evaluation);
      });
      signal.throwIfCancelled();
      return _state.result(
        outcome,
        raw,
        revision,
        before,
        evaluation.executedFields,
        evaluation.executedRules,
        fields,
        rules,
      );
    } on AcanthisValidationCancelled {
      // Caller cancellation remains control flow; superseded revisions settle quietly.
      _state.scope.cancellation?.throwIfCancelled();
      if (!signal.isCancelled) rethrow;
      return AcanthisValidationDelta(
        changedIssues: const [],
        executedFields: Set.unmodifiable(evaluation.executedFields),
        executedRules: Set.unmodifiable(evaluation.executedRules),
        fullValidation: full,
        validated: null,
        input: _freezeInput(raw),
        revision: revision,
        isCurrent: false,
        settled: false,
      );
    } finally {
      timer?.cancel();
      unlink();
      if (revision == _state.revision) _pending = const {};
    }
  }
}

AcanthisValidationScope _withContext(
  AcanthisValidationScope scope,
  Object? context,
) => AcanthisValidationScope(
  context: context,
  fieldPolicy: scope.fieldPolicy,
  objectPolicy: scope.objectPolicy,
  cancellation: scope.cancellation,
);

extension AcanthisLiveMaps on ObjectSchema {
  AcanthisLiveSession watch(
    Map<String, dynamic> initial, {
    AcanthisValidationScope? scope,
  }) => AcanthisLiveSession._(
    this,
    initial,
    scope ?? AcanthisValidationScope.current,
  );
}

extension AcanthisAsyncLiveMaps on ObjectSchema {
  Future<AcanthisAsyncLiveSession> watchAsync(
    Map<String, dynamic> initial, {
    AcanthisValidationScope? scope,
    Duration debounce = Duration.zero,
  }) => AcanthisAsyncLiveSession.create(
    this,
    initial,
    scope: scope,
    debounce: debounce,
  );
}

AcanthisValidationDelta _delta(
  List<AcanthisIssue> before,
  List<AcanthisIssue> after,
  Set<String> fields,
  Set<String> rules,
  bool full,
  Map<String, Object?>? validated,
  Map<String, dynamic> input,
  int revision,
  bool current,
) {
  final added = _difference(after, before);
  final removed = _difference(before, after);
  return AcanthisValidationDelta(
    changedIssues: List.unmodifiable([...removed, ...added]),
    addedIssues: List.unmodifiable(added),
    removedIssues: List.unmodifiable(removed),
    issues: List.unmodifiable(after),
    executedFields: Set.unmodifiable(fields),
    executedRules: Set.unmodifiable(rules),
    fullValidation: full,
    validated: validated,
    input: _freezeInput(input),
    revision: revision,
    isCurrent: current,
  );
}

List<AcanthisIssue> _difference(
  List<AcanthisIssue> left,
  List<AcanthisIssue> right,
) {
  final counts = <AcanthisIssue, int>{};
  for (final issue in right) {
    counts.update(issue, (n) => n + 1, ifAbsent: () => 1);
  }
  final result = <AcanthisIssue>[];
  for (final issue in left) {
    final count = counts[issue] ?? 0;
    if (count == 0) {
      result.add(issue);
    } else {
      counts[issue] = count - 1;
    }
  }
  return result;
}
