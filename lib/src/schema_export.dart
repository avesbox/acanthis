import 'dart:collection';
import 'dart:convert';

import 'common/schema.dart';
import 'common/schema_graph.dart';
import 'schema_import.dart';
import 'types/list.dart';
import 'types/instance.dart';
import 'types/object.dart';
import 'types/record.dart';
import 'types/lazy.dart';
import 'types/number.dart';
import 'types/string.dart';
import 'types/boolean.dart';
import 'types/literal.dart';
import 'types/nullable.dart';
import 'types/union.dart';
import 'types/tuple.dart';
import 'types/template.dart';
import 'validators/common.dart';
import 'validators/number.dart';
import 'validators/string.dart';
import 'validators/list.dart';
import 'validators/object.dart';
import 'validators/boolean.dart';
import 'validators/nullable.dart';

part 'schema_export_collections.dart';

/// Select the accepted JSON input or successful JSON output contract.
enum AcanthisSchemaMode { input, output }

final class AcanthisSchemaExportException implements Exception {
  const AcanthisSchemaExportException(this.path, this.reason);
  final String path;
  final String reason;
  @override
  String toString() => 'Cannot export ${path.isEmpty ? "/" : path}: $reason';
}

final _exports = Expando<_CachedExports>();

sealed class _ExportState {
  const _ExportState();
}

final class _SeenExport extends _ExportState {
  const _SeenExport();
}

final class _CompiledExport extends _ExportState {
  const _CompiledExport(this.build, [this.auditDefaults]);
  final Map<String, Object?> Function() build;
  final void Function()? auditDefaults;
}

const _seen = _SeenExport();

final class _CachedExports {
  _ExportState? input;
  _ExportState? output;
}

extension AcanthisContractExport on Schema<Object?, Object?> {
  /// Format the same audited JSON Schema using [indent] spaces per level.
  String toPrettyJsonSchema({
    int indent = 2,
    AcanthisSchemaMode mode = AcanthisSchemaMode.input,
  }) {
    if (indent < 0) {
      throw ArgumentError.value(indent, 'indent', 'Must be nonnegative');
    }
    return JsonEncoder.withIndent(' ' * indent)
        .convert(toJsonSchema(mode: mode));
  }

  Map<String, Object?> exportJsonSchema({required AcanthisSchemaMode mode}) =>
      toJsonSchema(mode: mode);
  Map<String, Object?> exportOpenApiSchema({
    required AcanthisSchemaMode mode,
  }) => toOpenApiSchema(mode: mode);

  /// JSON Schema 2020-12 for the audited JSON-only runtime subset.
  Map<String, Object?> toJsonSchema({
    AcanthisSchemaMode mode = AcanthisSchemaMode.input,
  }) => {
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    ...toOpenApiSchema(mode: mode),
  };

  /// An OpenAPI 3.1 Schema Object, not a complete OpenAPI document.
  Map<String, Object?> toOpenApiSchema({required AcanthisSchemaMode mode}) {
    if (this is AcanthisJsonContract) {
      return (this as AcanthisJsonContract).exportDefinition();
    }
    final cached = _exports[this] ??= _CachedExports();
    final existing = mode == AcanthisSchemaMode.input
        ? cached.input
        : cached.output;
    if (existing is _CompiledExport) {
      existing.auditDefaults?.call();
      return existing.build();
    }
    final collection =
        metadataEntry != null ||
            this is InstanceType ||
            this is ObjectSchema ||
            this is AcanthisUnion ||
            this is AcanthisTuple ||
            this is AcanthisTemplate ||
            this is AcanthisList ||
            this is RecordSchema ||
            this is ResolvedSchema ||
            this is LazyEntry ||
            this is AcanthisLiteral ||
            this is AcanthisNullable
        ? _CollectionExport(mode)
        : null;
    final result = collection?.build(this) ?? _exportPrimitive(this, mode);
    // Metadata examples may contain caller-owned nested values.
    if (collection?.hasMetadata ?? false) return result;
    // One-off exports need no snapshot compiler. On the second export, compile
    // builders from isolated data; never retain the mutable map returned here.
    final next = existing == null
        ? _seen
        : _CompiledExport(_compileCopy(result), collection?.revalidateDefaults);
    if (mode == AcanthisSchemaMode.input) {
      cached.input = next;
    } else {
      cached.output = next;
    }
    return result;
  }
}

Map<String, Object?> _metadataAnnotations(
  Schema<Object?, Object?> schema,
  String path,
) {
  final metadata = schema.metadataEntry;
  if (metadata == null) return {};
  final Map<String, Object?> annotations;
  try {
    annotations = metadata.toJson();
  } on ArgumentError catch (error) {
    throw AcanthisSchemaExportException(path, error.message.toString());
  }
  if (annotations.containsKey('format')) {
    throw AcanthisSchemaExportException(
      path,
      'Metadata format is not an audited validation contract.',
    );
  }
  final id = annotations.remove('id');
  if (id != null) annotations['x-acanthis-id'] = id;
  final properties =
      annotations.remove('otherProperties') as Map<String, Object?>?;
  for (final entry
      in properties?.entries ?? const <MapEntry<String, Object?>>[]) {
    if (!entry.key.startsWith('x-') ||
        entry.key == 'x-acanthis-id' && id != null) {
      throw AcanthisSchemaExportException(
        path,
        'Additional metadata must use non-conflicting x- annotation names.',
      );
    }
    annotations[entry.key] = entry.value;
  }
  return annotations;
}

// Compile fresh-snapshot builders once. Repeated exports do not rediscover each
// scalar map/list shape or rerun the runtime-contract audit.
Map<String, Object?> Function() _compileCopy(Map<String, Object?> value) {
  if (value.isEmpty) return () => <String, Object?>{};
  if (value.length == 1) {
    final key = value.keys.first;
    final scalar = value[key];
    if (_scalar(scalar)) return () => {key: scalar};
    final child = _compileValue(scalar);
    return () => {key: child()};
  }
  final keys = value.keys.toList(growable: false);
  final values = [for (final key in keys) _compileValue(value[key])];
  return () => {for (var i = 0; i < keys.length; i++) keys[i]: values[i]()};
}

bool _scalar(Object? value) =>
    value == null || value is String || value is num || value is bool;

Object? Function() _compileValue(Object? value) {
  if (_scalar(value)) return () => value;
  if (value is List<Object?>) {
    if (value.every(_scalar)) {
      final snapshot = List<Object?>.unmodifiable(value);
      return () => List<Object?>.of(snapshot);
    }
    final children = [for (final item in value) _compileValue(item)];
    return () => [for (final build in children) build()];
  }
  return _compileCopy(value as Map<String, Object?>);
}

Map<String, Object?> _exportPrimitive(
  Schema<Object?, Object?> type,
  AcanthisSchemaMode mode,
) {
  Never unsupported(String reason) =>
      throw AcanthisSchemaExportException('', reason);
  if (type is AsyncSchema<Object?, Object?> && type.isAsync) {
    unsupported('Async validation cannot be represented.');
  }
  final List<Object> checks;
  final Object? defaultValue;
  final String kind;
  if (type is AcanthisString) {
    if (type.coercionEnabled) {
      unsupported('String coercion cannot be represented.');
    }
    if (type.transformations.isNotEmpty) {
      unsupported('Transformations cannot be represented.');
    }
    checks = type.checks;
    defaultValue = type.defaultValue;
    kind = 'string';
  } else if (type is AcanthisNumeric<num>) {
    if (type is AcanthisNumeric<int> || type is AcanthisNumeric<double>) {
      unsupported(
        'Dart int/double representation restrictions have no exact JSON number contract.',
      );
    }
    if (type.coercionEnabled) {
      unsupported('Number coercion cannot be represented.');
    }
    if (type.transformations.isNotEmpty) {
      unsupported('Transformations cannot be represented.');
    }
    checks = type.checks;
    defaultValue = type.defaultValue;
    kind = 'number';
  } else if (type is AcanthisBoolean) {
    if (type.coercionEnabled) {
      unsupported('Boolean coercion cannot be represented.');
    }
    if (type.transformations.isNotEmpty) {
      unsupported('Transformations cannot be represented.');
    }
    checks = type.checks;
    defaultValue = type.defaultValue;
    kind = 'boolean';
  } else {
    unsupported('${type.runtimeType} has no audited JSON contract.');
  }
  num finite(num value) {
    if (!value.isFinite) {
      unsupported('Constraint bounds must be finite JSON numbers.');
    }
    if (value < -9007199254740991 || value > 9007199254740991) {
      unsupported(
        'Numeric constraints outside the safe integer range have no audited mixed int/double contract.',
      );
    }
    return value;
  }

  Map<String, Object?> enumeration(Iterable<Object?> values) {
    final unique = LinkedHashSet<Object?>.of(values).toList();
    for (final value in unique) {
      if (value is! String &&
          value is! bool &&
          value is! num &&
          value != null) {
        unsupported('Only JSON scalar equality can be exported.');
      }
      if (value is num) finite(value);
    }
    return unique.isEmpty ? {'not': <String, Object?>{}} : {'enum': unique};
  }

  final constraints = <Map<String, Object?>>[
    for (final operation in checks)
      switch (operation) {
        IsTrueCheck() => {'const': true},
        IsFalseCheck() => {'const': false},
        LteNumberCheck<num>() => {'maximum': finite(operation.value)},
        GteNumberCheck<num>() => {'minimum': finite(operation.value)},
        LtNumberCheck<num>() => {'exclusiveMaximum': finite(operation.value)},
        GtNumberCheck<num>() => {'exclusiveMinimum': finite(operation.value)},
        BetweenNumberCheck<num>() => {
          'minimum': finite(operation.min),
          'maximum': finite(operation.max),
        },
        PositiveNumberCheck<num>() => {'exclusiveMinimum': 0},
        NegativeNumberCheck<num>() => {'exclusiveMaximum': 0},
        NonPositiveNumberCheck<num>() => {'maximum': 0},
        NonNegativeNumberCheck<num>() => {'minimum': 0},
        FiniteNumberCheck<num>() || NotNaNNumberCheck<num>() => {},
        InfiniteNumberCheck<num>() ||
        NaNNumberCheck<num>() => {'not': <String, Object?>{}},
        EnumeratedNumberCheck<num>() => enumeration(operation.values),
        ExactCheck<Object?>() => enumeration([operation.value]),
        ContainedStringCheck() => enumeration(operation.values),
        RequiredStringCheck() || NotEmptyStringCheck() => {'minLength': 1},
        MinStringLengthCheck() ||
        MaxStringLengthCheck() ||
        ExactStringLengthCheck() => unsupported(
          'String length checks count UTF-16 code units; JSON Schema counts Unicode code points.',
        ),
        IntegerNumberCheck<num>() || DoubleNumberCheck<num>() => unsupported(
          'Dart int/double representation checks have no exact JSON number contract.',
        ),
        MultipleOfCheck<num>() => unsupported(
          'Floating-point remainder has no audited JSON Schema multipleOf contract.',
        ),
        _ => unsupported(
          'Check ${operation.runtimeType} has no audited JSON contract.',
        ),
      },
  ];
  Map<String, Object?> schema = {
    'type': kind,
    if (constraints.isNotEmpty) 'allOf': constraints,
  };
  if (defaultValue != null) {
    if (defaultValue is num && !defaultValue.isFinite) {
      unsupported('The default must be a finite JSON value.');
    }
    if (!type.tryParse(null).isValid) {
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
  return schema;
}
