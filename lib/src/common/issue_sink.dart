import 'dart:collection';

import 'package:meta/meta.dart';

import 'issue.dart';

/// An ordered, native diagnostic accumulator.
///
/// No error-map projection or legacy diagnostic conversion is performed.
/// Empty validation does not allocate a backing list. [issues] publishes an
/// immutable snapshot, cached until mutation; [takeIssues] transfers ownership
/// of the buffer without copying it and leaves this sink empty.
@internal
final class IssueSink extends IterableBase<AcanthisIssue> {
  List<AcanthisIssue>? _buffer;
  List<AcanthisIssue>? _snapshot;

  IssueSink();

  IssueSink.fromIssues(Iterable<AcanthisIssue> issues) {
    addAll(issues);
  }

  IssueSink.single(String code, {Map<String, Object?> parameters = const {}}) {
    addIssue(code, parameters: parameters);
  }

  @override
  int get length => _buffer?.length ?? 0;

  int get issueCount => length;

  @override
  bool get isEmpty => _buffer == null;

  @override
  bool get isNotEmpty => _buffer != null;

  @override
  Iterator<AcanthisIssue> get iterator =>
      (_buffer ?? const <AcanthisIssue>[]).iterator;

  /// An immutable snapshot that survives subsequent appends or [clear].
  List<AcanthisIssue> get issues {
    final buffer = _buffer;
    if (buffer == null) return const [];
    return _snapshot ??= _IssueSnapshot._owned(
      List<AcanthisIssue>.of(buffer, growable: false),
    );
  }

  void add(AcanthisIssue issue) {
    (_buffer ??= <AcanthisIssue>[]).add(issue);
    _snapshot = null;
  }

  void addAll(Iterable<AcanthisIssue> issues) {
    if (identical(issues, this)) {
      addAll(this.issues);
    } else if (issues is IssueSink) {
      final source = issues._buffer;
      if (source == null) return;
      (_buffer ??= <AcanthisIssue>[]).addAll(source);
      _snapshot = null;
    } else if (issues is List<AcanthisIssue>) {
      if (issues.isEmpty) return;
      // Invalidate before a custom List can throw partway through iteration.
      _snapshot = null;
      final buffer = _buffer ??= <AcanthisIssue>[];
      try {
        buffer.addAll(issues);
      } finally {
        if (buffer.isEmpty) _buffer = null;
      }
    } else {
      for (final issue in issues) {
        add(issue);
      }
    }
  }

  void addIssue(
    String code, {
    List<Object> path = const [],
    Map<String, Object?> parameters = const {},
    List<List<AcanthisIssue>> branches = const [],
  }) {
    add(
      AcanthisIssue(
        path: path,
        code: code.isEmpty ? 'custom' : code,
        parameters: parameters,
        branches: branches,
      ),
    );
  }

  /// Attaches a child's diagnostics in emission order with a typed path prefix.
  /// Self-merges use a snapshot and append each original issue exactly once.
  void addChild(Object segment, IssueSink child) {
    if (segment is! String && segment is! int) {
      throw ArgumentError.value(segment, 'segment', 'Expected String or int');
    }
    final source = identical(child, this) ? issues : child._buffer;
    if (source == null || source.isEmpty) return;
    final buffer = _buffer ??= <AcanthisIssue>[];
    _snapshot = null;
    for (final issue in source) {
      buffer.add(issue.prefixed(segment));
    }
  }

  /// Publishes the owned buffer and resets the sink, with no element copy.
  /// The returned list cannot change when this sink is reused.
  List<AcanthisIssue> takeIssues() {
    final buffer = _buffer;
    if (buffer == null) return const [];
    final result = _snapshot ?? _IssueSnapshot._owned(buffer);
    _buffer = null;
    _snapshot = null;
    return result;
  }

  void clear() {
    _buffer = null;
    _snapshot = null;
  }
}

// Only this library can create this ownership marker. Callers cannot use an
// arbitrary unmodifiable view over a mutable list to bypass result snapshots.
final class _IssueSnapshot extends UnmodifiableListView<AcanthisIssue> {
  _IssueSnapshot._owned(super.source);
}

/// Freeze externally supplied issue lists, reusing only owned sink snapshots.
@internal
List<AcanthisIssue> freezeIssues(List<AcanthisIssue> issues) {
  if (issues.isEmpty) return const [];
  if (issues is _IssueSnapshot) return issues;
  return _IssueSnapshot._owned(List<AcanthisIssue>.of(issues, growable: false));
}
