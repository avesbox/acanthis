import 'dart:collection';

import 'package:meta/meta.dart';

import 'i18n.dart';

/// A stable, machine-readable validation diagnostic.
@immutable
final class AcanthisIssue {
  AcanthisIssue({
    required List<Object> path,
    required this.code,
    Map<String, Object?> parameters = const {},
    List<List<AcanthisIssue>> branches = const [],
    this.defaultCatalog,
  }) : path = path.isEmpty ? const [] : List.unmodifiable(path),
       parameters = freezeIssueParameters(parameters),
       branches = branches.isEmpty
           ? const []
           : List.unmodifiable(branches.map(List<AcanthisIssue>.unmodifiable)) {
    if (path.any((part) => part is! String && part is! int)) {
      throw ArgumentError('Issue paths accept only strings and integers');
    }
  }

  final List<Object> path;
  final String code;
  final Map<String, Object?> parameters;

  /// Per-check presentation defaults, excluded from equality and transport.
  final AcanthisMessageCatalog? defaultCatalog;

  /// Failed union branches, in evaluation order. Paths are absolute from root.
  final List<List<AcanthisIssue>> branches;

  // All members passed here are already frozen. Prefixing must not freeze
  // constraint metadata again at every level of an object/list path.
  AcanthisIssue._frozen({
    required this.path,
    required this.code,
    required this.parameters,
    required this.branches,
    required this.defaultCatalog,
  });

  AcanthisIssue prefixed(Object segment) {
    if (segment is! String && segment is! int) {
      throw ArgumentError('Issue paths accept only strings and integers');
    }
    return AcanthisIssue._frozen(
      path: _PrefixedIssuePath(segment, path),
      code: code,
      parameters: parameters,
      defaultCatalog: defaultCatalog,
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

  /// Default presentation; not stored as part of the diagnostic.
  String get message => formatMessage();

  /// Resolve this diagnostic through a caller-provided immutable message map.
  String formatMessage({AcanthisMessageCatalog? catalog}) => catalog != null
      ? catalog.format(code, parameters)
      : AcanthisI18n.current.catalog?.resolve(code, parameters) ??
            defaultCatalog?.resolve(code, parameters) ??
            AcanthisMessageCatalog.english.format(code, parameters);

  Map<String, Object?> toJson({AcanthisMessageCatalog? catalog}) => {
    'path': path,
    'code': code,
    'parameters': parameters,
    'message': formatMessage(catalog: catalog),
    if (branches.isNotEmpty)
      'branches': [
        for (final branch in branches)
          [for (final issue in branch) issue.toJson(catalog: catalog)],
      ],
  };

  /// Locale-independent protocol node; excludes messages and submitted input.
  Map<String, Object?> toTransport() => {
    'path': path,
    'code': code,
    'parameters': parameters,
    if (branches.isNotEmpty)
      'branches': [
        for (final branch in branches)
          [for (final issue in branch) issue.toTransport()],
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
      _deepEqual(other.parameters, parameters) &&
      _deepEqual(other.branches, branches) &&
      _samePath(other.path, path);

  @override
  int get hashCode => Object.hash(
    code,
    Object.hashAll(path),
    _deepHash(parameters),
    _deepHash(branches),
  );

  static bool _samePath(List<Object> left, List<Object> right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    final leftIterator = left.iterator;
    final rightIterator = right.iterator;
    while (leftIterator.moveNext()) {
      rightIterator.moveNext();
      if (leftIterator.current != rightIterator.current) return false;
    }
    return true;
  }
}

// Both the prefix and tail are immutable. A path can therefore share its tail
// instead of copying an array whenever a parent attaches a diagnostic.
class _PrefixedIssuePath extends ListBase<Object> {
  final Object _segment;
  final List<Object> _tail;
  final int _length;
  _PrefixedIssuePath(this._segment, this._tail) : _length = _tail.length + 1;

  @override
  int get length => _length;
  @override
  set length(int value) => throw UnsupportedError('Issue paths are immutable');
  @override
  void operator []=(int index, Object value) =>
      throw UnsupportedError('Issue paths are immutable');
  @override
  Object operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', _length);
    List<Object> remaining = this;
    while (remaining is _PrefixedIssuePath) {
      if (index == 0) return remaining._segment;
      index--;
      remaining = remaining._tail;
    }
    return remaining[index];
  }

  // A ListBase iterator indexes repeatedly. Walking the shared tails directly
  // keeps traversal linear even for deeply nested diagnostics.
  @override
  Iterator<Object> get iterator => _IssuePathIterator(this);
}

class _IssuePathIterator implements Iterator<Object> {
  List<Object> _remaining;
  int _index = 0;
  Object? _current;
  _IssuePathIterator(this._remaining);

  @override
  Object get current =>
      _current ?? (throw StateError('No current path segment'));

  @override
  bool moveNext() {
    final remaining = _remaining;
    if (remaining is _PrefixedIssuePath) {
      _current = remaining._segment;
      _remaining = remaining._tail;
      return true;
    }
    if (_index < remaining.length) {
      _current = remaining[_index++];
      return true;
    }
    _current = null;
    return false;
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

/// Snapshot constraint metadata once, including the common scalar fast path.
@internal
Map<String, Object?> freezeIssueParameters(Map<String, Object?> parameters) {
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

/// Freeze JSON-safe constraint metadata without retaining arbitrary objects.
Object? freezeIssueParameter(Object? value) {
  // Keep scalar diagnostics allocation-free; traversal state is only needed
  // for custom containers.
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  return _freezeIssueParameter(value, _ParameterTraversal(), 0);
}

class _ParameterTraversal {
  final active = HashSet<Object>.identity();
  int remaining = 4096;
}

Object? _freezeIssueParameter(
  Object? value,
  _ParameterTraversal state,
  int depth,
) {
  if (state.remaining-- <= 0) return '<max-nodes>';
  final active = state.active;
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double) return value.isFinite ? value : value.toString();
  if (value is DateTime) return value.toIso8601String();
  if (value is Duration) return value.inMicroseconds;
  if (value is Enum) return value.name;
  if (value is RegExp) return value.pattern;
  if (depth >= 32) return '<max-depth>';
  if (value is Iterable) {
    if (!active.add(value)) return '<cycle>';
    try {
      final result = <Object?>[];
      for (final item in value) {
        if (result.length == 1024) {
          result.add('<truncated>');
          break;
        }
        result.add(_freezeIssueParameter(item, state, depth + 1));
        if (state.remaining <= 0) {
          result.add('<max-nodes>');
          break;
        }
      }
      return List.unmodifiable(result);
    } finally {
      active.remove(value);
    }
  }
  if (value is Map<String, Object?>) {
    if (!active.add(value)) return '<cycle>';
    try {
      if (value.length > 1024) return '<truncated-map>';
      final result = <String, Object?>{};
      for (final entry in value.entries) {
        result[entry.key] = _freezeIssueParameter(
          entry.value,
          state,
          depth + 1,
        );
        if (state.remaining <= 0) return '<max-nodes>';
      }
      return Map.unmodifiable(result);
    } finally {
      active.remove(value);
    }
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
