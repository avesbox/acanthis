import 'dart:convert';
import 'dart:collection';

import 'package:meta/meta.dart';

import 'registries/metadata_registry.dart';
import 'issue_sink.dart';
import 'i18n.dart';

/// A stable, machine-readable validation diagnostic.
@immutable
class AcanthisIssue {
  AcanthisIssue({
    required List<Object> path,
    required this.code,
    required this.message,
    Map<String, Object?> parameters = const {},
    List<List<AcanthisIssue>> branches = const [],
  }) : path = path.isEmpty ? const [] : List.unmodifiable(path),
       parameters = _freezeParameters(parameters),
       branches = branches.isEmpty
           ? const []
           : List.unmodifiable(branches.map(List<AcanthisIssue>.unmodifiable)) {
    if (path.any((part) => part is! String && part is! int)) {
      throw ArgumentError('Issue paths accept only strings and integers');
    }
  }

  final List<Object> path;
  final String code;
  final String message;
  final Map<String, Object?> parameters;

  /// Failed union branches, in evaluation order. Paths are absolute from root.
  final List<List<AcanthisIssue>> branches;

  // All members passed here are already frozen. Prefixing must not freeze
  // constraint metadata again at every level of an object/list path.
  AcanthisIssue._frozen({
    required this.path,
    required this.code,
    required this.message,
    required this.parameters,
    required this.branches,
  });

  AcanthisIssue prefixed(Object segment) {
    if (segment is! String && segment is! int) {
      throw ArgumentError('Issue paths accept only strings and integers');
    }
    return AcanthisIssue._frozen(
      path: _PrefixedIssuePath(segment, path),
      code: code,
      message: message,
      parameters: parameters,
      branches: branches.isEmpty
          ? const []
          : List.unmodifiable([
              for (final branch in branches)
                List<AcanthisIssue>.unmodifiable([
                  for (final issue in branch) issue.prefixed(segment),
                ]),
            ]),
    );
  }

  String formatMessage({AcanthisMessageResolver? resolver}) =>
      (resolver ?? AcanthisI18n.current.resolver)?.call(code, parameters) ??
      message;

  Map<String, Object?> toJson({AcanthisMessageResolver? resolver}) => {
    'path': path,
    'code': code,
    'parameters': parameters,
    'message': formatMessage(resolver: resolver),
    if (branches.isNotEmpty)
      'branches': [
        for (final branch in branches)
          [for (final issue in branch) issue.toJson(resolver: resolver)],
      ],
  };

  /// RFC 6901-style path suitable for transport and form adapters.
  String get jsonPointer => path.fold<String>('', (pointer, segment) {
    final escaped = segment
        .toString()
        .replaceAll('~', '~0')
        .replaceAll('/', '~1');
    return '$pointer/$escaped';
  });

  @override
  bool operator ==(Object other) =>
      other is AcanthisIssue &&
      other.code == code &&
      other.message == message &&
      _deepEqual(other.parameters, parameters) &&
      _deepEqual(other.branches, branches) &&
      _samePath(other.path, path);

  @override
  int get hashCode => Object.hash(
    code,
    message,
    Object.hashAll(path),
    _deepHash(parameters),
    _deepHash(branches),
  );

  static bool _samePath(List<Object> left, List<Object> right) =>
      left.length == right.length &&
      Iterable.generate(left.length)
          .every((index) => left[index] == right[index]);
}

// Both the prefix and tail are immutable. A path can therefore share its tail
// instead of copying an array whenever a parent attaches a diagnostic.
class _PrefixedIssuePath extends ListBase<Object> {
  final Object _segment;
  final List<Object> _tail;
  _PrefixedIssuePath(this._segment, this._tail);

  @override
  int get length => _tail.length + 1;
  @override
  set length(int value) => throw UnsupportedError('Issue paths are immutable');
  @override
  void operator []=(int index, Object value) =>
      throw UnsupportedError('Issue paths are immutable');
  @override
  Object operator [](int index) {
    if (index == 0) return _segment;
    return _tail[index - 1];
  }
}

// Most built-in constraints have a single scalar parameter. Store that frozen
// entry directly instead of allocating and copying two hash maps per failure.
class _SingleIssueParameter extends UnmodifiableMapBase<String, Object?> {
  final String _key;
  final Object? _value;
  _SingleIssueParameter(this._key, this._value);

  @override
  Object? operator [](Object? key) => key == _key ? _value : null;
  @override
  Iterable<String> get keys => [_key];
  @override
  int get length => 1;
  @override
  bool get isEmpty => false;
  @override
  bool containsKey(Object? key) => key == _key;
}

Map<String, Object?> _freezeParameters(Map<String, Object?> parameters) {
  if (parameters is _SingleIssueParameter) return parameters;
  if (parameters.isEmpty) return const {};
  if (parameters.length == 1) {
    final key = parameters.keys.first;
    return _SingleIssueParameter(key, freezeIssueParameter(parameters[key]));
  }
  return Map.unmodifiable(
    parameters.map((key, value) => MapEntry(key, freezeIssueParameter(value))),
  );
}

/// Frozen scalar constraint metadata shared by immutable built-in checks.
@internal
Map<String, Object?> singleIssueParameter(String key, Object? value) =>
    _SingleIssueParameter(key, freezeIssueParameter(value));

/// Return null to use the schema's fallback message.
typedef AcanthisMessageResolver = String? Function(
  String code,
  Map<String, Object?> parameters,
);

/// Freeze JSON-safe constraint metadata without retaining arbitrary objects.
Object? freezeIssueParameter(Object? value) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double) return value.isFinite ? value : value.toString();
  if (value is DateTime) return value.toIso8601String();
  if (value is Duration) return value.inMicroseconds;
  if (value is Enum) return value.name;
  if (value is RegExp) return value.pattern;
  if (value is Iterable) {
    return List.unmodifiable(value.map(freezeIssueParameter));
  }
  if (value is Map<String, Object?>) {
    return Map.unmodifiable(
      value.map((key, item) => MapEntry(key, freezeIssueParameter(item))),
    );
  }
  return '<${value.runtimeType}>';
}

bool _deepEqual(Object? a, Object? b) {
  if (a is List && b is List) {
    return a.length == b.length &&
        Iterable.generate(a.length).every((i) => _deepEqual(a[i], b[i]));
  }
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((key) => b.containsKey(key) && _deepEqual(a[key], b[key]));
  }
  return a == b;
}

int _deepHash(Object? value) {
  if (value is List) return Object.hashAll(value.map(_deepHash));
  if (value is Map) {
    return Object.hashAllUnordered(
      value.entries.map(
        (entry) => Object.hash(entry.key, _deepHash(entry.value)),
      ),
    );
  }
  return value.hashCode;
}

/// A typed tree keeps string keys distinct from integer indices.
class AcanthisIssueTree {
  final List<String> messages = [];
  final Map<Object, AcanthisIssueTree> children = {};
}

extension AcanthisIssueFormatting on Iterable<AcanthisIssue> {
  Map<String, List<String>> formatFields({AcanthisMessageResolver? resolver}) {
    final fields = <String, List<String>>{};
    for (final issue in this) {
      (fields[issue.jsonPointer] ??= []).add(
        issue.formatMessage(resolver: resolver),
      );
    }
    return fields;
  }

  AcanthisIssueTree formatTree({AcanthisMessageResolver? resolver}) {
    final root = AcanthisIssueTree();
    for (final issue in this) {
      var node = root;
      for (final segment in issue.path) {
        node = node.children.putIfAbsent(segment, AcanthisIssueTree.new);
      }
      node.messages.add(issue.formatMessage(resolver: resolver));
    }
    return root;
  }

  String formatJson({AcanthisMessageResolver? resolver}) =>
      jsonEncode([for (final issue in this) issue.toJson(resolver: resolver)]);
}

sealed class AcanthisOutcome<T> {
  const AcanthisOutcome();

  bool get isValid;

  /// Parsed output. On failure this is best-effort output and may not satisfy
  /// the schema. Check [isValid] or match the outcome before trusting it.
  T get value;

  MetadataEntry<T>? get metadata;

  List<AcanthisIssue> get issues;

  /// Lossy legacy projection. Prefer [issues] for complete diagnostics.
  Map<String, dynamic> get errors => IssueSink.fromIssues(issues);
}

final class AcanthisValid<T> extends AcanthisOutcome<T> {
  const AcanthisValid(this.value, {this.metadata});

  @override
  final T value;
  @override
  final MetadataEntry<T>? metadata;

  @override
  bool get isValid => true;

  @override
  List<AcanthisIssue> get issues => const [];
}

final class AcanthisInvalid<T> extends AcanthisOutcome<T> {
  AcanthisInvalid(
    List<AcanthisIssue> issues, {
    required this.value,
    this.metadata,
  }) : issues = List.unmodifiable(issues);

  @override
  final List<AcanthisIssue> issues;
  @override
  final T value;
  @override
  final MetadataEntry<T>? metadata;

  @override
  bool get isValid => false;
}

List<AcanthisIssue> issuesFromLegacyErrors(
  Map<String, dynamic> errors, [
  List<Object> path = const [],
]) {
  final issues = <AcanthisIssue>[];
  for (final entry in errors.entries) {
    final nextPath = [...path, entry.key];
    final error = entry.value;
    if (error is Map) {
      issues.addAll(
        issuesFromLegacyErrors(Map<String, dynamic>.from(error), nextPath),
      );
    } else {
      issues.add(
        AcanthisIssue(path: path, code: entry.key, message: error.toString()),
      );
    }
  }
  return List.unmodifiable(issues);
}
