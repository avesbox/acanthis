import 'common/validation_scope.dart';

import 'dart:collection';

import 'common/issue.dart' show AcanthisIssue, freezeIssueParameters;
import 'common/issue_sink.dart';
import 'common/results.dart';
import 'common/schema.dart';
import 'types/nullable.dart';

final class AcanthisSchemaImportException implements Exception {
  const AcanthisSchemaImportException(this.path, this.reason);
  final String path;
  final String reason;
  @override
  String toString() => 'Cannot import ${path.isEmpty ? "/" : path}: $reason';
}

/// Compile the supported JSON Schema 2020-12 subset once.
AcanthisJsonContract fromJsonSchema(Object? document) => _import(document);

/// Compile an OpenAPI 3.1 Schema Object (not an entire OpenAPI document).
AcanthisJsonContract fromOpenApiSchema(Object? document) => _import(document);
AcanthisJsonContract importJsonSchema(Object? document) =>
    fromJsonSchema(document);
AcanthisJsonContract importOpenApiSchema(Object? document) =>
    fromOpenApiSchema(document);

AcanthisJsonContract _import(Object? document) {
  final frozen = _snapshot(document, '', HashSet<Object>.identity(), 0, [
    16384,
  ]);
  final compiler = _Compiler(frozen);
  final root = compiler.compile(frozen, '');
  compiler.auditCycles();
  return AcanthisJsonContract._(frozen, root);
}

/// An immutable, compiled JSON contract. Parsing validates without coercing,
/// transforming, stripping keys, or applying JSON Schema default annotations.
final class AcanthisJsonContract extends Schema<Object?, Object?>
    with
        AsyncSchema<Object?, Object?>,
        ValidationSchema<Object?, Object?>,
        NullableSchema<Object?, Object?> {
  AcanthisJsonContract._(this.definition, this._root);
  final Object? definition;
  final _Node _root;
  @override
  bool get isAsync => false;
  @override
  Object? parse(Object? input) => parseOutcome(input).valueOrThrow;
  @override
  AcanthisOutcome<Object?> parseOutcome(Object? input) => _run(input, false);
  @override
  AcanthisOutcome<Object?> tryParse(Object? input) => _run(input, true);
  @override
  Future<Object?> parseAsync(Object? input) async => parse(input);
  @override
  Future<AcanthisOutcome<Object?>> parseOutcomeAsync(Object? input) async =>
      parseOutcome(input);
  @override
  Future<AcanthisOutcome<Object?>> tryParseAsync(Object? input) async =>
      tryParse(input);
  @override
  bool validate(Object? input) => parseOutcome(input).isValid;
  @override
  bool tryValidate(Object? input) => tryParse(input).isValid;

  Future<bool> validateAsync(Object? input) async => validate(input);
  Future<bool> tryValidateAsync(Object? input) async => tryValidate(input);

  AcanthisOutcome<Object?> _run(Object? input, bool collect) {
    AcanthisValidationScope.current.throwIfCancelled();
    final sink = IssueSink();
    final badPath = _invalidJson(input, null, 0);
    if (badPath != null) {
      sink.addIssue(
        'type',
        path: badPath,
        parameters: const {'expected': 'JSON value'},
      );
    } else {
      _root.validate(input, sink, const [], collect);
    }
    return sink.isEmpty
        ? AcanthisValid(input)
        : AcanthisInvalid(sink.takeIssues(), value: input);
  }

  /// Fresh mutable Schema Object; boolean contracts are normalized to objects.
  Map<String, Object?> exportDefinition() {
    final value = definition;
    if (value == true) return {};
    if (value == false) return {'not': <String, Object?>{}};
    final copy = _mutable(value) as Map<String, Object?>;
    copy.remove(r'$schema');
    return copy;
  }
}

String _path(String path, Object key) =>
    '$path/${key.toString().replaceAll('~', '~0').replaceAll('/', '~1')}';

Object? _snapshot(
  Object? value,
  String path,
  Set<Object> active,
  int depth,
  List<int> remaining,
) {
  Never bad(String reason) => throw AcanthisSchemaImportException(path, reason);
  if (--remaining[0] < 0 || depth > 64) {
    bad('Contract exceeds the 64-level/16384-node import limit.');
  }
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is double && value.isFinite) return value;
  if (value is! Map && value is! List) bad('Expected a JSON value.');
  if (!active.add(value)) bad('Cyclic Dart containers are not JSON.');
  try {
    if (value is List) {
      return List<Object?>.unmodifiable([
        for (var i = 0; i < value.length; i++)
          _snapshot(value[i], _path(path, i), active, depth + 1, remaining),
      ]);
    }
    final map = value as Map;
    final result = <String, Object?>{};
    for (final entry in map.entries) {
      if (entry.key is! String) bad('JSON object keys must be strings.');
      final key = entry.key as String;
      result[key] = _snapshot(
        entry.value,
        _path(path, key),
        active,
        depth + 1,
        remaining,
      );
    }
    return Map<String, Object?>.unmodifiable(result);
  } finally {
    active.remove(value);
  }
}

Object? _mutable(Object? value) => switch (value) {
  Map<String, Object?>() => {
    for (final entry in value.entries) entry.key: _mutable(entry.value),
  },
  List<Object?>() => [for (final item in value) _mutable(item)],
  _ => value,
};

// Validate the JSON domain once, including otherwise unconstrained properties.
// Shared subtrees are allowed; active-container cycles and excessive depth fail.
List<Object>? _invalidJson(Object? value, Set<Object>? active, int depth) {
  if (value == null || value is String || value is bool || value is int) {
    return null;
  }
  if (value is double && value.isFinite) return null;
  if (depth > 128 || (value is! List && value is! Map)) return const [];
  final visiting = active ?? HashSet<Object>.identity();
  if (!visiting.add(value)) return const [];
  try {
    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        final bad = _invalidJson(value[i], visiting, depth + 1);
        if (bad != null) return [i, ...bad];
      }
    } else if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) return const [];
        final bad = _invalidJson(entry.value, visiting, depth + 1);
        if (bad != null) return [key, ...bad];
      }
    }
    return null;
  } finally {
    visiting.remove(value);
  }
}

final class _Assertion {
  _Assertion(this.test, this.code, [Map<String, Object?> parameters = const {}])
    : parameters = freezeIssueParameters(parameters);
  final bool Function(Object?) test;
  final String code;
  final Map<String, Object?> parameters;
}

final class _Node {
  final assertions = <_Assertion>[];
  final allOf = <_Node>[];
  List<_Node>? anyOf;
  _Node? not;
  Map<String, _Node>? properties;
  List<String> required = const [];
  _Node? additional;
  _Node? items;
  List<_Node> prefixItems = const [];
  _Node? propertyNames;
  _Node? contains;

  void validate(
    Object? value,
    IssueSink sink,
    List<Object> path,
    bool collect,
  ) {
    final start = sink.length;
    for (final assertion in assertions) {
      if (!assertion.test(value)) {
        sink.addIssue(
          assertion.code,
          path: path,
          parameters: assertion.parameters,
        );
        if (!collect) return;
      }
    }
    for (final node in allOf) {
      node.validate(value, sink, path, collect);
      if (!collect && sink.length != start) return;
    }
    final alternatives = anyOf;
    if (alternatives != null) {
      final branches = <List<AcanthisIssue>>[];
      var accepted = false;
      for (final node in alternatives) {
        final branch = IssueSink();
        node.validate(value, branch, path, collect);
        if (branch.isEmpty) {
          accepted = true;
          break;
        }
        branches.add(branch.takeIssues());
      }
      if (!accepted) {
        sink.addIssue('union', path: path, branches: branches);
        if (!collect) return;
      }
    }
    final excluded = not;
    if (excluded != null) {
      final trial = IssueSink();
      excluded.validate(value, trial, path, false);
      if (trial.isEmpty) {
        sink.addIssue('jsonSchema.not', path: path);
        if (!collect) return;
      }
    }
    if (value is Map) {
      final names = propertyNames;
      if (names != null) {
        for (final key in value.keys) {
          names.validate(key, sink, [...path, key as String], collect);
          if (!collect && sink.length != start) return;
        }
      }
      for (final key in required) {
        if (!value.containsKey(key)) {
          sink.addIssue('required', path: [...path, key]);
          if (!collect) return;
        }
      }
      final fields = properties;
      if (fields != null) {
        for (final entry in fields.entries) {
          if (value.containsKey(entry.key)) {
            entry.value.validate(value[entry.key], sink, [
              ...path,
              entry.key,
            ], collect);
            if (!collect && sink.length != start) return;
          }
        }
      }
      final extra = additional;
      if (extra != null) {
        for (final key in value.keys) {
          if (fields?.containsKey(key) ?? false) continue;
          extra.validate(value[key], sink, [...path, key as String], collect);
          if (!collect && sink.length != start) return;
        }
      }
    }
    final item = items;
    final contained = contains;
    if (contained != null && value is List) {
      var matched = false;
      for (final candidate in value) {
        final trial = IssueSink();
        contained.validate(candidate, trial, const [], false);
        if (trial.isEmpty) {
          matched = true;
          break;
        }
      }
      if (!matched) {
        sink.addIssue('contains', path: path);
        if (!collect) return;
      }
    }
    if (value is List) {
      for (var i = 0; i < value.length; i++) {
        final child = i < prefixItems.length ? prefixItems[i] : item;
        child?.validate(value[i], sink, [...path, i], collect);
        if (!collect && sink.length != start) return;
      }
    }
  }
}

// The compiler is deliberately fail-closed: unknown validation keywords are
// rejected, not ignored as if their contracts were unconstrained.
final class _Compiler {
  _Compiler(this.document);
  final Object? document;
  final _active = HashSet<Object>.identity();
  final _cache = HashMap<Object, _Node>.identity();
  final _paths = HashMap<_Node, String>.identity();
  int _nodes = 0;
  static const _keywords = {
    r'$schema',
    r'$defs',
    r'$ref',
    r'$comment',
    'title',
    'description',
    'default',
    'examples',
    'deprecated',
    'readOnly',
    'writeOnly',
    'type',
    'enum',
    'const',
    'minimum',
    'maximum',
    'exclusiveMinimum',
    'exclusiveMaximum',
    'minLength',
    'pattern',
    'maxLength',
    'minItems',
    'maxItems',
    'uniqueItems',
    'minProperties',
    'maxProperties',
    'properties',
    'required',
    'additionalProperties',
    'items',
    'prefixItems',
    'propertyNames',
    'contains',
    'allOf',
    'anyOf',
    'not',
  };

  // References may form cycles only across an object/array descent. Audit the
  // complete graph after linking: shared nodes can create cycles on later use.
  void auditCycles() {
    final active = HashSet<_Node>.identity();
    final done = HashSet<_Node>.identity();
    void visit(_Node node) {
      if (done.contains(node)) return;
      if (!active.add(node)) {
        throw AcanthisSchemaImportException(
          _paths[node] ?? '',
          'Reference cycles must descend through properties or items.',
        );
      }
      if (active.length > 64) {
        throw AcanthisSchemaImportException(
          _paths[node] ?? '',
          'Reference evaluation exceeds 64 levels.',
        );
      }
      for (final child in node.allOf) {
        visit(child);
      }
      for (final child in node.anyOf ?? const <_Node>[]) {
        visit(child);
      }
      if (node.not case final excluded?) visit(excluded);
      active.remove(node);
      done.add(node);
    }

    for (final node in _paths.keys) {
      visit(node);
    }
  }

  _Node compile(Object? value, String path) {
    Never bad(String reason, [String? at]) =>
        throw AcanthisSchemaImportException(at ?? path, reason);
    if (value is bool) {
      if (++_nodes > 4096) {
        bad('Schema expansion exceeds the 4096-node limit.');
      }
      final node = _Node();
      if (!value) {
        node.assertions.add(_Assertion((_) => false, 'jsonSchema.false'));
      }
      return node;
    }
    if (value is! Map<String, Object?>) {
      bad('Expected a schema object or boolean.');
    }
    if (_active.contains(value)) {
      return _cache[value]!;
    }
    final existing = _cache[value];
    if (existing != null) return existing;
    if (++_nodes > 4096 || _active.length >= 64) {
      bad('Schema expansion exceeds the 64-level/4096-node limit.');
    }
    _active.add(value);
    try {
      for (final key in value.keys) {
        if (!_keywords.contains(key) && !key.startsWith('x-')) {
          bad('Unsupported keyword "$key".', _path(path, key));
        }
      }
      for (final key in [r'$schema', r'$comment', 'title', 'description']) {
        if (value.containsKey(key) && value[key] is! String) {
          bad('Expected a string.', _path(path, key));
        }
      }
      if (value.containsKey(r'$schema') &&
          !const {
            'https://json-schema.org/draft/2020-12/schema',
            'https://spec.openapis.org/oas/3.1/dialect/base',
          }.contains(value[r'$schema'])) {
        bad(
          'Only JSON Schema 2020-12 / OpenAPI 3.1 contracts are supported.',
          _path(path, r'$schema'),
        );
      }
      for (final key in [
        'deprecated',
        'readOnly',
        'writeOnly',
        'uniqueItems',
      ]) {
        if (value.containsKey(key) && value[key] is! bool) {
          bad('Expected a boolean.', _path(path, key));
        }
      }
      if (value.containsKey('examples') && value['examples'] is! List) {
        bad('Expected an array.', _path(path, 'examples'));
      }
      final node = _Node();
      _cache[value] = node;
      _paths[node] = path;
      if (value.containsKey('type')) {
        final raw = value['type'];
        final types = raw is String ? [raw] : raw;
        const allowed = {
          'null',
          'boolean',
          'object',
          'array',
          'number',
          'integer',
          'string',
        };
        if (types is! List ||
            types.isEmpty ||
            types.any((t) => t is! String || !allowed.contains(t)) ||
            types.toSet().length != types.length) {
          bad(
            'Expected a JSON type or nonempty array of unique JSON types.',
            _path(path, 'type'),
          );
        }
        node.assertions.add(
          _Assertion((v) => types.any((t) => _hasType(v, t)), 'type', {
            'expected': types.join('|'),
          }),
        );
      }
      if (value.containsKey('const')) {
        final expected = value['const'];
        node.assertions.add(
          _Assertion((v) => _equal(v, expected), 'exact', {'value': expected}),
        );
      }
      if (value.containsKey('enum')) {
        final values = value['enum'];
        if (values is! List || values.isEmpty) {
          bad('Expected a nonempty enum array.', _path(path, 'enum'));
        }
        if (values.map(_JsonKey.new).toSet().length != values.length) {
          bad('Enum values must be unique.', _path(path, 'enum'));
        }
        node.assertions.add(
          _Assertion((v) => values.any((e) => _equal(v, e)), 'enumerated', {
            'values': values,
          }),
        );
      }
      for (final key in [
        'minimum',
        'maximum',
        'exclusiveMinimum',
        'exclusiveMaximum',
      ]) {
        if (!value.containsKey(key)) continue;
        final bound = value[key];
        if (bound is! num) {
          bad('Expected a finite JSON number.', _path(path, key));
        }
        final code = switch (key) {
          'minimum' => 'gte',
          'maximum' => 'lte',
          'exclusiveMinimum' => 'gt',
          _ => 'lt',
        };
        node.assertions.add(
          _Assertion(
            (v) =>
                v is! num ||
                switch (key) {
                  'minimum' => _compare(v, bound) >= 0,
                  'maximum' => _compare(v, bound) <= 0,
                  'exclusiveMinimum' => _compare(v, bound) > 0,
                  _ => _compare(v, bound) < 0,
                },
            code,
            {'value': bound},
          ),
        );
      }
      if (value.containsKey('pattern')) {
        final pattern = value['pattern'];
        if (pattern is! String) {
          bad('Expected a string.', _path(path, 'pattern'));
        }
        final RegExp expression;
        try {
          expression = RegExp(pattern);
        } on FormatException {
          bad('Invalid regular expression.', _path(path, 'pattern'));
        }
        node.assertions.add(
          _Assertion((v) => v is! String || expression.hasMatch(v), 'pattern', {
            'pattern': pattern,
          }),
        );
      }
      for (final key in [
        'minLength',
        'maxLength',
        'minItems',
        'maxItems',
        'minProperties',
        'maxProperties',
      ]) {
        if (!value.containsKey(key)) continue;
        final limit = value[key];
        if (limit is! num ||
            limit < 0 ||
            limit != limit.truncateToDouble() ||
            limit > 9007199254740991) {
          bad('Expected a nonnegative safe JSON integer.', _path(path, key));
        }
        final count = limit.toInt();
        node.assertions.add(
          _Assertion(
            (v) {
              final int? length = key.endsWith('Length') && v is String
                  ? v.runes.length
                  : key.endsWith('Items') && v is List
                  ? v.length
                  : key.endsWith('Properties') && v is Map
                  ? v.length
                  : null;
              return length == null ||
                  (key.startsWith('min') ? length >= count : length <= count);
            },
            key,
            {
              key.endsWith('Length')
                      ? 'value'
                      : key.endsWith('Properties')
                      ? 'constraintValue'
                      : key:
                  count,
            },
          ),
        );
      }
      if (value['uniqueItems'] == true) {
        node.assertions.add(
          _Assertion(
            (v) => v is! List || v.map(_JsonKey.new).toSet().length == v.length,
            'uniqueItems',
          ),
        );
      }
      for (final key in ['allOf', 'anyOf']) {
        if (!value.containsKey(key)) continue;
        final branches = value[key];
        if (branches is! List || branches.isEmpty) {
          bad('Expected a nonempty schema array.', _path(path, key));
        }
        final compiled = [
          for (var i = 0; i < branches.length; i++)
            compile(branches[i], _path(_path(path, key), i)),
        ];
        if (key == 'allOf') {
          node.allOf.addAll(compiled);
        } else {
          node.anyOf = compiled;
        }
      }
      if (value.containsKey('not')) {
        node.not = compile(value['not'], _path(path, 'not'));
      }
      if (value.containsKey('properties')) {
        final fields = value['properties'];
        if (fields is! Map<String, Object?>) {
          bad('Expected a schema map.', _path(path, 'properties'));
        }
        node.properties = {
          for (final entry in fields.entries)
            entry.key: compile(
              entry.value,
              _path(_path(path, 'properties'), entry.key),
            ),
        };
      }
      if (value.containsKey('required')) {
        final keys = value['required'];
        if (keys is! List ||
            keys.any((k) => k is! String) ||
            keys.toSet().length != keys.length) {
          bad(
            'Expected unique string property names.',
            _path(path, 'required'),
          );
        }
        node.required = keys.cast<String>();
      }
      if (value.containsKey('additionalProperties')) {
        node.additional = compile(
          value['additionalProperties'],
          _path(path, 'additionalProperties'),
        );
      }
      if (value.containsKey('items')) {
        node.items = compile(value['items'], _path(path, 'items'));
      }
      if (value.containsKey('prefixItems')) {
        final prefix = value['prefixItems'];
        if (prefix is! List || prefix.isEmpty) {
          bad(
            'Expected a nonempty array of schemas.',
            _path(path, 'prefixItems'),
          );
        }
        node.prefixItems = [
          for (var i = 0; i < prefix.length; i++)
            compile(prefix[i], _path(_path(path, 'prefixItems'), i)),
        ];
      }
      if (value.containsKey('propertyNames')) {
        node.propertyNames = compile(
          value['propertyNames'],
          _path(path, 'propertyNames'),
        );
      }
      if (value.containsKey('contains')) {
        node.contains = compile(value['contains'], _path(path, 'contains'));
      }
      if (value.containsKey(r'$defs')) {
        final definitions = value[r'$defs'];
        if (definitions is! Map<String, Object?>) {
          bad('Expected a schema map.', _path(path, r'$defs'));
        }
        for (final entry in definitions.entries) {
          compile(entry.value, _path(_path(path, r'$defs'), entry.key));
        }
      }
      if (value.containsKey(r'$ref')) {
        final ref = value[r'$ref'];
        if (ref is! String || !ref.startsWith('#')) {
          bad(
            'Only local JSON Pointer references are supported.',
            _path(path, r'$ref'),
          );
        }
        Object? target = document;
        String pointer;
        try {
          pointer = Uri.decodeComponent(ref.substring(1));
        } on FormatException {
          bad('Invalid reference encoding.', _path(path, r'$ref'));
        }
        if (pointer.isNotEmpty && !pointer.startsWith('/')) {
          bad(
            'Only JSON Pointer references are supported.',
            _path(path, r'$ref'),
          );
        }
        for (final raw
            in pointer.isEmpty
                ? const <String>[]
                : pointer.substring(1).split('/')) {
          if (RegExp(r'~(?![01])').hasMatch(raw)) {
            bad('Invalid JSON Pointer escape.', _path(path, r'$ref'));
          }
          final key = raw.replaceAll('~1', '/').replaceAll('~0', '~');
          if (target is Map<String, Object?> && target.containsKey(key)) {
            target = target[key];
          } else if (target is List &&
              RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(key)) {
            final index = int.tryParse(key);
            if (index == null || index >= target.length) {
              bad('Reference does not resolve.', _path(path, r'$ref'));
            }
            target = target[index];
          } else {
            bad('Reference does not resolve.', _path(path, r'$ref'));
          }
        }
        node.allOf.add(compile(target, _path(path, r'$ref')));
      }
      _cache[value] = node;
      return node;
    } finally {
      _active.remove(value);
    }
  }
}

bool _hasType(Object? value, Object? type) => switch (type) {
  'null' => value == null,
  'boolean' => value is bool,
  'string' => value is String,
  'number' => value is num,
  'integer' =>
    value is int || (value is double && value == value.truncateToDouble()),
  'array' => value is List,
  'object' => value is Map,
  _ => false,
};

bool _equal(Object? a, Object? b) {
  if (a is num && b is num) {
    if (a is int && b is double) {
      return b == b.truncateToDouble() && BigInt.from(a) == BigInt.from(b);
    }
    if (a is double && b is int) {
      return a == a.truncateToDouble() && BigInt.from(a) == BigInt.from(b);
    }
    return a == b;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_equal(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || !_equal(a[key], b[key])) return false;
    }
    return true;
  }
  return a == b;
}

int _compare(num a, num b) {
  if (a == 0 && b == 0) return 0;
  if (a is int && b is double && b == b.truncateToDouble()) {
    if (a < -9007199254740991 ||
        a > 9007199254740991 ||
        b.abs() > 9007199254740991) {
      return BigInt.from(a).compareTo(BigInt.from(b));
    }
  } else if (a is double && b is int) {
    return -_compare(b, a);
  }
  return a.compareTo(b);
}

final class _JsonKey {
  const _JsonKey(this.value);
  final Object? value;
  @override
  bool operator ==(Object other) =>
      other is _JsonKey && _equal(value, other.value);
  @override
  int get hashCode => _hash(value);
  static int _hash(Object? value) => switch (value) {
    List() => Object.hashAll(value.map(_hash)),
    Map() => Object.hashAllUnordered(
      value.entries.map((e) => Object.hash(e.key, _hash(e.value))),
    ),
    _ => value.hashCode,
  };
}
