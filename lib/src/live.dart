import 'dart:collection';

import 'package:meta/meta.dart';

import 'results.dart';
import 'types/map.dart';

/// Explains the work done by a [AcanthisLiveSession] update.
@immutable
class AcanthisValidationDelta<V> {
  const AcanthisValidationDelta({
    required this.changedIssues,
    required this.executedFields,
    required this.fullValidation,
    required this.validated,
  });

  final List<AcanthisIssue> changedIssues;
  final Set<String> executedFields;
  final bool fullValidation;
  final Map<String, V>? validated;
}

/// A synchronous, top-level object validation session.
///
/// Independent field updates validate only that field. Schemas containing map
/// operations or declared cross-field dependencies conservatively revalidate
/// the full object, preserving ordinary [AcanthisMap.tryParse] semantics.
class AcanthisLiveSession<V> {
  AcanthisLiveSession._(this.schema, Map<String, dynamic> initial)
    : _input = Map<String, dynamic>.of(initial) {
    if (schema.isAsync) {
      throw ArgumentError.value(
        schema,
        'schema',
        'Live sessions currently support synchronous schemas only.',
      );
    }
    _validateAll();
  }

  final AcanthisMap<V> schema;
  final Map<String, dynamic> _input;
  final Map<String?, List<AcanthisIssue>> _issuesByField = {};
  final Map<String, V> _fieldValues = {};
  List<AcanthisIssue> _orderedIssues = const [];
  Map<String, V>? _validated;
  Set<String> _lastExecutedFields = const {};
  bool _lastFullValidation = true;

  Map<String, dynamic> get input => UnmodifiableMapView(_input);
  Map<String, V>? get validated =>
      _validated == null ? null : UnmodifiableMapView(_validated!);

  /// Returns the latest explanation for a field, including why it was rerun.
  String explain(String field) {
    if (!_lastExecutedFields.contains(field)) {
      return '$field was not affected by the latest update.';
    }
    if (_lastFullValidation) {
      return '$field was rerun because this schema has object-level or cross-field rules.';
    }
    return '$field was rerun because its value changed.';
  }

  /// Applies a top-level field change and returns only diagnostics that changed.
  AcanthisValidationDelta<V> set(String field, dynamic value) {
    final before = _allIssues;
    _input[field] = value;

    if (_requiresFullValidation(field)) {
      _validateAll();
    } else {
      _validateField(field);
    }

    final after = _allIssues;
    final changed = _changedIssues(before, after);
    return AcanthisValidationDelta(
      changedIssues: List.unmodifiable(changed),
      executedFields: _lastExecutedFields,
      fullValidation: _lastFullValidation,
      validated: validated,
    );
  }

  bool _requiresFullValidation(String field) =>
      !schema.fields.containsKey(field) ||
      schema.operations.isNotEmpty ||
      schema.hasCrossFieldDependencies;

  void _validateAll() {
    final result = schema.tryParse(_input);
    final outcome = result.toOutcome();
    _issuesByField.clear();
    switch (outcome) {
      case AcanthisValid<Map<String, V>> valid:
        _orderedIssues = const [];
        _fieldValues
          ..clear()
          ..addAll(valid.value);
        _validated = Map<String, V>.of(_fieldValues);
      case AcanthisInvalid<Map<String, V>> invalid:
        _orderedIssues = invalid.issues;
        _validated = null;
        for (final issue in invalid.issues) {
          final field = issue.path.isEmpty ? null : issue.path.first.toString();
          (_issuesByField[field] ??= []).add(issue);
        }
        _refreshIndependentValues(result.value);
    }
    _lastExecutedFields = Set.unmodifiable(schema.fields.keys.toSet());
    _lastFullValidation = true;
  }

  void _validateField(String field) {
    final validator = schema.fields[field]!;
    final result = validator.tryParse(_input[field]);
    final outcome = result.toOutcome();
    _issuesByField.remove(field);
    switch (outcome) {
      case AcanthisValid<dynamic> valid:
        _fieldValues[field] = valid.value as V;
      case AcanthisInvalid<dynamic> invalid:
        _validated = null;
        _issuesByField[field] = invalid.issues
            .map((issue) => issue.prefixed(field))
            .toList(growable: false);
    }
    _validated = _issuesByField.isEmpty
        ? Map<String, V>.of(_fieldValues)
        : null;
    _orderedIssues = [
      for (final field in schema.fields.keys) ...?_issuesByField[field],
      for (final entry in _issuesByField.entries)
        if (!schema.fields.containsKey(entry.key)) ...entry.value,
    ];
    _lastExecutedFields = {field};
    _lastFullValidation = false;
  }

  List<AcanthisIssue> get issues => List.unmodifiable(_allIssues);

  List<AcanthisIssue> get _allIssues => _orderedIssues;

  void _refreshIndependentValues(Map<String, V> parsed) {
    _fieldValues.clear();
    for (final field in schema.fields.keys) {
      if (!_issuesByField.containsKey(field) && parsed.containsKey(field)) {
        _fieldValues[field] = parsed[field] as V;
      }
    }
  }
}

extension AcanthisLiveMaps<V> on AcanthisMap<V> {
  AcanthisLiveSession<V> watch(Map<String, dynamic> initial) =>
      AcanthisLiveSession<V>._(this, initial);
}

/// Async counterpart to [AcanthisLiveSession].
///
/// It associates every update with a monotonic revision. An older asynchronous
/// validation response can never overwrite a newer session state.
class AcanthisAsyncLiveSession<V> {
  AcanthisAsyncLiveSession._(this.schema, Map<String, dynamic> initial)
    : _input = Map<String, dynamic>.of(initial);

  final AcanthisMap<V> schema;
  final Map<String, dynamic> _input;
  var _revision = 0;
  List<AcanthisIssue> _issues = const [];
  Map<String, V>? _validated;

  Map<String, dynamic> get input => UnmodifiableMapView(_input);
  Map<String, V>? get validated =>
      _validated == null ? null : UnmodifiableMapView(_validated!);
  List<AcanthisIssue> get issues => _issues;

  static Future<AcanthisAsyncLiveSession<V>> create<V>(
    AcanthisMap<V> schema,
    Map<String, dynamic> initial,
  ) async {
    final session = AcanthisAsyncLiveSession<V>._(schema, initial);
    await session._validate(session._revision);
    return session;
  }

  Future<AcanthisValidationDelta<V>> set(String field, dynamic value) async {
    final before = _issues;
    _input[field] = value;
    final revision = ++_revision;
    await _validate(revision);
    final after = _issues;
    final changed = _changedIssues(before, after);
    return AcanthisValidationDelta(
      changedIssues: List.unmodifiable(changed),
      executedFields: Set.unmodifiable(schema.fields.keys.toSet()),
      fullValidation: true,
      validated: validated,
    );
  }

  Future<void> _validate(int revision) async {
    final outcome = (await schema.tryParseAsync(_input)).toOutcome();
    if (revision != _revision) return;
    switch (outcome) {
      case AcanthisValid<Map<String, V>> valid:
        _validated = Map<String, V>.of(valid.value);
        _issues = const [];
      case AcanthisInvalid<Map<String, V>> invalid:
        _validated = null;
        _issues = invalid.issues;
    }
  }
}

extension AcanthisAsyncLiveMaps<V> on AcanthisMap<V> {
  Future<AcanthisAsyncLiveSession<V>> watchAsync(
    Map<String, dynamic> initial,
  ) => AcanthisAsyncLiveSession.create<V>(this, initial);
}

// Multiset difference preserves repeated equal diagnostics in deltas.
List<AcanthisIssue> _changedIssues(
  List<AcanthisIssue> before,
  List<AcanthisIssue> after,
) {
  final remaining = List<AcanthisIssue>.of(after);
  final removed = <AcanthisIssue>[];
  for (final issue in before) {
    final index = remaining.indexOf(issue);
    if (index < 0) {
      removed.add(issue);
    } else {
      remaining.removeAt(index);
    }
  }
  return [...removed, ...remaining];
}
