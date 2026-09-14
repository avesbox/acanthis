import 'dart:collection';

import 'results.dart';

/// Internal ordered diagnostic sink. The Map interface preserves the existing
/// tryParseInternal extension point for third-party schemas. Library checks emit
/// issues directly; map writes from older extensions are adapted at write time.
class IssueSink extends MapBase<String, dynamic> {
  final List<AcanthisIssue> _issues = [];

  IssueSink();
  IssueSink.fromIssues(Iterable<AcanthisIssue> issues) {
    _issues.addAll(issues);
  }
  IssueSink.of(Map<String, dynamic> source) {
    addAll(source);
  }
  IssueSink.single(
    String code,
    String message, {
    Map<String, Object?> parameters = const {},
  }) {
    addIssue(code, message, parameters: parameters);
  }

  List<AcanthisIssue> get issues => List.unmodifiable(_issues);

  Map<String, dynamic> get _legacy {
    final result = <String, dynamic>{};
    for (final issue in _issues) {
      var node = result;
      for (final segment in issue.path) {
        final key = segment.toString();
        if (node[key] is! Map<String, dynamic>) node[key] = <String, dynamic>{};
        node = node[key] as Map<String, dynamic>;
      }
      node[issue.code] = issue.message;
    }
    return result;
  }

  @override
  dynamic operator [](Object? key) => _legacy[key];
  @override
  Iterable<String> get keys => _legacy.keys;
  @override
  bool get isEmpty => _issues.isEmpty;
  @override
  bool get isNotEmpty => _issues.isNotEmpty;
  @override
  void clear() => _issues.clear();
  @override
  dynamic remove(Object? key) {
    final previous = this[key];
    _issues.removeWhere(
      (issue) =>
          (issue.path.isEmpty ? issue.code : issue.path.first.toString()) ==
          key,
    );
    return previous;
  }

  @override
  void operator []=(String key, dynamic value) {
    if (value is Map<String, dynamic>) {
      addChild(key, value);
    } else {
      addIssue(key, value.toString());
    }
  }

  @override
  void addAll(Map<String, dynamic> other) {
    _issues.addAll(
      other is IssueSink ? other.issues : issuesFromLegacyErrors(other),
    );
  }
}

extension IssueEmission on Map<String, dynamic> {
  int get issueCount =>
      this is IssueSink ? (this as IssueSink)._issues.length : length;

  void addIssue(
    String code,
    String message, {
    List<Object> path = const [],
    Map<String, Object?> parameters = const {},
    List<List<AcanthisIssue>> branches = const [],
  }) {
    final issue = AcanthisIssue(
      path: path,
      code: code.isEmpty ? 'custom' : code,
      message: message,
      parameters: parameters,
      branches: branches,
    );
    if (this is IssueSink) {
      (this as IssueSink)._issues.add(issue);
    } else {
      final sink = IssueSink().._issues.add(issue);
      addAll(sink._legacy);
    }
  }

  void addChild(Object segment, Map<String, dynamic> child) {
    if (this is IssueSink) {
      final issues = child is IssueSink
          ? child.issues
          : issuesFromLegacyErrors(child);
      (this as IssueSink)._issues.addAll(
        issues.map((issue) => issue.prefixed(segment)),
      );
    } else {
      this[segment.toString()] = Map<String, dynamic>.of(child);
    }
  }
}
