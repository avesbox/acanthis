import 'dart:async';

import 'package:acanthis/acanthis.dart';

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

/// A revision-specific result. A superseded debounced revision is not settled.
class AcanthisValidationDelta<V> {
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
  final Map<String, V>? validated;
  final Map<String, dynamic> input;
  final int revision;
  final bool isCurrent;
  final bool settled;
}

// JSON-like collections are copied on entry and frozen on publication. Domain
// objects are opaque: callers must treat them and context as immutable.
dynamic _copy(dynamic value, {bool freeze = false}) {
  if (value is Map<String, dynamic>) {
    final result = value.map(
      (key, value) => MapEntry(key, _copy(value, freeze: freeze)),
    );
    return freeze ? Map<String, dynamic>.unmodifiable(result) : result;
  }
  if (value is List) {
    final result = value.map((value) => _copy(value, freeze: freeze)).toList();
    return freeze ? List<dynamic>.unmodifiable(result) : result;
  }
  return value;
}

// Preserve the runtime types of schema outputs (including List<int>, DTOs).
// Parsed values follow the schema's ordinary ownership contract.
Map<String, V> _freeze<V>(Map<String, V> value) =>
    Map<String, V>.unmodifiable(value);

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
  return next;
}

class _SessionState<V> {
  _SessionState(this.schema, Map<String, dynamic> initial, this.scope)
    : input = _copy(initial) as Map<String, dynamic>;
  final AcanthisMap<V> schema;
  AcanthisValidationScope scope;
  Map<String, dynamic> input;
  int revision = 0;
  List<AcanthisIssue> issues = const [];
  Map<String, V>? validated;
  Map<String, AcanthisOutcome<dynamic>> fields = {};
  Map<String, List<AcanthisIssue>> rules = {};
  Set<String> executed = {};
  bool full = true;
  final Set<AcanthisPath> dirty = {};
  bool contextChanged = false;

  bool get fallback =>
      schema.operations.isNotEmpty ||
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

  AcanthisValidationDelta<V> result(
    AcanthisOutcome<Map<String, V>> outcome,
    Map<String, dynamic> raw,
    int revision,
    List<AcanthisIssue> before,
    Set<String> executedFields,
    Set<String> executedRules,
    Map<String, AcanthisOutcome<dynamic>> fieldCache,
    Map<String, List<AcanthisIssue>> ruleCache,
  ) {
    final after = outcome is AcanthisInvalid<Map<String, V>>
        ? outcome.issues
        : <AcanthisIssue>[];
    final parsed = outcome.isValid ? _freeze(outcome.value) : null;
    final current = revision == this.revision;
    final delta = _delta<V>(
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
class AcanthisLiveSession<V> {
  AcanthisLiveSession._(
    AcanthisMap<V> schema,
    Map<String, dynamic> initial,
    AcanthisValidationScope scope,
  ) : _state = _SessionState(schema, initial, scope) {
    if (schema.isAsync) throw ArgumentError('Use watchAsync for async schemas');
    _validate();
  }
  final _SessionState<V> _state;
  AcanthisMap<V> get schema => _state.schema;
  Map<String, dynamic> get input => _freezeInput(_state.input);
  Map<String, V>? get validated => _state.validated;
  List<AcanthisIssue> get issues => _state.issues;
  int get revision => _state.revision;

  String explain(String field) => !_state.executed.contains(field)
      ? '$field was not affected by the latest update.'
      : _state.full
      ? '$field was rerun because this schema has object-level or cross-field rules.'
      : '$field was rerun because its value changed.';

  AcanthisValidationDelta<V> set(String field, dynamic value) =>
      setPath(AcanthisPath([field]), value);
  AcanthisValidationDelta<V> setPath(Object path, dynamic value) =>
      batch([AcanthisEdit.set(path, value)]);
  AcanthisValidationDelta<V> remove(String field) =>
      removePath(AcanthisPath([field]));
  AcanthisValidationDelta<V> removePath(Object path) =>
      batch([AcanthisEdit.remove(path)]);
  AcanthisValidationDelta<V> batch(List<AcanthisEdit> edits) {
    _state.edit(edits);
    return _validate();
  }

  /// Context changes also invalidate nested checks, whose dependencies are unknown.
  AcanthisValidationDelta<V> updateContext(Object? context) {
    _state.scope = _withContext(_state.scope, context);
    _state.contextChanged = true;
    _state.revision++;
    return _validate();
  }

  AcanthisValidationDelta<V> _validate() {
    _state.validated = null;
    final fields = Map<String, AcanthisOutcome<dynamic>>.of(_state.fields);
    final rules = Map<String, List<AcanthisIssue>>.of(_state.rules);
    _state.invalidate(fields, rules);
    final executed = <String>{};
    final executedRules = <String>{};
    final result = _state.scope.run(() {
      if (_state.fallback) {
        executed.addAll(schema.fields.keys);
        return schema.tryParse(_state.input);
      }
      return schema.evaluateObject(
        _state.input,
        fieldCache: fields,
        ruleCache: rules,
        executedFields: executed,
        executedRules: executedRules,
      );
    });
    return _state.result(
      result,
      _state.input,
      revision,
      issues,
      executed,
      executedRules,
      fields,
      rules,
    );
  }
}

/// Async editing with debounce, cooperative cancellation, and revision guards.
/// A newer edit cancels the previous signal; stale work cannot publish state.
class AcanthisAsyncLiveSession<V> {
  AcanthisAsyncLiveSession._(
    AcanthisMap<V> schema,
    Map<String, dynamic> initial,
    AcanthisValidationScope scope,
    this.debounce,
  ) : _state = _SessionState(schema, initial, scope);
  final _SessionState<V> _state;
  final Duration debounce;
  AcanthisCancellationSignal? _signal;
  bool _disposed = false;
  Set<String> _pending = const {};
  AcanthisMap<V> get schema => _state.schema;
  int get revision => _state.revision;
  Map<String, dynamic> get input => _freezeInput(_state.input);
  Map<String, V>? get validated => _state.validated;
  List<AcanthisIssue> get issues => _state.issues;
  Set<String> get pendingFields => _pending;

  static Future<AcanthisAsyncLiveSession<V>> create<V>(
    AcanthisMap<V> schema,
    Map<String, dynamic> initial, {
    AcanthisValidationScope? scope,
    Duration debounce = Duration.zero,
  }) async {
    if (debounce.isNegative) throw ArgumentError('Debounce cannot be negative');
    final session = AcanthisAsyncLiveSession<V>._(
      schema,
      initial,
      scope ?? AcanthisValidationScope.current,
      debounce,
    );
    await session._validate(delay: false);
    return session;
  }

  Future<AcanthisValidationDelta<V>> set(String field, dynamic value) =>
      setPath(AcanthisPath([field]), value);
  Future<AcanthisValidationDelta<V>> setPath(Object path, dynamic value) =>
      batch([AcanthisEdit.set(path, value)]);
  Future<AcanthisValidationDelta<V>> remove(String field) =>
      removePath(AcanthisPath([field]));
  Future<AcanthisValidationDelta<V>> removePath(Object path) =>
      batch([AcanthisEdit.remove(path)]);
  Future<AcanthisValidationDelta<V>> batch(List<AcanthisEdit> edits) {
    if (_disposed) throw StateError('Session is disposed');
    _state.edit(edits);
    return _validate();
  }

  Future<AcanthisValidationDelta<V>> updateContext(Object? context) {
    if (_disposed) throw StateError('Session is disposed');
    _state.scope = _withContext(_state.scope, context);
    _state.contextChanged = true;
    _state.revision++;
    return _validate();
  }

  void dispose() {
    _disposed = true;
    _signal?.cancel();
    _pending = const {};
    _state.revision++;
  }

  Future<AcanthisValidationDelta<V>> _validate({bool delay = true}) async {
    _signal?.cancel();
    final signal = _signal = AcanthisCancellationSignal();
    final revision = _state.revision;
    final raw = _copy(_state.input) as Map<String, dynamic>;
    final before = _state.issues;
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
    if (delay && debounce > Duration.zero) {
      await Future.any([Future<void>.delayed(debounce), signal.whenCancelled]);
      if (signal.isCancelled) {
        return AcanthisValidationDelta(
          changedIssues: const [],
          executedFields: const {},
          fullValidation: _state.fallback,
          validated: null,
          input: _freezeInput(raw),
          revision: revision,
          isCurrent: false,
          settled: false,
        );
      }
    }
    final executed = <String>{};
    final executedRules = <String>{};
    try {
      final outcome = await scope.run(() {
        if (_state.fallback) {
          executed.addAll(schema.fields.keys);
          return schema.tryParseAsync(raw);
        }
        return schema.evaluateObjectAsync(
          raw,
          fieldCache: fields,
          ruleCache: rules,
          executedFields: executed,
          executedRules: executedRules,
          onFieldSettled: (field) {
            if (revision == _state.revision) {
              _pending = Set.unmodifiable(
                _pending.where((key) => key != field),
              );
            }
          },
        );
      });
      return _state.result(
        outcome,
        raw,
        revision,
        before,
        executed,
        executedRules,
        fields,
        rules,
      );
    } finally {
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

extension AcanthisLiveMaps<V> on AcanthisMap<V> {
  AcanthisLiveSession<V> watch(
    Map<String, dynamic> initial, {
    AcanthisValidationScope? scope,
  }) => AcanthisLiveSession<V>._(
    this,
    initial,
    scope ?? AcanthisValidationScope.current,
  );
}

extension AcanthisAsyncLiveMaps<V> on AcanthisMap<V> {
  Future<AcanthisAsyncLiveSession<V>> watchAsync(
    Map<String, dynamic> initial, {
    AcanthisValidationScope? scope,
    Duration debounce = Duration.zero,
  }) => AcanthisAsyncLiveSession.create<V>(
    this,
    initial,
    scope: scope,
    debounce: debounce,
  );
}

AcanthisValidationDelta<V> _delta<V>(
  List<AcanthisIssue> before,
  List<AcanthisIssue> after,
  Set<String> fields,
  Set<String> rules,
  bool full,
  Map<String, V>? validated,
  Map<String, dynamic> input,
  int revision,
  bool current,
) {
  final added = List<AcanthisIssue>.of(after);
  final removed = <AcanthisIssue>[];
  for (final issue in before) {
    final index = added.indexOf(issue);
    if (index < 0) {
      removed.add(issue);
    } else {
      added.removeAt(index);
    }
  }
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
