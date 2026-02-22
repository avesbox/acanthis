import 'dart:collection';

import 'package:acanthis/acanthis.dart';
import 'package:acanthis/src/lazy_object_mapper.dart';
import 'package:acanthis/src/operations/checks.dart';
import 'package:acanthis/src/operations/transformations.dart';
import 'package:acanthis/src/validators/map.dart';
import 'package:meta/meta.dart';
import 'package:nanoid2/nanoid2.dart';

class _MissingValue {
  const _MissingValue();
}

const _missing = _MissingValue();

/// A class to validate map types
class AcanthisMap<V> extends AcanthisType<Map<String, V>> {
  final Map<String, AcanthisType> _fields;

  /// The fields of the map
  Map<String, AcanthisType> get fields => UnmodifiableMapView(_fields);

  final bool _passthrough;
  final AcanthisType? _passthroughType;
  final List<_Dependency> _dependencies;
  final Set<String> _optionalFields;
  final bool _localPure;
  late final List<String> _keys;
  late final List<AcanthisType> _types;
  late final List<bool> _isOptional;
  late final List<bool> _isNullable;
  late final int _length;
  late final Map<String, dynamic> _templateMap;
  late final bool _isPure;

  @override
  bool get isPure => _localPure && _isPure && super.isPure;

  /// Constructor of the map type
  AcanthisMap(
    this._fields, {
    super.key,
    super.metadataEntry,
    bool isPure = true,
  }) : _passthrough = false,
       _passthroughType = null,
       _dependencies = const [],
       _optionalFields = const {},
       _localPure = isPure {
    _initializeCaches();
  }

  AcanthisMap._({
    required Map<String, AcanthisType<dynamic>> fields,
    required bool passthrough,
    required AcanthisType? passthroughType,
    required List<_Dependency> dependencies,
    required Set<String> optionalFields,
    bool isPure = true,
    super.isAsync,
    super.operations,
    super.key,
    super.metadataEntry,
    super.defaultValue,
  }) : _fields = fields,
       _passthrough = passthrough,
       _passthroughType = passthroughType,
       _dependencies = dependencies,
       _optionalFields = optionalFields,
       _localPure = isPure {
    _initializeCaches();
  }

  void _initializeCaches() {
    _keys = _fields.keys.toList(growable: false);
    _types = _keys.map((key) => _fields[key]!).toList(growable: false);
    _isOptional = _keys
        .map((key) => _optionalFields.contains(key))
        .toList(growable: false);
    _isNullable = _types
        .map((type) => type is AcanthisNullable)
        .toList(growable: false);
    _length = _keys.length;
    _templateMap = {for (final key in _keys) key: null};
    _isPure =
        _types.every((type) => type.isPure && type.defaultValue == null) &&
        !_passthrough &&
        defaultValue == null;
  }

  void _throwRequiredFieldError(String fieldKey, AcanthisType fieldType) {
    final checks = fieldType.operations.whereType<AcanthisCheck>();
    final validationErrors = [
      'Field $fieldKey is required',
      for (final check in checks) check.error,
    ];
    throw ValidationError('${validationErrors.join('.\n')}.');
  }

  void _validateDependenciesThrow(Map<String, V> value) {
    if (_dependencies.isEmpty) {
      return;
    }
    final queryCache = <String, dynamic>{};
    for (final dependency in _dependencies) {
      queryCache.putIfAbsent(
        dependency.dependendsOn,
        () => _keyQuery(dependency.dependendsOn, value),
      );
      queryCache.putIfAbsent(
        dependency.dependent,
        () => _keyQuery(dependency.dependent, value),
      );
      final dependFrom = queryCache[dependency.dependendsOn];
      final dependTo = queryCache[dependency.dependent];
      if (dependFrom != null && dependTo != null) {
        if (!dependency.dependency(dependFrom, dependTo)) {
          throw ValidationError(
            'Dependency not met: ${dependency.dependendsOn}->${dependency.dependent}',
          );
        }
      } else {
        throw ValidationError(
          'The dependency or dependFrom field does not exist in the map',
        );
      }
    }
  }

  void _validateDependenciesTry(
    Map<String, V> value,
    Map<String, dynamic> errors,
  ) {
    if (_dependencies.isEmpty) {
      return;
    }
    final queryCache = <String, dynamic>{};
    for (final dependency in _dependencies) {
      queryCache.putIfAbsent(
        dependency.dependendsOn,
        () => _keyQuery(dependency.dependendsOn, value),
      );
      queryCache.putIfAbsent(
        dependency.dependent,
        () => _keyQuery(dependency.dependent, value),
      );
      final dependFrom = queryCache[dependency.dependendsOn];
      final dependTo = queryCache[dependency.dependent];
      if (dependFrom != null && dependTo != null) {
        if (!dependency.dependency(dependFrom, dependTo)) {
          errors[dependency.dependent] = {'dependency': 'Dependency not met'};
        }
      } else {
        errors[dependency.dependent] = {
          'dependency[${dependency.dependendsOn}->${dependency.dependent}]':
              'The dependency or dependFrom field does not exist in the map',
        };
      }
    }
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
      optionalFields: {..._optionalFields, ...fields},
      operations: operations,
      isAsync: isAsync,
      key: key,
    );
  }

  @override
  Map<String, V> parseInternal(dynamic value) {
    final input = value as Map<String, V>;
    if (isPure) {
      for (int i = 0; i < _length; i++) {
        final fieldKey = _keys[i];
        final fieldType = _types[i];
        final passedValue = input[fieldKey] ?? _missing;
        if (identical(passedValue, _missing) &&
            !_isOptional[i] &&
            !_isNullable[i]) {
          _throwRequiredFieldError(fieldKey, fieldType);
        }
        if (identical(passedValue, _missing) &&
            _isOptional[i] &&
            !_isNullable[i]) {
          continue;
        }
        if (fieldType is LazyEntry) {
          (fieldType)
              .call(this)
              .parseInternal(
                identical(passedValue, _missing) ? null : passedValue,
              );
        } else {
          fieldType.parseInternal(
            identical(passedValue, _missing) ? null : passedValue,
          );
        }
      }
      _validateDependenciesThrow(input);
      return super.parseInternal(input);
    }

    final parsed = Map<String, V>.of(_templateMap as Map<String, V>);
    for (int i = 0; i < _length; i++) {
      final fieldKey = _keys[i];
      final fieldType = _types[i];
      final passedValue = input[fieldKey] ?? _missing;
      if (identical(passedValue, _missing) &&
          !_isOptional[i] &&
          !_isNullable[i]) {
        _throwRequiredFieldError(fieldKey, fieldType);
      }
      if (identical(passedValue, _missing) &&
          _isOptional[i] &&
          !_isNullable[i]) {
        continue;
      }
      if (fieldType is LazyEntry) {
        parsed[fieldKey] = (fieldType)
            .call(this)
            .parseInternal(
              identical(passedValue, _missing) ? null : passedValue,
            );
      } else {
        parsed[fieldKey] = fieldType.parseInternal(
          identical(passedValue, _missing) ? null : passedValue,
        );
      }
    }

    if (_passthrough) {
      final passthroughKeys = input.keys.toSet().difference(
        _fields.keys.toSet(),
      );
      for (final key in passthroughKeys) {
        final objValue = input[key];
        if (_passthroughType != null) {
          try {
            parsed[key] = _passthroughType.parseInternal(objValue);
          } on TypeError catch (_) {
            throw ValidationError(
              '$key expose a value of type ${objValue.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}',
            );
          }
        } else {
          parsed[key] = objValue as V;
        }
      }
    }

    _validateDependenciesThrow(input);
    return super.parseInternal(parsed);
  }

  @override
  Map<String, V> tryParseInternal(
    dynamic value, {
    required Map<String, dynamic> errors,
  }) {
    final input = value as Map<String, V>;
    if (isPure) {
      for (int i = 0; i < _length; i++) {
        final fieldKey = _keys[i];
        final fieldType = _types[i];
        dynamic passedValue = input[fieldKey] ?? _missing;
        if (identical(passedValue, _missing) &&
            fieldType.defaultValue != null) {
          passedValue = fieldType.defaultValue;
        }
        if (identical(passedValue, _missing) &&
            !_isOptional[i] &&
            !_isNullable[i]) {
          final checks = fieldType.operations.whereType<AcanthisCheck>();
          errors[fieldKey] = {
            'required': 'Field $fieldKey is required',
            for (final check in checks) check.name: check.error,
          };
          continue;
        }
        if (identical(passedValue, _missing) &&
            _isOptional[i] &&
            !_isNullable[i]) {
          continue;
        }
        final fieldErrors = <String, dynamic>{};
        final valueToParse = identical(passedValue, _missing)
            ? null
            : passedValue;
        if (fieldType is LazyEntry) {
          (fieldType)
              .call(this)
              .tryParseInternal(valueToParse, errors: fieldErrors);
        } else {
          fieldType.tryParseInternal(valueToParse, errors: fieldErrors);
        }
        if (fieldErrors.isNotEmpty) {
          errors[fieldKey] = fieldErrors;
        }
      }
      _validateDependenciesTry(input, errors);
      return super.tryParseInternal(input, errors: errors);
    }

    final parsed = Map<String, V>.of(_templateMap as Map<String, V>);
    for (int i = 0; i < _length; i++) {
      final fieldKey = _keys[i];
      final fieldType = _types[i];
      dynamic passedValue = input[fieldKey] ?? _missing;
      if (identical(passedValue, _missing) && fieldType.defaultValue != null) {
        passedValue = fieldType.defaultValue;
      }
      if (identical(passedValue, _missing) &&
          !_isOptional[i] &&
          !_isNullable[i]) {
        final checks = fieldType.operations.whereType<AcanthisCheck>();
        errors[fieldKey] = {
          'required': 'Field $fieldKey is required',
          for (final check in checks) check.name: check.error,
        };
        continue;
      }
      if (identical(passedValue, _missing) &&
          _isOptional[i] &&
          !_isNullable[i]) {
        continue;
      }
      final fieldErrors = <String, dynamic>{};
      final valueToParse = identical(passedValue, _missing)
          ? null
          : passedValue;
      final fieldValue = fieldType is LazyEntry
          ? (fieldType)
                .call(this)
                .tryParseInternal(valueToParse, errors: fieldErrors)
          : fieldType.tryParseInternal(valueToParse, errors: fieldErrors);
      parsed[fieldKey] = fieldValue;
      if (fieldErrors.isNotEmpty) {
        errors[fieldKey] = fieldErrors;
      }
    }

    if (_passthrough) {
      final passthroughKeys = input.keys.toSet().difference(
        _fields.keys.toSet(),
      );
      for (final key in passthroughKeys) {
        final objValue = input[key];
        if (_passthroughType != null) {
          try {
            final passthroughErrors = <String, dynamic>{};
            parsed[key] = _passthroughType.tryParseInternal(
              objValue,
              errors: passthroughErrors,
            );
            if (passthroughErrors.isNotEmpty) {
              errors[key] = passthroughErrors;
            }
          } on TypeError catch (_) {
            errors[key] = {
              'error':
                  '$key expose a value of type ${objValue.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}',
            };
          }
        } else {
          parsed[key] = objValue as V;
        }
      }
    }

    _validateDependenciesTry(input, errors);
    return super.tryParseInternal(parsed, errors: errors);
  }

  @override
  Future<AcanthisParseResult<Map<String, V>>> parseAsync(
    Map<String, V> value,
  ) async {
    final parsed = <String, V>{};
    // Parse each field
    for (var entry in _fields.entries) {
      final fieldType = entry.value;
      final isOptional = _optionalFields.contains(entry.key);
      final isNullable = fieldType is AcanthisNullable;
      final passedValue = value[entry.key];
      if (passedValue == null && !isOptional && !isNullable) {
        final checks = fieldType.operations.whereType<AcanthisCheck>();
        final validationErrors = [
          'Field ${entry.key} is required',
          for (final check in checks) check.error,
        ];
        throw ValidationError(validationErrors.join('.\n'));
      }
      if (passedValue == null && isOptional && !isNullable) continue;
      if (fieldType is LazyEntry) {
        parsed[entry.key] = (await fieldType.parseAsync(
          passedValue,
          this,
        )).value;
      } else {
        parsed[entry.key] = (await fieldType.parseAsync(passedValue)).value;
      }
    }
    // Batch passthrough logic
    if (_passthrough) {
      final passthroughKeys = value.keys.toSet().difference(
        _fields.keys.toSet(),
      );
      for (final key in passthroughKeys) {
        final objValue = value[key];
        if (_passthroughType != null) {
          try {
            final parsedValue = await _passthroughType.parseAsync(objValue);
            parsed[key] = parsedValue.value;
          } on TypeError catch (_) {
            throw ValidationError(
              '$key expose a value of type ${objValue.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}',
            );
          }
        } else {
          parsed[key] = objValue as V;
        }
      }
    }
    // Memoized dependency validation
    if (_dependencies.isNotEmpty) {
      final queryCache = <String, dynamic>{};
      for (var dependency in _dependencies) {
        queryCache.putIfAbsent(
          dependency.dependendsOn,
          () => _keyQuery(dependency.dependendsOn, value),
        );
        queryCache.putIfAbsent(
          dependency.dependent,
          () => _keyQuery(dependency.dependent, value),
        );
        final dependFrom = queryCache[dependency.dependendsOn];
        final dependTo = queryCache[dependency.dependent];
        if (dependFrom != null && dependTo != null) {
          if (!dependency.dependency(dependFrom, dependTo)) {
            throw ValidationError(
              'Dependency not met: ${dependency.dependendsOn}->${dependency.dependent}',
            );
          }
        } else {
          throw ValidationError(
            'The dependency or dependFrom field does not exist in the map',
          );
        }
      }
    }
    return await super.parseAsync(parsed);
  }

  @override
  Future<AcanthisParseResult<Map<String, V>>> tryParseAsync(
    Map<String, V> value,
  ) async {
    final parsed = <String, V>{};
    final errors = <String, dynamic>{};
    for (final entry in _fields.entries) {
      final fieldType = entry.value;
      final isOptional = _optionalFields.contains(entry.key);
      final isNullable = fieldType is AcanthisNullable;
      final passedValue = value[entry.key];
      if (passedValue == null && !isOptional && !isNullable) {
        final checks = fieldType.operations.whereType<AcanthisCheck>();
        final validationErrors = {
          'required': 'Field ${entry.key} is required',
          for (final check in checks) check.name: check.error,
        };
        errors[entry.key] = validationErrors;
        continue;
      }
      if (passedValue == null && isOptional && !isNullable) continue;
      final AcanthisParseResult parsedValue;
      if (fieldType is LazyEntry) {
        parsedValue = await fieldType.tryParseAsync(passedValue, this);
      } else {
        parsedValue = await fieldType.tryParseAsync(passedValue);
      }
      parsed[entry.key] = parsedValue.value;
      if (parsedValue.errors.isNotEmpty) {
        errors[entry.key] = parsedValue.errors;
      }
    }
    // Batch passthrough logic
    if (_passthrough) {
      final passthroughKeys = value.keys.toSet().difference(
        _fields.keys.toSet(),
      );
      for (final key in passthroughKeys) {
        final objValue = value[key];
        if (_passthroughType != null) {
          try {
            final parsedValue = await _passthroughType.tryParseAsync(objValue);
            parsed[key] = parsedValue.value;
            errors[key] = parsedValue.errors;
          } on TypeError catch (_) {
            errors[key] = {
              'error':
                  '$key expose a value of type ${objValue.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}',
            };
          }
        } else {
          parsed[key] = objValue as V;
        }
      }
    }

    // Memoized dependency validation
    if (_dependencies.isNotEmpty) {
      final queryCache = <String, dynamic>{};
      for (var dependency in _dependencies) {
        queryCache.putIfAbsent(
          dependency.dependendsOn,
          () => _keyQuery(dependency.dependendsOn, value),
        );
        queryCache.putIfAbsent(
          dependency.dependent,
          () => _keyQuery(dependency.dependent, value),
        );
        final dependFrom = queryCache[dependency.dependendsOn];
        final dependTo = queryCache[dependency.dependent];
        if (dependFrom != null && dependTo != null) {
          if (!dependency.dependency(dependFrom, dependTo)) {
            errors[dependency.dependent] = {'dependency': 'Dependency not met'};
          }
        } else {
          errors[dependency.dependent] = {
            'dependency[${dependency.dependendsOn}->${dependency.dependent}]':
                'The dependency or dependFrom field does not exist in the map',
          };
        }
      }
    }
    final result = await super.tryParseAsync(parsed);
    if (result.errors.isNotEmpty) {
      errors.addAll(result.errors);
    }
    final success = errors.isEmpty;
    return AcanthisParseResult(
      value: success ? result.value : defaultValue ?? result.value,
      errors: errors,
      success: success,
      metadata: result.metadata,
    );
  }

  /// Override of [tryParse] from [AcanthisType]
  @override
  AcanthisParseResult<Map<String, V>> tryParse(Map<String, V> value) {
    if (isAsync) {
      throw AsyncValidationException(
        'Cannot use tryParse with async operations',
      );
    }
    return super.tryParse(value as dynamic);
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
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
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
      fields: {..._fields, ...newFields},
      passthrough: _passthrough,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  /// Merge field(s) to the map
  /// if a field already exists, it will be overwritten
  AcanthisMap<V> merge(Map<String, AcanthisType> fields) {
    return AcanthisMap<V>._(
      fields: {..._fields, ...fields},
      passthrough: _passthrough,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
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
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
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
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  /// Allow unknown keys in the map
  AcanthisMap<V> passthrough({AcanthisType? type}) {
    return AcanthisMap<V>._(
      fields: _fields,
      passthrough: true,
      passthroughType: type,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  /// Allow for null values in the map
  AcanthisMap<V?> partial({bool deep = false}) {
    if (deep) {
      return AcanthisMap<V?>(
        _fields.map((key, value) {
          if (value is AcanthisMap) {
            return MapEntry(key, value.partial(deep: deep));
          }
          if (value is LazyEntry) {
            return MapEntry(key, value.call(this).nullable());
          }
          return MapEntry(key, value.nullable());
        }),
      );
    }
    return AcanthisMap<V?>._(
      fields: _fields.map((key, value) => MapEntry(key, value.nullable())),
      passthrough: true,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  /// Add a check to the map to check if it has at least [length] elements
  AcanthisMap<V> maxProperties(
    int constraint, {
    String? message,
    String Function(int constraintValue)? messageBuilder,
  }) {
    return withCheck(
      MaxPropertiesCheck(
        constraintValue: constraint,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the map to check if it has at most [length] elements
  AcanthisMap<V> minProperties(
    int constraint, {
    String? message,
    String Function(int constraintValue)? messageBuilder,
  }) {
    return withCheck(
      MinPropertiesCheck(
        constraintValue: constraint,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  /// Add a check to the map to check if it has exactly [length] elements
  AcanthisMap<V> lengthProperties(
    int constraint, {
    String? message,
    String Function(int constraintValue)? messageBuilder,
  }) {
    return withCheck(
      LengthPropertiesCheck(
        constraintValue: constraint,
        message: message,
        messageBuilder: messageBuilder,
      ),
    );
  }

  @override
  AcanthisMap<V> withAsyncCheck(AcanthisAsyncCheck<Map<String, V>> check) {
    return AcanthisMap<V>._(
      fields: _fields,
      passthrough: _passthrough,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: [...operations, check],
      isAsync: true,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  @override
  AcanthisMap<V> withCheck(AcanthisCheck<Map<String, V>> check) {
    return AcanthisMap<V>._(
      fields: _fields,
      passthrough: _passthrough,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: [...operations, check],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
  }

  @override
  AcanthisMap<V> withTransformation(
    AcanthisTransformation<Map<String, V>> transformation,
  ) {
    return AcanthisMap<V>._(
      fields: _fields,
      passthrough: _passthrough,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: false,
      operations: [...operations, transformation],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
    );
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
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: objectKey,
      metadataEntry: metadata,
    );
  }

  @override
  Map<String, dynamic> toJsonSchema() {
    final schema = <String, dynamic>{};
    final lazyEntries = _fields.entries
        .where((entry) => entry.value is LazyEntry)
        .toList();
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
        defsMap[entryKey] = (entry.value as LazyEntry).toJsonSchema(
          parent: this,
          defs: true,
          defKey: entryKey,
        );
      }
    }
    for (final key in defsMap.keys) {
      lazyObjectMapper.remove(key);
    }
    final constraints = _getConstraints();
    return {
      if (defsMap.isNotEmpty) r'$defs': defsMap,
      'type': 'object',
      if (metadataEntry != null) ...metadataEntry!.toJson(),
      'properties': schema,
      'additionalProperties': _passthrough == false
          ? false
          : _passthroughType?.toJsonSchema() ?? true,
      'required': _fields.keys
          .where((key) => !_optionalFields.contains(key))
          .toList(),
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

  @override
  AcanthisType<Map<String, V>> withDefault(Map<String, V> value) {
    return AcanthisMap._(
      fields: _fields,
      passthrough: _passthrough,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: value,
    );
  }

  @override
  Map<String, dynamic> toOpenApiSchema() {
    final schema = <String, dynamic>{};
    final lazyEntries = _fields.entries
        .where((entry) => entry.value is LazyEntry)
        .toList();
    for (var entry in _fields.entries) {
      if (entry.value is LazyEntry) {
        final entryKey = '${entry.key}-lazy';
        schema[entry.key] = {r'$ref': '#/components/$entryKey'};
      } else {
        schema[entry.key] = entry.value.toOpenApiSchema();
      }
    }
    final defsMap = {};
    final lazyObjectMapper = LazyObjectMapper();
    for (var entry in lazyEntries) {
      final entryKey = '${entry.key}-lazy';
      final lazyEntry = lazyObjectMapper.get(entryKey);
      if (lazyEntry == false) {
        defsMap[entryKey] = (entry.value as LazyEntry).toOpenApiSchema(
          parent: this,
          defs: true,
          defKey: entryKey,
        );
      }
    }
    for (final key in defsMap.keys) {
      lazyObjectMapper.remove(key);
    }
    final constraints = _getConstraints();
    return {
      if (defsMap.isNotEmpty) 'refs': defsMap,
      'type': 'object',
      if (metadataEntry != null) ...metadataEntry!.toJson(),
      'properties': schema,
      'additionalProperties': _passthrough == false
          ? false
          : _passthroughType?.toOpenApiSchema() ?? true,
      'required': _fields.keys
          .where((key) => !_optionalFields.contains(key))
          .toList(),
      if (constraints.isNotEmpty) ...constraints,
    };
  }

  @override
  Map<String, V> mock([int? seed]) {
    final result = <String, V>{};
    for (var entry in _fields.entries) {
      if (entry.value is LazyEntry) {
        result[entry.key] = (entry.value as LazyEntry).call(this).mock(seed);
      } else {
        result[entry.key] = entry.value.mock(seed);
      }
    }
    if (_passthrough) {
      // Generate some random additional properties if passthrough is enabled
      for (int i = 0; i < 3; i++) {
        final randomKey = 'additional_${nanoid()}';
        if (_passthroughType != null) {
          result[randomKey] = _passthroughType.mock(seed);
        } else {
          // If no specific type is defined for passthrough, we can just assign a random value
          result[randomKey] = 'random_value_${nanoid()}' as V;
        }
      }
    }
    return result;
  }
}

/// Create a map of [fields]
AcanthisMap object(Map<String, AcanthisType> fields) =>
    AcanthisMap<dynamic>(fields);

@immutable
class _Dependency {
  final String dependent;
  final String dependendsOn;
  final bool Function(dynamic, dynamic) dependency;

  const _Dependency(this.dependent, this.dependendsOn, this.dependency);
}

class LazyEntry<O> extends AcanthisType<O> {
  final AcanthisType<O> Function(AcanthisMap parent) _type;

  LazyEntry(this._type, {super.operations, super.isAsync});

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
    return LazyEntry(_type, operations: [...operations, check], isAsync: true);
  }

  @override
  LazyEntry<O> withCheck(AcanthisCheck<O> check) {
    return LazyEntry(_type, operations: [...operations, check]);
  }

  @override
  LazyEntry<O> withTransformation(AcanthisTransformation<O> transformation) {
    return LazyEntry(_type, operations: [...operations, transformation]);
  }

  @override
  Map<String, dynamic> toJsonSchema({
    AcanthisMap<dynamic>? parent,
    bool defs = false,
    String defKey = '',
  }) {
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

  @override
  AcanthisType<O> withDefault(O value) {
    throw UnimplementedError('The implementation must be done from the parent');
  }

  @override
  Map<String, dynamic> toOpenApiSchema({
    AcanthisMap<dynamic>? parent,
    bool defs = false,
    String defKey = '',
  }) {
    final lazyObjectMapper = LazyObjectMapper();
    final type = _type(parent!);
    if (type is LazyEntry) {
      throw StateError('Circular dependency detected');
    }
    if (defs) {
      lazyObjectMapper.add(defKey);
    }
    final schema = type.toOpenApiSchema();
    return schema;
  }

  @override
  O mock([int? seed]) {
    throw UnimplementedError('The implementation must be done from the parent');
  }
}

LazyEntry<O> lazy<O>(
  AcanthisType<O> Function(AcanthisMap<dynamic> parent) type,
) => LazyEntry<O>(type);
