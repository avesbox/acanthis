import 'dart:collection';

import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/lazy_object_mapper.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/validators/map.dart';
import 'package:meta/meta.dart';
import 'package:nanoid2/nanoid2.dart';

/// A class to validate map types
class AcanthisMap<V> extends AcanthisType<Map<String, V>> {
  final Map<String, AcanthisType> _fields;

  /// The fields of the map
  Map<String, AcanthisType> get fields => UnmodifiableMapView(_fields);

  final bool _passthrough;
  final AcanthisType? _passthroughType;
  final List<_Dependency> _dependencies;
  final List<String> _optionalFields;

  /// Constructor of the map type
  const AcanthisMap(this._fields, {super.key})
      : _passthrough = false,
        _passthroughType = null,
        _dependencies = const [],
        _optionalFields = const [];

  AcanthisMap._({
    required Map<String, AcanthisType<dynamic>> fields,
    required bool passthrough,
    required AcanthisType? passthroughType,
    required List<_Dependency> dependencies,
    required List<String> optionalFields,
    super.isAsync,
    super.operations,
    super.key,
  })  : _fields = fields,
        _passthrough = passthrough,
        _passthroughType = passthroughType,
        _dependencies = dependencies,
        _optionalFields = optionalFields;

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
        optionalFields: [
          ..._optionalFields,
          ...fields,
        ],
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
    final parsed = <String, V>{};
    // Validate required fields
    for (var field in _fields.entries) {
      final key = field.key;
      final isOptional = _optionalFields.contains(key);
      final isNullable = field.value is AcanthisNullable;
      final passedValue = value[key];
      if (passedValue == null && !isOptional && !isNullable) {
        final checks = field.value.operations.cast<AcanthisCheck>();
        final validationErrors = [
          'Field $key is required',
          for (final check in checks) check.error,
        ];
        final errorMessage = '${validationErrors.join('.\n')}.';

        throw ValidationError(errorMessage);
      }
      if (passedValue == null && isOptional && !isNullable) {
        continue;
      }
      final fieldValue = field.value;
      if (fieldValue is LazyEntry) {
        parsed[key] = fieldValue.parse(passedValue, this).value;
      } else {
        parsed[key] = _fields[key]!.parse(passedValue).value;
      }
    }
    if (_passthrough) {
      for (var obj in value.entries) {
        if (!_fields.containsKey(obj.key)) {
          if (_passthroughType != null) {
            try {
              final parsedValue = _passthroughType.parse(obj.value);
              parsed[obj.key] = parsedValue.value;
            } on TypeError catch (_) {
              throw ValidationError(
                  '${obj.key} expose a value of type ${obj.value.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}');
            }
          } else {
            parsed[obj.key] = obj.value;
          }
        }
      }
    }
    if (_dependencies.isNotEmpty) {
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
    }
    return super.parse(parsed);
  }

  @override
  Future<AcanthisParseResult<Map<String, V>>> parseAsync(
      Map<String, V> value) async {
    final parsed = <String, V>{};
    final passedValue = Map<String, V>.from(value);
    // Parse each field
    for (var entry in _fields.entries) {
      final key = entry.key;
      final isOptional = _optionalFields.contains(key);
      if (!value.containsKey(key) && !isOptional) {
        final checks = entry.value.operations.cast<AcanthisCheck>();
        final validationErrors = [
          'Field $key is required',
          for (final check in checks) check.error,
        ];
        final errorMessage = '${validationErrors.join('.\n')}.';

        throw ValidationError(errorMessage);
      }
      if (value[key] == null &&
          isOptional &&
          entry.value is! AcanthisNullable) {
        continue;
      }
      final fieldValue = entry.value;
      if (fieldValue is LazyEntry) {
        parsed[key] =
            (await fieldValue.parseAsync(passedValue[key], this)).value;
      } else {
        final result = await fieldValue.parseAsync(passedValue[key]);
        parsed[key] = result.value;
      }
    }
    if (_passthrough) {
      for (var obj in value.entries) {
        if (!_fields.containsKey(obj.key)) {
          if (_passthroughType != null) {
            try {
              final parsedValue = await _passthroughType.parseAsync(obj.value);
              parsed[obj.key] = parsedValue.value;
            } on TypeError catch (_) {
              throw ValidationError(
                  '${obj.key} expose a value of type ${obj.value.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}');
            }
          } else {
            parsed[obj.key] = obj.value;
          }
        }
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
    return await super.parseAsync(parsed);
  }

  @override
  Future<AcanthisParseResult<Map<String, V>>> tryParseAsync(
      Map<String, V> value) async {
    final Map<String, V> passedValue = Map.from(value);
    final parsed = <String, V>{};
    final errors = <String, dynamic>{};
    for (var field in _fields.entries) {
      final key = field.key;
      final isOptional = _optionalFields.contains(key);
      if (!passedValue.containsKey(key) &&
          !isOptional &&
          field.value is! AcanthisNullable) {
        final checks = field.value.operations.cast<AcanthisCheck>();
        final validationErrors = {
          'required': 'Field is required',
          for (final check in checks) check.name: check.error,
        };

        errors[key] = validationErrors;
        continue;
      }
      if (passedValue[key] == null &&
          isOptional &&
          field.value is! AcanthisNullable) {
        continue;
      }
      final fieldValue = field.value;
      final AcanthisParseResult parsedValue;
      if (fieldValue is LazyEntry) {
        parsedValue = await fieldValue.tryParseAsync(passedValue[key], this);
      } else {
        parsedValue = await fieldValue.tryParseAsync(passedValue[key]);
      }
      parsed[key] = parsedValue.value;
      if (parsedValue.errors.isNotEmpty) {
        errors[key] = parsedValue.errors;
      }
    }
    if (_passthrough) {
      for (var obj in passedValue.entries) {
        if (!_fields.containsKey(obj.key)) {
          if (_passthroughType != null) {
            try {
              final parsedValue =
                  await _passthroughType.tryParseAsync(obj.value);
              parsed[obj.key] = parsedValue.value;
              errors[obj.key] = parsedValue.errors;
            } on TypeError catch (_) {
              errors[obj.key] = {
                'error':
                    '${obj.key} expose a value of type ${obj.value.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}'
              };
            }
          } else {
            parsed[obj.key] = obj.value;
          }
        }
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
    final result = await super.tryParseAsync(parsed);
    if (result.errors.isNotEmpty) {
      errors.addAll(result.errors);
    }
    return AcanthisParseResult(
        value: result.value,
        errors: errors,
        success: errors.isEmpty,
        metadata: result.metadata);
  }

  /// Override of [tryParse] from [AcanthisType]
  @override
  AcanthisParseResult<Map<String, V>> tryParse(Map<String, V> value) {
    if (isAsync) {
      throw AsyncValidationException(
          'Cannot use tryParse with async operations');
    }
    final parsed = <String, V>{};
    final errors = <String, dynamic>{};
    for (var field in _fields.entries) {
      final key = field.key;
      final isOptional = _optionalFields.contains(key);
      if (!value.containsKey(key) && !isOptional) {
        final checks = field.value.operations.cast<AcanthisCheck>();
        final validationErrors = {
          'required': 'Field is required',
          for (final check in checks) check.name: check.error,
        };

        errors[key] = validationErrors;
        continue;
      }
      if (value[key] == null &&
          isOptional &&
          field.value is! AcanthisNullable) {
        continue;
      }
      final fieldValue = field.value;
      final AcanthisParseResult parsedValue;
      if (fieldValue is LazyEntry) {
        parsedValue = fieldValue.tryParse(value[key], this);
      } else {
        parsedValue = fieldValue.tryParse(value[key]);
      }
      parsed[key] = parsedValue.value;
      if (parsedValue.errors.isNotEmpty) {
        errors[key] = parsedValue.errors;
      }
    }
    if (_passthrough) {
      for (var obj in value.entries) {
        if (!_fields.containsKey(obj.key)) {
          if (_passthroughType != null) {
            try {
              final parsedValue = _passthroughType.tryParse(obj.value);
              parsed[obj.key] = parsedValue.value;
              if (parsedValue.errors.isNotEmpty) {
                errors[obj.key] = parsedValue.errors;
              }
            } on TypeError catch (_) {
              errors[obj.key] = {
                'error':
                    '${obj.key} expose a value of type ${obj.value.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}'
              };
            }
          } else {
            parsed[obj.key] = obj.value;
          }
        }
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
    if (result.errors.isNotEmpty) {
      errors.addAll(result.errors);
    }
    return AcanthisParseResult(
        value: parsed,
        errors: errors,
        success: errors.isEmpty,
        metadata: result.metadata);
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
        dependencies: [
          ..._dependencies,
          _Dependency(dependent, dependendsOn, dependency),
        ],
        optionalFields: _optionalFields,
        operations: operations,
        isAsync: isAsync,
        key: key);
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
        fields: {
          ..._fields,
          ...newFields,
        },
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
        fields: {
          ..._fields,
          ...fields,
        },
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
        fields: newFields,
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
        fields: newFields,
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

  /// Allow for null values in the map
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

  /// Add a check to the map to check if it has at least [length] elements
  AcanthisMap<V> maxProperties(int constraint,
      {String? message, String Function(int constraintValue)? messageBuilder}) {
    return withCheck(MaxPropertiesCheck(
        constraintValue: constraint,
        message: message,
        messageBuilder: messageBuilder));
  }

  /// Add a check to the map to check if it has at most [length] elements
  AcanthisMap<V> minProperties(int constraint,
      {String? message, String Function(int constraintValue)? messageBuilder}) {
    return withCheck(MinPropertiesCheck(
        constraintValue: constraint,
        message: message,
        messageBuilder: messageBuilder));
  }

  /// Add a check to the map to check if it has exactly [length] elements
  AcanthisMap<V> lengthProperties(int constraint,
      {String? message, String Function(int constraintValue)? messageBuilder}) {
    return withCheck(LengthPropertiesCheck(
        constraintValue: constraint,
        message: message,
        messageBuilder: messageBuilder));
  }

  @override
  AcanthisMap<V> withAsyncCheck(AcanthisAsyncCheck<Map<String, V>> check) {
    return AcanthisMap<V>._(
        fields: _fields,
        passthrough: _passthrough,
        passthroughType: _passthroughType,
        dependencies: _dependencies,
        optionalFields: _optionalFields,
        operations: [
          ...operations,
          check,
        ],
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
        operations: [
          ...operations,
          check,
        ],
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
        operations: [
          ...operations,
          transformation,
        ],
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
    for (final operation in operations) {
      if (operation is MaxPropertiesCheck) {
        final op = operation as MaxPropertiesCheck;
        constraints[op.name] = op.constraintValue;
      }
      if (operation is MinPropertiesCheck) {
        final op = operation as MinPropertiesCheck;
        constraints[op.name] = op.constraintValue;
      }
      if (operation is LengthPropertiesCheck) {
        final op = operation as LengthPropertiesCheck;
        constraints['maxProperties'] = op.constraintValue;
        constraints['minProperties'] = op.constraintValue;
      }
    }
    return constraints;
  }
}

/// Create a map of [fields]
AcanthisMap object(Map<String, AcanthisType> fields) => AcanthisMap<dynamic>(
      fields,
    );

@immutable
class _Dependency {
  final String dependent;
  final String dependendsOn;
  final bool Function(dynamic, dynamic) dependency;

  const _Dependency(this.dependent, this.dependendsOn, this.dependency);
}

class LazyEntry<O> extends AcanthisType<O> {
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
  AcanthisParseResult<O> parse(O value, [AcanthisMap? parent]) {
    final type = _type(parent!);
    if (value is List) {
      value = List<Map<String, dynamic>>.from(value) as O;
    }
    return type.parse(value);
  }

  @override
  AcanthisParseResult<O> tryParse(O value, [AcanthisMap? parent]) {
    final type = _type(parent!);
    if (value is List) {
      value = List<Map<String, dynamic>>.from(value) as O;
    }
    return type.tryParse(value);
  }

  @override
  Future<AcanthisParseResult<O>> parseAsync(O value, [AcanthisMap? parent]) {
    final type = _type(parent!);
    if (value is List) {
      value = List<Map<String, dynamic>>.from(value) as O;
    }
    return type.parseAsync(value);
  }

  @override
  Future<AcanthisParseResult<O>> tryParseAsync(O value, [AcanthisMap? parent]) {
    final type = _type(parent!);
    if (value is List) {
      value = List<Map<String, dynamic>>.from(value) as O;
    }
    return type.tryParseAsync(value);
  }

  @override
  LazyEntry<O> withAsyncCheck(AcanthisAsyncCheck<O> check) {
    return LazyEntry(
      _type,
      operations: [
        ...operations,
        check,
      ],
      isAsync: true,
    );
  }

  @override
  LazyEntry<O> withCheck(AcanthisCheck<O> check) {
    return LazyEntry(
      _type,
      operations: [
        ...operations,
        check,
      ],
    );
  }

  @override
  LazyEntry<O> withTransformation(AcanthisTransformation<O> transformation) {
    return LazyEntry(
      _type,
      operations: [
        ...operations,
        transformation,
      ],
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
  LazyEntry<O> meta(MetadataEntry metadata) {
    throw UnimplementedError('The implementation must be done from the parent');
  }
}

LazyEntry<O> lazy<O>(
        AcanthisType<O> Function(AcanthisMap<dynamic> parent) type) =>
    LazyEntry<O>(type);
