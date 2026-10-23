import '../registries/metadata_registry.dart';
import '../common/validation_scope.dart';
import '../common/issue.dart';
import '../common/results.dart';
import '../common/schema.dart';
import '../common/schema_operations.dart';
import '../common/value_schema.dart';
import '../common/schema_graph.dart';
import '../schema_export.dart';
import 'number.dart';
import 'boolean.dart';
import 'literal.dart';
import 'nullable.dart';
import 'union.dart';
import '../validators/number.dart';
import '../validators/string.dart';
import 'string.dart';

/// A string shape assembled from literal text and JSON scalar schema patterns.
/// Segment schemas validate typed substrings; their output does not rewrite text.
final class AcanthisTemplate extends ValueSchemaBase<String, AcanthisTemplate> {
  factory AcanthisTemplate(List<Object?> parts) {
    if (parts.isEmpty) {
      throw ArgumentError('A template needs at least one part');
    }
    final snapshot = List<Object?>.unmodifiable(parts);
    final pattern =
        '^${snapshot.map((part) {
          if (part is String) return RegExp.escape(part);
          if (part is Schema<Object?, Object?>) {
            return '(?:${_partPattern(part)})';
          }
          throw ArgumentError.value(part, 'parts', 'Expected text or a scalar schema');
        }).join()}\$(?![\\s\\S])';
    return AcanthisTemplate._(
      snapshot,
      pattern,
      false,
      SchemaOperations<String>(),
      null,
      false,
    );
  }
  AcanthisTemplate._(
    this.parts,
    this.pattern,
    this.coercionEnabled,
    SchemaOperations<String> operations,
    String? defaultValue,
    bool hasDefault,
  ) : super(
        operations: operations,
        configuredDefault: defaultValue,
        ownDefault: hasDefault,
      );
  final List<Object?> parts;
  final String pattern;
  late final RegExp expression = RegExp(pattern);
  final bool coercionEnabled;
  @override
  Iterable<Schema<Object?, Object?>> get schemaChildren =>
      parts.whereType<Schema<Object?, Object?>>();
  @override
  late final bool isAsync = schemaGraphIsAsync(this);
  late final _segmentPatterns = [
    for (final part in parts)
      part is Schema<Object?, Object?> ? _shapeMatcher(part) : null,
  ];

  /// Only callback-free, unconstrained scalar segments have a shape-only export.
  bool get hasAuditedSegments => schemaChildren.every(_shapeOnly);
  AcanthisTemplate coerce() => copySchemaMetadata(
    this,
    AcanthisTemplate._(
      parts,
      pattern,
      true,
      operations,
      configuredDefault,
      ownDefault,
    ),
  );
  @override
  AcanthisTemplate rebuild(
    SchemaOperations<String> operations,
    String? defaultValue,
    bool hasDefault,
  ) => copySchemaMetadata(
    this,
    AcanthisTemplate._(
      parts,
      pattern,
      coercionEnabled,
      operations,
      defaultValue,
      hasDefault,
    ),
  );
  Object? _coerce(Object? input) {
    if (coercionEnabled &&
        (input is num || input is bool || input is DateTime)) {
      input = input.toString();
    }
    return input;
  }

  /// Choose boundaries by shape alone so callbacks are never retried.
  List<String>? _split(String input) {
    final failed = <(int, int)>{};
    final selected = List<String>.filled(parts.length, '');
    bool visit(int index, int offset) {
      if (index == parts.length) return offset == input.length;
      if (failed.contains((index, offset))) return false;
      final part = parts[index];
      if (part is String) {
        if (input.startsWith(part, offset)) {
          selected[index] = part;
          if (visit(index + 1, offset + part.length)) return true;
        }
      } else {
        final pattern = _segmentPatterns[index]!;
        for (var end = input.length; end >= offset; end--) {
          final text = input.substring(offset, end);
          if (!pattern(text)) continue;
          selected[index] = text;
          if (visit(index + 1, end)) return true;
        }
      }
      failed.add((index, offset));
      return false;
    }

    return visit(0, 0) ? selected : null;
  }

  AcanthisOutcome<String> _mismatch(String input) => AcanthisInvalid([
    AcanthisIssue(
      path: [],
      code: 'templateLiteral',
      parameters: {'pattern': pattern},
    ),
  ], value: input);

  @override
  AcanthisOutcome<String> parseValue(Object? input, bool collect) {
    input = _coerce(input);
    if (input is! String) {
      return AcanthisInvalid<String>.withoutValue([
        AcanthisIssue(path: [], code: 'type'),
      ]);
    }
    final segments = _split(input);
    if (segments == null) return _mismatch(input);
    final issues = <AcanthisIssue>[];
    for (var i = 0; i < parts.length; i++) {
      AcanthisValidationScope.current.throwIfCancelled();
      final part = parts[i];
      if (part is! Schema<Object?, Object?>) continue;
      final result = _segment(part, segments[i], collect);
      AcanthisValidationScope.current.throwIfCancelled();
      issues.addAll(result.issues.map((issue) => issue.prefixed(i)));
      if (!collect && issues.isNotEmpty) break;
    }
    return issues.isEmpty
        ? AcanthisValid(input)
        : AcanthisInvalid(issues, value: input);
  }

  @override
  Future<AcanthisOutcome<String>> parseValueAsync(
    Object? input,
    bool collect,
  ) async {
    input = _coerce(input);
    if (input is! String) {
      return AcanthisInvalid<String>.withoutValue([
        AcanthisIssue(path: [], code: 'type'),
      ]);
    }
    final segments = _split(input);
    if (segments == null) return _mismatch(input);
    final issues = <AcanthisIssue>[];
    for (var i = 0; i < parts.length; i++) {
      AcanthisValidationScope.current.throwIfCancelled();
      final part = parts[i];
      if (part is! Schema<Object?, Object?>) continue;
      final result = await _segmentAsync(part, segments[i], collect);
      AcanthisValidationScope.current.throwIfCancelled();
      issues.addAll(result.issues.map((issue) => issue.prefixed(i)));
      if (!collect && issues.isNotEmpty) break;
    }
    return issues.isEmpty
        ? AcanthisValid(input)
        : AcanthisInvalid(issues, value: input);
  }
}

Object? _decode(Schema<Object?, Object?> schema, String text) {
  if (schema is AcanthisLiteral) return schema.value;
  if (schema is AcanthisInt) return int.tryParse(text) ?? text;
  if (schema is AcanthisDouble) return double.tryParse(text) ?? text;
  if (schema is AcanthisNumeric) return num.tryParse(text) ?? text;
  if (schema is AcanthisBoolean) return text == 'true';
  return text;
}

final _shapeMatchers = Expando<bool Function(String)>();

bool Function(String) _shapeMatcher(Schema<Object?, Object?> schema) =>
    _shapeMatchers[schema] ??= _buildShapeMatcher(schema);

bool Function(String) _buildShapeMatcher(Schema<Object?, Object?> schema) {
  if (schema is AcanthisString) {
    for (final check in schema.checks) {
      if (check is PatternStringCheck) return check.regExp.hasMatch;
    }
  }
  if (schema is AcanthisTemplate) return (text) => schema._split(text) != null;
  if (schema is AcanthisNullable) {
    final child = _shapeMatcher(schema.element);
    return (text) => text == 'null' || child(text);
  }
  if (schema is AcanthisUnion) {
    final children = schema.alternatives.map(_shapeMatcher).toList();
    return (text) => children.any((match) => match(text));
  }
  return RegExp('^(?:${_partPattern(schema)})\$(?![\\s\\S])').hasMatch;
}

AcanthisOutcome<Object?> _segment(
  Schema<Object?, Object?> schema,
  String text,
  bool collect,
) {
  if (schema is AcanthisUnion<Object?>) {
    final branches = <List<AcanthisIssue>>[];
    for (final child in schema.alternatives) {
      final result = _segment(child, text, true);
      if (result.isValid) return schema.applyOperations(result, collect);
      branches.add(result.issues);
    }
    return AcanthisInvalid<Object?>.withoutValue([
      AcanthisIssue(path: [], code: 'union', branches: branches),
    ]);
  }
  if (schema is AcanthisNullable<Object?> && text != 'null') {
    return schema.applyOperations(
      _segment(schema.element, text, collect),
      collect,
    );
  }
  if (!_shapeMatcher(schema)(text)) {
    return AcanthisInvalid<Object?>.withoutValue([
      AcanthisIssue(path: [], code: 'templateLiteral'),
    ]);
  }
  final value = schema is AcanthisNullable && text == 'null'
      ? null
      : _decode(schema, text);
  return collect ? schema.tryParse(value) : schema.parseOutcome(value);
}

Future<AcanthisOutcome<Object?>> _segmentAsync(
  Schema<Object?, Object?> schema,
  String text,
  bool collect,
) async {
  if (schema is AcanthisUnion<Object?>) {
    final branches = <List<AcanthisIssue>>[];
    for (final child in schema.alternatives) {
      final result = await _segmentAsync(child, text, true);
      if (result.isValid) return schema.applyOperationsAsync(result, collect);
      branches.add(result.issues);
    }
    return AcanthisInvalid<Object?>.withoutValue([
      AcanthisIssue(path: [], code: 'union', branches: branches),
    ]);
  }
  if (schema is AcanthisNullable<Object?> && text != 'null') {
    return schema.applyOperationsAsync(
      await _segmentAsync(schema.element, text, collect),
      collect,
    );
  }
  if (!_shapeMatcher(schema)(text)) {
    return AcanthisInvalid<Object?>.withoutValue([
      AcanthisIssue(path: [], code: 'templateLiteral'),
    ]);
  }
  final value = schema is AcanthisNullable && text == 'null'
      ? null
      : _decode(schema, text);
  return schema is AsyncSchema<Object?, Object?>
      ? collect
            ? schema.tryParseAsync(value)
            : schema.parseOutcomeAsync(value)
      : collect
      ? schema.tryParse(value)
      : schema.parseOutcome(value);
}

bool _shapeOnly(Schema<Object?, Object?> schema) {
  if (schema is AcanthisTemplate) {
    return !schema.hasOperations &&
        !schema.coercionEnabled &&
        schema.hasAuditedSegments &&
        !schema.hasDefault;
  }
  if (schema is AcanthisString) return schema.isIdentity;
  if (schema is AcanthisNumeric) {
    return schema.checks.isEmpty &&
        schema.transformations.isEmpty &&
        schema.asyncChecks.isEmpty &&
        !schema.coercionEnabled &&
        !schema.hasDefault;
  }
  if (schema is AcanthisBoolean) {
    return !schema.hasOperations &&
        !schema.coercionEnabled &&
        !schema.hasDefault;
  }
  if (schema is AcanthisLiteral) {
    return !schema.hasOperations &&
        !schema.hasDefault &&
        (schema.value == null ||
            schema.value is String ||
            schema.value is num ||
            schema.value is bool);
  }
  if (schema is AcanthisUnion) {
    return !schema.hasGuards &&
        !schema.hasOperations &&
        !schema.hasDefault &&
        schema.alternatives.every(_shapeOnly);
  }
  if (schema is AcanthisNullable) {
    return !schema.hasOperations &&
        !schema.hasDefault &&
        _shapeOnly(schema.element);
  }
  return false;
}

String _schemaPattern(Map<String, Object?> schema) {
  if (schema['allOf'] case final List constraints) {
    for (final constraint in constraints) {
      final map = Map<String, Object?>.from(constraint as Map);
      if (map.containsKey('pattern')) return _inline(map['pattern'] as String);
      if (map.containsKey('enum')) return _schemaPattern(map);
    }
  }
  if (schema['anyOf'] case final List alternatives) {
    return '(?:${alternatives.map((s) => _schemaPattern(Map<String, Object?>.from(s as Map))).join('|')})';
  }
  if (schema.containsKey('const')) return RegExp.escape('${schema['const']}');
  if (schema['enum'] case final List values) {
    return '(?:${values.map((v) => RegExp.escape('$v')).join('|')})';
  }
  switch (schema['type']) {
    case 'null':
      return 'null';
    case 'boolean':
      return '(?:true|false)';
    case 'integer':
      return r'-?\d+';
    case 'number':
      return r'-?\d+(?:\.\d+)?';
    case 'string':
      var pattern = schema['pattern'] as String? ?? r'[\s\S]*';
      if (pattern.startsWith('^')) pattern = pattern.substring(1);
      if (pattern.endsWith(r'$')) {
        pattern = pattern.substring(0, pattern.length - 1);
      }
      return pattern;
    default:
      throw ArgumentError('Template segments require scalar schema patterns');
  }
}

AcanthisTemplate template(List<Object?> parts) => AcanthisTemplate(parts);

String _partPattern(Schema<Object?, Object?> part) {
  if (part is AcanthisString) {
    for (final check in part.checks) {
      if (check is PatternStringCheck) return _inline(check.regExp.pattern);
      if (check is ContainedStringCheck) {
        return '(?:${check.values.map(RegExp.escape).join('|')})';
      }
      if (check is EnumeratedStringCheck) {
        return '(?:${check.values.map(RegExp.escape).join('|')})';
      }
    }
    return r'[\s\S]*';
  }
  if (part is AcanthisTemplate) return _inline(part.pattern);
  if (part is AcanthisLiteral) return RegExp.escape('${part.value}');
  if (part is AcanthisBoolean) return '(?:true|false)';
  if (part is AcanthisNullable) return '(?:null|${_partPattern(part.element)})';
  if (part is AcanthisUnion) {
    if (part.hasGuards) {
      throw ArgumentError('Template segments cannot use guarded unions');
    }
    return part.alternatives.isEmpty
        ? '(?!)'
        : '(?:${part.alternatives.map(_partPattern).join('|')})';
  }
  if (part is AcanthisNumeric) {
    for (final check in part.checks) {
      if (check is EnumeratedNumberCheck) {
        return '(?:${check.values.map((v) => RegExp.escape('$v')).join('|')})';
      }
    }
    return part is AcanthisInt ? r'-?\d+' : r'-?\d+(?:\.\d+)?';
  }
  return _schemaPattern(part.toOpenApiSchema(mode: AcanthisSchemaMode.input));
}

String _inline(String pattern) {
  if (pattern.endsWith(r'$(?![\s\S])')) {
    pattern = pattern.substring(0, pattern.length - r'$(?![\s\S])'.length);
  }
  if (pattern.startsWith('^')) pattern = pattern.substring(1);
  if (pattern.endsWith(r'$')) {
    pattern = pattern.substring(0, pattern.length - 1);
  }
  return pattern;
}
