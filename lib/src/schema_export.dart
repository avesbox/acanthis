import 'dart:collection';

import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/validators/boolean.dart';
import 'package:acanthis/src/validators/common.dart';
import 'package:acanthis/src/validators/list.dart';
import 'package:acanthis/src/validators/number.dart';
import 'package:acanthis/src/validators/string.dart';

/// Select the accepted JSON input or successful JSON output contract.
enum AcanthisSchemaMode { input, output }

/// An exact schema cannot represent this runtime behavior.
class AcanthisSchemaExportException implements Exception {
  AcanthisSchemaExportException(this.path, this.reason);
  final String path;
  final String reason;
  @override
  String toString() => 'Cannot export ${path.isEmpty ? "/" : path}: $reason';
}

extension AcanthisContractExport on AcanthisType {
  /// Exports the supported JSON-only subset using JSON Schema 2020-12.
  /// Unaudited checks, coercion and transformations throw
  /// with a schema path instead of silently claiming an exact contract.
  Map<String, dynamic> exportJsonSchema({required AcanthisSchemaMode mode}) => {
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    ..._ContractExporter(mode).export(this),
  };

  /// Returns an OpenAPI 3.1 Schema Object (not a complete OpenAPI document).
  Map<String, dynamic> exportOpenApiSchema({
    required AcanthisSchemaMode mode,
  }) => _ContractExporter(mode).export(this);
}

String _childPath(String path, String key) =>
    '$path/${key.replaceAll('~', '~0').replaceAll('/', '~1')}';

List<Map<String, dynamic>> _constraints(AcanthisType type, String path) {
  Never unsupported(String reason) =>
      throw AcanthisSchemaExportException(path, reason);
  num finite(num value) {
    if (!value.isFinite) {
      unsupported('Constraint bounds must be finite JSON numbers.');
    }
    return value;
  }

  Map<String, dynamic> enumeration(Iterable<dynamic> values) {
    final unique = values.toSet().toList();
    for (final value in unique) {
      if (value is! String &&
          value is! bool &&
          value is! num &&
          value != null) {
        unsupported('Only JSON scalar equality can be exported.');
      }
      if (value is num) finite(value);
    }
    return unique.isEmpty ? {'not': <String, dynamic>{}} : {'enum': unique};
  }

  return [
    for (final operation in type.operations)
      switch (operation) {
        LteNumberCheck() when type is AcanthisNumeric => {
          'maximum': finite(operation.value),
        },
        GteNumberCheck() when type is AcanthisNumeric => {
          'minimum': finite(operation.value),
        },
        LtNumberCheck() when type is AcanthisNumeric => {
          'exclusiveMaximum': finite(operation.value),
        },
        GtNumberCheck() when type is AcanthisNumeric => {
          'exclusiveMinimum': finite(operation.value),
        },
        BetweenNumberCheck() when type is AcanthisNumeric => {
          'minimum': finite(operation.min),
          'maximum': finite(operation.max),
        },
        PositiveNumberCheck() when type is AcanthisNumeric => {
          'exclusiveMinimum': 0,
        },
        NegativeNumberCheck() when type is AcanthisNumeric => {
          'exclusiveMaximum': 0,
        },
        NonPositiveNumberCheck() when type is AcanthisNumeric => {'maximum': 0},
        NonNegativeNumberCheck() when type is AcanthisNumeric => {'minimum': 0},
        FiniteNumberCheck() ||
        NotNaNNumberCheck() when type is AcanthisNumeric => {},
        InfiniteNumberCheck() || NaNNumberCheck()
            when type is AcanthisNumeric =>
          {'not': <String, dynamic>{}},
        EnumeratedNumberCheck() when type is AcanthisNumeric => enumeration(
          operation.values,
        ),
        ExactCheck()
            when type is AcanthisNumeric ||
                type is AcanthisString ||
                type is AcanthisBoolean =>
          enumeration([operation.value]),
        IsTrueCheck() when type is AcanthisBoolean => {'const': true},
        IsFalseCheck() when type is AcanthisBoolean => {'const': false},
        ContainedStringCheck() when type is AcanthisString => enumeration(
          operation.values,
        ),
        RequiredStringCheck() ||
        NotEmptyStringCheck() when type is AcanthisString => {'minLength': 1},
        MinItemsListCheck() when type is AcanthisList => {
          'minItems': operation.minItems < 0 ? 0 : operation.minItems,
        },
        MaxItemsListCheck() when type is AcanthisList =>
          operation.maxItems < 0
              ? {'not': <String, dynamic>{}}
              : {'maxItems': operation.maxItems},
        LengthListCheck() when type is AcanthisList =>
          operation.length < 0
              ? {'not': <String, dynamic>{}}
              : {'minItems': operation.length, 'maxItems': operation.length},
        MinStringLengthCheck() ||
        MaxStringLengthCheck() ||
        ExactStringLengthCheck() => unsupported(
          'String length checks count UTF-16 code units; JSON Schema counts Unicode code points. '
          'Use the legacy exporter only if this approximation is acceptable.',
        ),
        UniqueItemsListCheck() => unsupported(
          'List uniqueness uses Dart equality; JSON Schema uses structural JSON equality.',
        ),
        IntegerNumberCheck() || DoubleNumberCheck() => unsupported(
          'Dart int/double representation checks have no exact JSON number contract.',
        ),
        MultipleOfCheck() => unsupported(
          'Dart floating-point remainder has not been audited against JSON Schema multipleOf.',
        ),
        AcanthisCheck() => unsupported(
          'Check ${operation.name.isEmpty ? operation.runtimeType : operation.name} '
          'has no audited JSON contract. Remove it or use the legacy best-effort exporter.',
        ),
        _ => unsupported(
          'Transformations and custom operations cannot be represented.',
        ),
      },
  ];
}

class _ContractExporter {
  _ContractExporter(this.mode);
  final AcanthisSchemaMode mode;
  final _active = HashMap<AcanthisType, String>.identity();
  final _referenced = <String>{};
  final _definitions = <String, dynamic>{};
  int _nextId = 0;

  Map<String, dynamic> export(AcanthisType type) {
    final schema = _exportContract(type, '');
    return {...schema, if (_definitions.isNotEmpty) r'$defs': _definitions};
  }

  Map<String, dynamic> _exportContract(AcanthisType type, String path) {
    final existing = _active[type];
    if (existing != null) {
      _referenced.add(existing);
      return {r'$ref': '#/\$defs/$existing'};
    }
    if (_active.length >= 64) {
      throw AcanthisSchemaExportException(
        path,
        'Schema expansion exceeds 64 levels. Lazy callbacks must reuse a '
        'stable schema (for example parent.list()), not rebuild it at each level.',
      );
    }
    final id = 'schema${_nextId++}';
    _active[type] = id;
    try {
      final schema = _body(type, path);
      if (_referenced.contains(id)) _definitions[id] = schema;
      return schema;
    } finally {
      _active.remove(type);
    }
  }

  Map<String, dynamic> _body(AcanthisType type, String path) {
    Never unsupported(String reason) =>
        throw AcanthisSchemaExportException(path, reason);
    if (type.isAsync) unsupported('Async validation cannot be represented.');
    final constraints = _constraints(type, path);
    late Map<String, dynamic> schema;
    if (type is AcanthisMap) {
      if (type.hasCrossFieldDependencies) {
        unsupported('Cross-field dependencies cannot be represented.');
      }
      final required = <String>[];
      final properties = <String, dynamic>{};
      for (final entry in type.fields.entries) {
        final field = entry.value;
        final fieldPath = _childPath(path, entry.key);
        AcanthisType resolved = field;
        if (field is LazyEntry) {
          if (field.operations.isNotEmpty || field.isAsync) {
            throw AcanthisSchemaExportException(
              fieldPath,
              'Operations on LazyEntry are not an audited runtime contract.',
            );
          }
          try {
            resolved = field.call(type);
          } catch (_) {
            throw AcanthisSchemaExportException(
              fieldPath,
              'Lazy callback failed to resolve. Return a stable non-LazyEntry schema.',
            );
          }
        }
        properties[entry.key] = _exportContract(resolved, fieldPath);
        final isRequired =
            !type.isOptionalField(entry.key) ||
            (mode == AcanthisSchemaMode.output &&
                !type.isPatch &&
                field.hasDefault);
        if (isRequired &&
            !(mode == AcanthisSchemaMode.input && field.hasDefault)) {
          required.add(entry.key);
        }
      }
      schema = {
        'type': 'object',
        'properties': properties,
        'required': required,
        'additionalProperties': switch (type.unknownKeyPolicy) {
          AcanthisUnknownKeys.reject => false,
          AcanthisUnknownKeys.strip => mode == AcanthisSchemaMode.input,
          AcanthisUnknownKeys.preserve =>
            type.additionalValueType == null
                ? true
                : _exportContract(type.additionalValueType!, '$path/*'),
        },
      };
    } else if (type is AcanthisNullable) {
      final element = _exportContract(type.element, path);
      schema = mode == AcanthisSchemaMode.output && type.defaultValue != null
          ? element
          : {
              'anyOf': [
                element,
                {'type': 'null'},
              ],
            };
    } else if (type is AcanthisList) {
      schema = {
        'type': 'array',
        'items': _exportContract(type.element, '$path/*'),
      };
    } else if (type is AcanthisUnion) {
      if (type.hasGuards) {
        unsupported('Arbitrary variant guards cannot be represented.');
      }
      final branches = type.alternatives;
      schema = {
        'anyOf': [
          for (var index = 0; index < branches.length; index++)
            _exportContract(branches[index], '$path/anyOf/$index'),
        ],
      };
    } else if (type is AcanthisString) {
      if (type.coercionEnabled) {
        unsupported('String coercion cannot be represented.');
      }
      schema = {'type': 'string'};
    } else if (type is AcanthisBoolean) {
      if (type.coercionEnabled) {
        unsupported('Boolean coercion cannot be represented.');
      }
      schema = {'type': 'boolean'};
    } else if (type is AcanthisNumeric) {
      if (type.coercionEnabled) {
        unsupported('Number coercion cannot be represented.');
      }
      // JSON does not preserve Dart int versus double representation.
      if (type.elementType != num) {
        unsupported(
          'Dart int/double representation restrictions have no exact JSON number contract.',
        );
      }
      schema = {'type': 'number'};
    } else if (type is AcanthisLiteral &&
        (type.value == null ||
            type.value is String ||
            type.value is bool ||
            type.value is num)) {
      if (type.value is num &&
          (type.elementType != num || !(type.value as num).isFinite)) {
        unsupported(
          'Numeric literals require a finite num-typed value for exact export.',
        );
      }
      schema = {'const': type.value};
    } else {
      unsupported('${type.runtimeType} has no audited JSON contract.');
    }
    if (constraints.isNotEmpty) {
      schema = {...schema, 'allOf': constraints};
    }
    if (type.hasDefault) {
      if (!type.tryParse(null).success) {
        unsupported('The default does not satisfy its schema.');
      }
      if (mode == AcanthisSchemaMode.input) {
        schema = {
          'anyOf': [
            schema,
            {'type': 'null'},
          ],
        };
      }
    }
    // Metadata is presentation data, not a way to override structural keywords.
    final metadata = type.metadataEntry?.toJson();
    return {
      if (metadata != null)
        for (final key in [
          'title',
          'description',
          'deprecated',
          'readOnly',
          'writeOnly',
        ])
          if (metadata.containsKey(key)) key: metadata[key],
      ...schema,
    };
  }
}
