import 'package:acanthis/src/exceptions/validation_error.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/operation.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:nanoid2/nanoid2.dart';

import 'types.dart';

/// Validates strings built from template-literal style parts.
class AcanthisTemplate extends AcanthisType<String> {
  /// Ordered list of literal strings or other acanthis types.
  final List<dynamic> parts;

  late final String _pattern = _buildPattern();

  String get pattern => _pattern;
  late final RegExp _regExp = RegExp(_pattern, dotAll: true);

  /// Constructor for template literal type
  AcanthisTemplate(
    List<dynamic> segments, {
    super.operations = const [],
    bool? isAsync,
    super.key,
    super.metadataEntry,
    super.defaultValue,
  })  : parts = List.unmodifiable(segments),
        super(
          isAsync: isAsync ?? _segmentsAreAsync(segments, operations),
        ) {
    if (segments.isEmpty) {
      throw ArgumentError('Template literal must have at least one part');
    }
  }

  static bool _segmentsAreAsync(
    List<dynamic> segments,
    List<AcanthisOperation<String>> operations,
  ) {
    if (operations.any((op) => op is AcanthisAsyncCheck<String>)) {
      return true;
    }
    for (final segment in segments) {
      if (segment is AcanthisType && segment.isAsync) {
        return true;
      }
    }
    return false;
  }

  bool _matches(String value) => _regExp.hasMatch(value);

  String _buildPattern() {
    final buffer = StringBuffer('^');
    for (final part in parts) {
      buffer.write(_patternForPart(part));
    }
    buffer.write(r'$');
    return buffer.toString();
  }

  String _patternForPart(dynamic part) {
    if (part is String) {
      return RegExp.escape(part);
    }
    if (part is AcanthisType) {
      final schema = part.toJsonSchema();
      return '(?:${_patternForSchema(schema)})';
    }
    throw ArgumentError('Unsupported template literal part: ${part.runtimeType}');
  }

  String _patternForSchema(Map<String, dynamic> schema) {
    if (schema.containsKey('anyOf')) {
      final patterns = (schema['anyOf'] as List)
          .map((raw) => _patternForSchema(Map<String, dynamic>.from(raw)))
          .where((p) => p.isNotEmpty)
          .toList();
      return patterns.isEmpty ? '.*' : '(?:${patterns.join('|')})';
    }
    if (schema.containsKey('oneOf')) {
      final patterns = (schema['oneOf'] as List)
          .map((raw) => _patternForSchema(Map<String, dynamic>.from(raw)))
          .where((p) => p.isNotEmpty)
          .toList();
      return patterns.isEmpty ? '.*' : '(?:${patterns.join('|')})';
    }
    if (schema.containsKey('enum')) {
      final enums = (schema['enum'] as List)
          .map((value) => RegExp.escape('$value'))
          .join('|');
      return enums.isEmpty ? '.*' : '(?:$enums)';
    }
    if (schema.containsKey('const')) {
      return RegExp.escape('${schema['const']}');
    }
    final type = schema['type'];
    if (type == 'literal') {
      return RegExp.escape('${schema['value']}');
    }
    if (type == 'null') {
      return 'null';
    }
    if (type == 'boolean') {
      return '(?:true|false)';
    }
    if (type == 'number' || type == 'integer') {
      return r'-?\d+(?:\.\d+)?';
    }
    if (type == 'string') {
      final pattern = schema['pattern'] as String?;
      if (pattern != null && pattern.isNotEmpty) {
        return _normalizeInlinePattern(pattern);
      }
      return '.*';
    }
    return '.*';
  }

  String _normalizeInlinePattern(String pattern) {
    var normalized = pattern;
    if (normalized.startsWith('/') && normalized.endsWith('/') &&
        normalized.length >= 2) {
      normalized = normalized.substring(1, normalized.length - 1);
    }
    if (normalized.startsWith('^')) {
      normalized = normalized.substring(1);
    }
    if (normalized.endsWith(r'$')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized.isEmpty ? '.*' : normalized;
  }

  @override
  AcanthisParseResult<String> parse(String value) {
    if (!_matches(value)) {
      throw ValidationError('Value does not match template literal');
    }
    return super.parse(value);
  }

  @override
  AcanthisParseResult<String> tryParse(String value) {
    if (!_matches(value)) {
      return AcanthisParseResult(
        value: defaultValue ?? value,
        errors: const {
          'templateLiteral': 'Value does not match template literal',
        },
        success: false,
        metadata: metadataEntry,
      );
    }
    return super.tryParse(value);
  }

  @override
  Future<AcanthisParseResult<String>> parseAsync(String value) async {
    if (!_matches(value)) {
      throw ValidationError('Value does not match template literal');
    }
    return super.parseAsync(value);
  }

  @override
  Future<AcanthisParseResult<String>> tryParseAsync(String value) async {
    if (!_matches(value)) {
      return AcanthisParseResult(
        value: defaultValue ?? value,
        errors: const {
          'templateLiteral': 'Value does not match template literal',
        },
        success: false,
        metadata: metadataEntry,
      );
    }
    return super.tryParseAsync(value);
  }

  @override
  AcanthisTemplate withAsyncCheck(AcanthisAsyncCheck<String> check) {
    return AcanthisTemplate(
      parts,
      operations: [...operations, check],
      isAsync: true,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisTemplate withCheck(AcanthisCheck<String> check) {
    return AcanthisTemplate(
      parts,
      operations: [...operations, check],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisTemplate withTransformation(
    AcanthisTransformation<String> transformation,
  ) {
    return AcanthisTemplate(
      parts,
      operations: [...operations, transformation],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisType<String> meta(MetadataEntry<String> metadata) {
    String k = key;
    if (k.isEmpty) {
      k = nanoid();
    }
    MetadataRegistry().add(k, metadata);
    return AcanthisTemplate(
      parts,
      operations: operations,
      isAsync: isAsync,
      key: k,
      metadataEntry: metadata,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisType<String> withDefault(String value) {
    return AcanthisTemplate(
      parts,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: value,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    return {
      'type': 'string',
      'pattern': _pattern,
      if (metadataEntry != null) ...metadataEntry!.toJson(),
    };
  }

  @override
  Map<String, dynamic> toOpenApiSchema() {
    return {
      'type': 'string',
      'pattern': _pattern,
      if (defaultValue != null) 'default': defaultValue,
    };
  }
}

AcanthisTemplate template(List<dynamic> parts) =>
    AcanthisTemplate(parts);
