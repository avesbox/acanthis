import 'dart:collection';

import 'package:acanthis/src/exceptions/async_exception.dart';
import 'package:acanthis/src/lazy_object_mapper.dart';
import 'package:acanthis/src/registries/metadata_registry.dart';
import 'package:acanthis/src/types/nullable.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:meta/meta.dart';
import 'package:nanoid2/nanoid2.dart';

import '../exceptions/validation_error.dart';
import 'types.dart';

/// A class to validate map types
class AcanthisMap<V> extends AcanthisType<Map<String, V>> {
  final IMap<String, AcanthisType> _fields;
  Map<String, AcanthisType> get fields => UnmodifiableMapView(_fields.unlock);

  final bool _passthrough;
  final AcanthisType? _passthroughType;
  final IList<_Dependency> _dependencies;
  final IList<String> _optionalFields;

  const AcanthisMap(this._fields, {super.key})
      : _passthrough = false,
        _passthroughType = null,
        _dependencies = const IList.empty(),
        _optionalFields = const IList.empty();

  AcanthisMap._({
    required IMap<String, AcanthisType<dynamic>> fields,
    required bool passthrough,
    required AcanthisType? passthroughType,
    required IList<_Dependency> dependencies,
    required IList<String> optionalFields,
    super.isAsync,
    super.operations,
    super.key,
  })  : _fields = fields,
        _passthrough = passthrough,
        _passthroughType = passthroughType,
        _dependencies = dependencies,
        _optionalFields = optionalFields;

  Map<String, V> _parse(Map<String, V> value) {
    final parsed = <String, V>{};
    final optionalFieldsSet = _optionalFields.toSet();

    // Validate required fields
    for (var field in _fields.keys) {
      if (!value.containsKey(field) && !optionalFieldsSet.contains(field)) {
        throw ValidationError('Field $field is required');
      }
    }
    for (var obj in value.entries) {
      if (!_fields.containsKey(obj.key)) {
        if (_passthrough) {
          if (_passthroughType != null) {
            try {
              final parsedValue = _passthroughType.parse(obj.value);
              parsed[obj.key] = parsedValue.value;
            } on TypeError catch (_) {
              throw ValidationError(
                  '$obj.key expose a value of type ${obj.value.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}');
            }
          } else {
            parsed[obj.key] = obj.value;
          }
          continue;
        }
        throw ValidationError('Field ${obj.key} is not allowed in this object');
      }
      if (_fields[obj.key] is LazyEntry) {
        final type = (_fields[obj.key] as LazyEntry).call(this);
        if (obj.value is List) {
          parsed[obj.key] = type
              .parse(List<Map<String, dynamic>>.from(obj.value as List))
              .value;
        } else {
          parsed[obj.key] = type.parse(obj.value).value;
        }
      } else {
        parsed[obj.key] = _fields[obj.key]!.parse(obj.value).value;
      }
    }
    for (var dependency in _dependencies) {
      final dependFrom = _keyQuery(dependency.dependendsOn, value);
      final dependTo = _keyQuery(dependency.dependent, value);
      if (dependFrom != null && dependTo != null) {
        if (!dependency.dependency(dependFrom, dependTo)) {
          throw ValidationError(
              'Dependency not met: ${dependency.dependendsOn}->${dependency.dependent}');
        }
      } else {
        throw ValidationError(
            'The dependency or dependFrom field does not exist in the map');
      }
    }
    final result = super.parse(parsed);
    return result.value;
  }

  Future<Map<String, V>> _parseAsync(Map<String, V> value) async {
    final parsed = <String, V>{};
    final optionalFieldsSet = _optionalFields.toSet();

    // Validate required fields
    for (var field in _fields.keys) {
      if (!value.containsKey(field) && !optionalFieldsSet.contains(field)) {
        throw ValidationError('Field $field is required');
      }
    }

    // Parse each field
    for (var entry in value.entries) {
      final key = entry.key;
      final fieldValue = entry.value;

      if (!_fields.containsKey(key)) {
        if (_passthrough) {
          if (_passthroughType != null) {
            try {
              final parsedValue = await _passthroughType.parseAsync(fieldValue);
              parsed[key] = parsedValue.value;
            } on TypeError catch (_) {
              throw ValidationError(
                  '$key expose a value of type ${fieldValue.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}');
            }
          } else {
            parsed[key] = fieldValue;
          }
          continue;
        }
        throw ValidationError('Field $key is not allowed in this object');
      }

      final fieldType = _fields[key];
      if (fieldType is LazyEntry) {
        final type = fieldType.call(this);
        final result = await type.parseAsync(fieldValue);
        parsed[key] = result.value;
      } else {
        final result = await fieldType!.parseAsync(fieldValue);
        parsed[key] = result.value;
      }
    }

    // Validate dependencies
    for (var dependency in _dependencies) {
      final dependFrom = _keyQuery(dependency.dependendsOn, value);
      final dependTo = _keyQuery(dependency.dependent, value);

      if (dependFrom != null && dependTo != null) {
        if (!dependency.dependency(dependFrom, dependTo)) {
          throw ValidationError(
              'Dependency not met: ${dependency.dependendsOn}->${dependency.dependent}');
        }
      } else {
        throw ValidationError(
            'The dependency or dependFrom field does not exist in the map');
      }
    }

    final result = await super.parseAsync(parsed);
    return result.value;
  }

  (Map<String, V>, Map<String, dynamic>) _tryParse(Map<String, V> value) {
    final parsed = <String, V>{};
    final errors = <String, dynamic>{};
    final optionalFieldsSet = _optionalFields.toSet();

    // Validate required fields
    for (var field in _fields.keys) {
      if (!value.containsKey(field) && !optionalFieldsSet.contains(field)) {
        errors[field] = {'required': 'Field is required'};
      }
    }

    // Parse each field
    for (var entry in value.entries) {
      final key = entry.key;
      final fieldValue = entry.value;

      if (!_fields.containsKey(key)) {
        if (_passthrough) {
          if (_passthroughType != null) {
            try {
              final parsedValue = _passthroughType.tryParse(fieldValue);
              parsed[key] = parsedValue.value;
              errors[key] = parsedValue.errors;
            } on TypeError catch (_) {
              errors[key] = {
                'error':
                    '$key expose a value of type ${fieldValue.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}'
              };
            }
          } else {
            parsed[key] = fieldValue;
          }
        } else {
          errors[key] = {'notAllowed': 'Field is not allowed in this object'};
        }
        continue;
      }

      final fieldType = _fields[key];
      final AcanthisParseResult parsedValue;
      if (fieldType is LazyEntry) {
        final resolvedType = fieldType.call(this);
        if (fieldValue is List) {
          parsedValue = resolvedType
              .tryParse(List<Map<String, dynamic>>.from(fieldValue as List));
        } else {
          parsedValue = resolvedType.tryParse(fieldValue);
        }
      } else {
        parsedValue = fieldType!.tryParse(fieldValue);
      }

      parsed[key] = parsedValue.value;
      if (parsedValue.errors.isNotEmpty) {
        errors[key] = parsedValue.errors;
      }
    }

    // Validate dependencies
    for (var dependency in _dependencies) {
      final dependFrom = _keyQuery(dependency.dependendsOn, value);
      final dependTo = _keyQuery(dependency.dependent, value);

      if (dependFrom != null && dependTo != null) {
        if (!dependency.dependency(dependFrom, dependTo)) {
          errors[dependency.dependent] = {'dependency': 'Dependency not met'};
        }
      } else {
        errors[dependency.dependent] = {
          'dependency[${dependency.dependendsOn}->${dependency.dependent}]':
              'The dependency or dependFrom field does not exist in the map'
        };
      }
    }

    final result = super.tryParse(parsed);
    return (result.value, {...errors, ...result.errors});
  }

  Future<({Map<String, V> values, Map<String, dynamic> errors})> _tryParseAsync(
      Map<String, V> value) async {
    final parsed = <String, V>{};
    final errors = <String, dynamic>{};
    final optionalFieldsSet = _optionalFields.toSet();

    // Validate required fields
    for (var field in _fields.keys) {
      if (!value.containsKey(field) && !optionalFieldsSet.contains(field)) {
        errors[field] = {'required': 'Field is required'};
      }
    }

    // Parse each field
    for (var entry in value.entries) {
      final key = entry.key;
      final fieldValue = entry.value;

      if (!_fields.containsKey(key)) {
        if (_passthrough) {
          if (_passthroughType != null) {
            try {
              final parsedValue =
                  await _passthroughType.tryParseAsync(fieldValue);
              parsed[key] = parsedValue.value;
              errors[key] = parsedValue.errors;
            } on TypeError catch (_) {
              errors[key] = {
                'error':
                    '$key expose a value of type ${fieldValue.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}'
              };
            }
          } else {
            parsed[key] = fieldValue;
          }
        } else {
          errors[key] = {'notAllowed': 'Field is not allowed in this object'};
        }
        continue;
      }

      final fieldType = _fields[key];
      final AcanthisParseResult parsedValue;

      try {
        if (fieldType is LazyEntry) {
          final resolvedType = fieldType.call(this);
          if (fieldValue is List) {
            parsedValue = await resolvedType.tryParseAsync(
                List<Map<String, dynamic>>.from(fieldValue as List));
          } else {
            parsedValue = await resolvedType.tryParseAsync(fieldValue);
          }
        } else {
          parsedValue = await fieldType!.tryParseAsync(fieldValue);
        }
        parsed[key] = parsedValue.value;
        errors[key] = parsedValue.errors;
      } catch (e) {
        errors[key] = {'error': e.toString()};
      }
    }

    // Validate dependencies
    for (var dependency in _dependencies) {
      final dependFrom = _keyQuery(dependency.dependendsOn, value);
      final dependTo = _keyQuery(dependency.dependent, value);

      if (dependFrom != null && dependTo != null) {
        if (!dependency.dependency(dependFrom, dependTo)) {
          errors[dependency.dependent] = {'dependency': 'Dependency not met'};
        }
      } else {
        errors[dependency.dependent] = {
          'dependency[${dependency.dependendsOn}->${dependency.dependent}]':
              'The dependency or dependFrom field does not exist in the map'
        };
      }
    }

    // Parse the final result
    final result = await super.tryParseAsync(parsed);
    return (values: result.value, errors: {...errors, ...result.errors});
  }

  dynamic _keyQuery(String key, Map<String, V> value) {
    final keys = key.split('.');
    dynamic result = value;
    for (var k in keys) {
      if (result is Map<String, dynamic>) {
        if (result.containsKey(k)) {
          result = result[k];
        } else {
          return null;
        }
      } else if (result is List) {
        final kIndex = int.tryParse(k.replaceAll('[', '').replaceAll(']', ''));
        if (kIndex != null && kIndex < result.length) {
          result = result[kIndex];
        } else {
          return null;
        }
      } else {
        return null;
      }
    }
    return result;
  }

  /// Add optional fields to the map
  ///
  /// The optionals are valid only for the current layer of the object
  AcanthisMap<V> optionals(List<String> fields) {
    return AcanthisMap<V>._(
        fields: _fields,
        passthrough: _passthrough,
        passthroughType: _passthroughType,
        dependencies: _dependencies,
        optionalFields: _optionalFields.addAll(fields),
        operations: operations,
        isAsync: isAsync,
        key: key);
  }

  /// Override of [parse] from [AcanthisType]
  @override
  AcanthisParseResult<Map<String, V>> parse(Map<String, V> value) {
    if (isAsync) {
      throw AsyncValidationException(
          'Cannot use tryParse with async operations');
    }
    final parsed = _parse(value);
    return AcanthisParseResult(
        value: parsed, metadata: MetadataRegistry().get(key));
  }

  @override
  Future<AcanthisParseResult<Map<String, V>>> parseAsync(
      Map<String, V> value) async {
    final parsed = await _parseAsync(value);
    return AcanthisParseResult(
        value: parsed, metadata: MetadataRegistry().get(key));
  }

  @override
  Future<AcanthisParseResult<Map<String, V>>> tryParseAsync(
      Map<String, V> value) async {
    final parsed = await _tryParseAsync(value);
    return AcanthisParseResult(
        value: parsed.values,
        errors: parsed.errors,
        success: _recursiveSuccess(parsed.errors),
        metadata: MetadataRegistry().get(key));
  }

  /// Override of [tryParse] from [AcanthisType]
  @override
  AcanthisParseResult<Map<String, V>> tryParse(Map<String, V> value) {
    if (isAsync) {
      throw AsyncValidationException(
          'Cannot use tryParse with async operations');
    }
    final (parsed, errors) = _tryParse(value);
    return AcanthisParseResult(
        value: parsed,
        errors: errors,
        success: _recursiveSuccess(errors),
        metadata: MetadataRegistry().get(key));
  }

  /// Add a field dependency to the map to validate the map based on the [condition]
  /// [dependency] is the field that depends on [dependFrom]
  AcanthisMap<V> addFieldDependency({
    required String dependent,
    required String dependendsOn,
    required bool Function(dynamic, dynamic) dependency,
  }) {
    return AcanthisMap<V>._(
        fields: _fields,
        passthrough: _passthrough,
        passthroughType: _passthroughType,
        dependencies:
            _dependencies.add(_Dependency(dependent, dependendsOn, dependency)),
        optionalFields: _optionalFields,
        operations: operations,
        isAsync: isAsync,
        key: key);
  }

  bool _recursiveSuccess(Map<String, dynamic> errors) {
    List<bool> results = [];
    for (var error in errors.values) {
      results.add(error is Map<String, dynamic>
          ? _recursiveSuccess(error)
          : error.isEmpty);
    }
    return results.every((element) => element);
  }

  /// Add field(s) to the map
  /// It won't overwrite existing fields
  AcanthisMap<V> extend(Map<String, AcanthisType> fields) {
    final newFields = <String, AcanthisType>{};
    for (var field in fields.keys) {
      if (!_fields.containsKey(field)) {
        newFields[field] = fields[field]!;
      }
    }
    return AcanthisMap<V>._(
        fields: _fields.addAll(newFields.toIMap()),
        passthrough: _passthrough,
        passthroughType: _passthroughType,
        dependencies: _dependencies,
        optionalFields: _optionalFields,
        operations: operations,
        isAsync: isAsync,
        key: key);
  }

  /// Merge field(s) to the map
  /// if a field already exists, it will be overwritten
  AcanthisMap<V> merge(Map<String, AcanthisType> fields) {
    return AcanthisMap<V>._(
        fields: _fields.addAll(fields.toIMap()),
        passthrough: _passthrough,
        passthroughType: _passthroughType,
        dependencies: _dependencies,
        optionalFields: _optionalFields,
        operations: operations,
        isAsync: isAsync,
        key: key);
  }

  /// Pick field(s) from the map
  AcanthisMap<V> pick(Iterable<String> fields) {
    final newFields = <String, AcanthisType>{};
    for (var field in fields) {
      if (_fields.containsKey(field)) {
        newFields[field] = _fields[field]!;
      }
    }
    return AcanthisMap<V>._(
        fields: newFields.toIMap(),
        passthrough: _passthrough,
        passthroughType: _passthroughType,
        dependencies: _dependencies,
        optionalFields: _optionalFields,
        operations: operations,
        isAsync: isAsync,
        key: key);
  }

  /// Omit field(s) from the map
  AcanthisMap<V> omit(Iterable<String> toOmit) {
    final newFields = <String, AcanthisType>{};
    for (var field in _fields.keys) {
      if (!toOmit.contains(field)) {
        newFields[field] = _fields[field]!;
      }
    }
    return AcanthisMap<V>._(
        fields: newFields.toIMap(),
        passthrough: _passthrough,
        passthroughType: _passthroughType,
        dependencies: _dependencies,
        optionalFields: _optionalFields,
        operations: operations,
        isAsync: isAsync,
        key: key);
  }

  /// Allow unknown keys in the map
  AcanthisMap<V> passthrough({AcanthisType? type}) {
    return AcanthisMap<V>._(
        fields: _fields,
        passthrough: true,
        passthroughType: type,
        dependencies: _dependencies,
        optionalFields: _optionalFields,
        operations: operations,
        isAsync: isAsync,
        key: key);
  }

  AcanthisMap<V?> partial({bool deep = false}) {
    if (deep) {
      return AcanthisMap<V?>(_fields.map((key, value) {
        if (value is AcanthisMap) {
          return MapEntry(key, value.partial(deep: deep));
        }
        if (value is LazyEntry) {
          return MapEntry(key, value.call(this).nullable());
        }
        return MapEntry(key, value.nullable());
      }));
    }
    return AcanthisMap<V?>(
        _fields.map((key, value) => MapEntry(key, value.nullable())));
  }

  AcanthisMap<V> maxProperties(int constraint) {
    return withCheck(ContraintsPropertiesNumber.maxProperties(constraint));
  }

  AcanthisMap<V> minProperties(int constraint) {
    return withCheck(ContraintsPropertiesNumber.minProperties(constraint));
  }

  @override
  AcanthisMap<V> withAsyncCheck(AcanthisAsyncCheck<Map<String, V>> check) {
    return AcanthisMap<V>._(
        fields: _fields,
        passthrough: _passthrough,
        passthroughType: _passthroughType,
        dependencies: _dependencies,
        optionalFields: _optionalFields,
        operations: operations.add(check),
        isAsync: true,
        key: key);
  }

  @override
  AcanthisMap<V> withCheck(AcanthisCheck<Map<String, V>> check) {
    return AcanthisMap<V>._(
        fields: _fields,
        passthrough: _passthrough,
        passthroughType: _passthroughType,
        dependencies: _dependencies,
        optionalFields: _optionalFields,
        operations: operations.add(check),
        isAsync: isAsync,
        key: key);
  }

  @override
  AcanthisMap<V> withTransformation(
      AcanthisTransformation<Map<String, V>> transformation) {
    return AcanthisMap<V>._(
        fields: _fields,
        passthrough: _passthrough,
        passthroughType: _passthroughType,
        dependencies: _dependencies,
        optionalFields: _optionalFields,
        operations: operations.add(transformation),
        isAsync: isAsync,
        key: key);
  }

  @override
  AcanthisMap<V> meta(MetadataEntry<Map<String, V>> metadata) {
    String objectKey = key;
    if (objectKey.isEmpty) {
      objectKey = nanoid();
    }
    MetadataRegistry().add(objectKey, metadata);
    return AcanthisMap<V>._(
      fields: _fields,
      passthrough: _passthrough,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      operations: operations,
      isAsync: isAsync,
      key: objectKey,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    final schema = <String, dynamic>{};
    final lazyEntries =
        _fields.entries.where((entry) => entry.value is LazyEntry).toList();
    for (var entry in _fields.entries) {
      if (entry.value is LazyEntry) {
        final entryKey = '${entry.key}-lazy';
        schema[entry.key] = {r'$ref': '#/\$defs/$entryKey'};
      } else {
        schema[entry.key] = entry.value.toJsonSchema();
      }
    }
    final defsMap = {};
    final lazyObjectMapper = LazyObjectMapper();
    for (var entry in lazyEntries) {
      final entryKey = '${entry.key}-lazy';
      final lazyEntry = lazyObjectMapper.get(entryKey);
      if (lazyEntry == false) {
        defsMap[entryKey] = (entry.value as LazyEntry)
            .toJsonSchema(parent: this, defs: true, defKey: entryKey);
      }
    }
    final metadata = MetadataRegistry().get<Map<String, dynamic>>(key);
    for (final key in defsMap.keys) {
      lazyObjectMapper.remove(key);
    }
    final constraints = _getConstraints();
    return {
      if (defsMap.isNotEmpty) r'$defs': defsMap,
      'type': 'object',
      if (metadata != null) ...metadata.toJson(),
      'properties': schema,
      'additionalProperties': _passthrough == false
          ? false
          : _passthroughType?.toJsonSchema() ?? true,
      'required':
          _fields.keys.where((key) => !_optionalFields.contains(key)).toList(),
      if (constraints.isNotEmpty) ...constraints,
    };
  }

  Map<String, dynamic> _getConstraints() {
    final constraints = <String, dynamic>{};
    for (var operation in operations) {
      if (operation is ContraintsPropertiesNumber) {
        constraints[operation.name] = operation.constraintValue;
      }
    }
    return constraints;
  }
}

class ContraintsPropertiesNumber<V> extends AcanthisCheck<Map<String, V>> {
  final int constraintValue;

  const ContraintsPropertiesNumber({
    required this.constraintValue,
    required super.name,
    required super.error,
    required super.onCheck,
  });

  static ContraintsPropertiesNumber<V> maxProperties<V>(
    int constraint,
  ) {
    return ContraintsPropertiesNumber<V>(
      constraintValue: constraint,
      name: 'maxProperties',
      error: 'The map has more than $constraint fields',
      onCheck: (value) => value.length <= constraint,
    );
  }

  static ContraintsPropertiesNumber<V> minProperties<V>(
    int constraint,
  ) {
    return ContraintsPropertiesNumber<V>(
      constraintValue: constraint,
      name: 'minProperties',
      error: 'The map has less than $constraint fields',
      onCheck: (value) => value.length >= constraint,
    );
  }
}

/// Create a map of [fields]
AcanthisMap object(Map<String, AcanthisType> fields) => AcanthisMap<dynamic>(
      fields.toIMap(),
    );

@immutable
class _Dependency {
  final String dependent;
  final String dependendsOn;
  final bool Function(dynamic, dynamic) dependency;

  const _Dependency(this.dependent, this.dependendsOn, this.dependency);
}

class LazyEntry<O> extends AcanthisType<dynamic> {
  final AcanthisType<O> Function(AcanthisMap parent) _type;

  const LazyEntry(
    this._type, {
    super.operations,
    super.isAsync,
  });

  AcanthisType<O> call(AcanthisMap<dynamic> parent) {
    final type = _type(parent);
    if (type is LazyEntry) {
      throw StateError('Circular dependency detected');
    }
    return type;
  }

  @override
  AcanthisNullable nullable({defaultValue}) {
    throw UnimplementedError('The implementation must be done from the parent');
  }

  @override
  LazyEntry withAsyncCheck(AcanthisAsyncCheck check) {
    return LazyEntry(
      _type,
      operations: operations.add(check),
      isAsync: true,
    );
  }

  @override
  LazyEntry withCheck(AcanthisCheck check) {
    return LazyEntry(
      _type,
      operations: operations.add(check),
    );
  }

  @override
  LazyEntry withTransformation(AcanthisTransformation transformation) {
    return LazyEntry(
      _type,
      operations: operations.add(transformation),
    );
  }

  @override
  Map<String, dynamic> toJsonSchema(
      {AcanthisMap<dynamic>? parent, bool defs = false, String defKey = ''}) {
    final lazyObjectMapper = LazyObjectMapper();
    final type = _type(parent!);
    if (type is LazyEntry) {
      throw StateError('Circular dependency detected');
    }
    if (defs) {
      lazyObjectMapper.add(defKey);
    }
    final schema = type.toJsonSchema();
    return schema;
  }

  @override
  LazyEntry meta(MetadataEntry metadata) {
    throw UnimplementedError('The implementation must be done from the parent');
  }
}

LazyEntry<O> lazy<O>(
        AcanthisType<O> Function(AcanthisMap<dynamic> parent) type) =>
    LazyEntry<O>(type);
