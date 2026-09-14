import 'dart:convert';

import 'package:meta/meta.dart';

import 'registries/metadata_registry.dart';
import 'types/types.dart';

/// A stable, machine-readable validation diagnostic.
@immutable
class AcanthisIssue {
  AcanthisIssue({
    required List<Object> path,
    required this.code,
    required this.message,
    Map<String, Object?> parameters = const {},
    List<List<AcanthisIssue>> branches = const [],
  }) : path = List.unmodifiable(path),
       parameters = Map.unmodifiable(
         parameters.map(
           (key, value) => MapEntry(key, freezeIssueParameter(value)),
         ),
       ),
       branches = List.unmodifiable(
         branches.map(List<AcanthisIssue>.unmodifiable),
       ) {
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

  AcanthisIssue prefixed(Object segment) => AcanthisIssue(
    path: [segment, ...path],
    code: code,
    message: message,
    parameters: parameters,
    branches: [
      for (final branch in branches)
        [for (final issue in branch) issue.prefixed(segment)],
    ],
  );

  String formatMessage({AcanthisMessageResolver? resolver}) =>
      resolver?.call(code, parameters) ?? message;

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
}

final class AcanthisValid<T> extends AcanthisOutcome<T> {
  const AcanthisValid(this.value, {this.metadata});

  final T value;
  final MetadataEntry<T>? metadata;

  @override
  bool get isValid => true;
}

final class AcanthisInvalid<T> extends AcanthisOutcome<T> {
  const AcanthisInvalid(this.issues, {this.recoveryValue, this.metadata});

  final List<AcanthisIssue> issues;
  final T? recoveryValue;
  final MetadataEntry<T>? metadata;

  @override
  bool get isValid => false;
}

extension AcanthisOutcomeConversion<T> on AcanthisParseResult<T> {
  AcanthisOutcome<T> toOutcome() {
    if (success) return AcanthisValid(value, metadata: metadata);
    return AcanthisInvalid(issues, recoveryValue: value, metadata: metadata);
  }
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

extension AcanthisOutcomeParsing<T> on AcanthisType<T> {
  /// Typed companion to [tryParse]. It preserves the legacy result API while
  /// allowing callers to handle success and failure exhaustively.
  AcanthisOutcome<T> validate(dynamic value) => tryParse(value).toOutcome();

  Future<AcanthisOutcome<T>> validateAsync(dynamic value) async =>
      (await tryParseAsync(value)).toOutcome();
}
