import 'package:acanthis/src/issue_sink.dart';

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

/// Handling of undeclared object keys.
enum AcanthisUnknownKeys { strip, preserve, reject }

/// A class to validate map types
class AcanthisMap<V> extends AcanthisType<Map<String, V>> {
  final Map<String, AcanthisType> _fields;

  /// The fields of the map
  Map<String, AcanthisType> get fields => UnmodifiableMapView(_fields);

  /// Whether the schema has rules involving more than one field.
  bool get hasCrossFieldDependencies => _dependencies.isNotEmpty;

  final bool _passthrough;
  final AcanthisType? _passthroughType;
  final List<_Dependency> _dependencies;
  final Set<String> _optionalFields;
  final bool _localPure;
  late final List<String> _keys;
  late final List<AcanthisType> _types;
  late final List<bool> _isOptional;
  final bool _patch;
  final bool _rejectUnknownKeys;

  bool get isPatch => _patch;
  bool isOptionalField(String key) => _patch || _optionalFields.contains(key);
  AcanthisUnknownKeys get unknownKeyPolicy => _rejectUnknownKeys
      ? AcanthisUnknownKeys.reject
      : _passthrough
      ? AcanthisUnknownKeys.preserve
      : AcanthisUnknownKeys.strip;
  AcanthisType? get additionalValueType => _passthroughType;
  late final int _length;
  late final bool _isPure;
  late final bool _canReuseInput =
      _localPure &&
      super.isPure &&
      defaultValue == null &&
      _types.every((type) => type.isPure && !type.hasDefault) &&
      (_passthroughType == null ||
          (_passthroughType.isPure && _passthroughType.defaultValue == null));

  // Compile lazily: fluent intermediate schemas are often never parsed.
  late final _ObjectTypePlan? _objectTypePlan = _compileObjectTypePlan();

  _ObjectTypePlan? _compileObjectTypePlan() {
    // Typed maps currently expose a lazy cast view in their pure path. Keep
    // that behavior, including when a cast error is observed, on that path.
    if (V != dynamic) return null;
    if (runtimeType != (AcanthisMap<dynamic>)) return null;
    final keys = <String>[];
    final kinds = <int>[];
    final parents = <int>[];
    final slots = <int>[];
    final mapLengths = <int>[_length];
    var mapCount = 1;

    bool append(AcanthisMap schema, int parent) {
      if (!schema.isPure ||
          schema.isAsync ||
          schema.operations.isNotEmpty ||
          schema._dependencies.isNotEmpty ||
          schema._optionalFields.isNotEmpty) {
        return false;
      }
      for (var i = 0; i < schema._length; i++) {
        final child = schema._types[i];
        if (!child.isPure ||
            child.isAsync ||
            child.hasDefault ||
            child.operations.isNotEmpty) {
          return false;
        }
        final type = child.runtimeType;
        final kind = type == AcanthisString
            ? 1
            : type == AcanthisBoolean
            ? 2
            : type == (AcanthisNumeric<int>)
            ? 3
            : type == (AcanthisNumeric<double>)
            ? 4
            : type == (AcanthisNumeric<num>)
            ? 5
            : type == (AcanthisMap<dynamic>)
            ? 0
            : -1;
        // Exact runtime types deliberately exclude user subclasses.
        if (kind == -1) return false;
        keys.add(schema._keys[i]);
        kinds.add(kind);
        parents.add(parent);
        if (kind == 0) {
          final slot = mapCount++;
          mapLengths.add((child as AcanthisMap)._length);
          slots.add(slot);
          if (!append(child, slot)) return false;
        } else {
          slots.add(0);
        }
      }
      return true;
    }

    if (!append(this, 0)) return null;
    return _ObjectTypePlan(keys, kinds, parents, slots, mapCount, mapLengths);
  }

  Map<String, V> _plannedOutput(Map<String, dynamic> input) {
    // All required keys have been checked. Equal lengths therefore mean no
    // unknown keys, and preserve the input's insertion order as before.
    if (input.length == _length) {
      return input as Map<String, V>;
    }
    // The existing stripping path emits keys in schema order.
    return {for (final key in _keys) key: input[key] as V};
  }

  Map<String, V> _reuseUnchangedInput(dynamic input, Map<String, V> output) {
    if (!_canReuseInput ||
        input is! Map<String, V> ||
        input.length != output.length) {
      return output;
    }
    for (final key in output.keys) {
      if (!input.containsKey(key) || !identical(input[key], output[key])) {
        return output;
      }
    }
    return input;
  }

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
       _patch = false,
       _rejectUnknownKeys = false,
       _dependencies = const [],
       _optionalFields = const {},
       _localPure = isPure,
       super(isAsync: _fields.values.any((field) => field.isAsync)) {
    _initializeCaches();
  }

  AcanthisMap._({
    required Map<String, AcanthisType<dynamic>> fields,
    required this._passthrough,
    required this._passthroughType,
    required this._dependencies,
    required this._optionalFields,
    this._patch = false,
    this._rejectUnknownKeys = false,
    bool isPure = true,
    bool isAsync = false,
    super.operations,
    super.key,
    super.metadataEntry,
    super.defaultValue,
  }) : _fields = fields,
       _localPure = isPure,
       super(isAsync: isAsync || fields.values.any((field) => field.isAsync)) {
    _initializeCaches();
  }

  void _initializeCaches() {
    _keys = _fields.keys.toList(growable: false);
    _types = _keys.map((key) => _fields[key]!).toList(growable: false);
    _isOptional = _keys
        .map((key) => _optionalFields.contains(key))
        .toList(growable: false);
    _length = _keys.length;
    _isPure =
        _types.every((type) => type.isPure && !type.hasDefault) &&
        !_passthrough &&
        !_rejectUnknownKeys &&
        defaultValue == null;
  }

  void _requiredIssues(
    Map<String, dynamic> errors,
    String field,
    AcanthisType type,
  ) {
    errors.addIssue('required', 'Field $field is required', path: [field]);
    // Preserve the existing collection policy for absent fields, including
    // repeated checks, without running predicates against missing input.
    for (final check in type.operations.whereType<AcanthisCheck>()) {
      errors.addIssue(
        check.code,
        check.error,
        path: [field],
        parameters: check.parameters,
      );
    }
  }

  void _throwRequiredFieldError(String fieldKey, AcanthisType fieldType) {
    final checks = fieldType.operations.whereType<AcanthisCheck>();
    final validationErrors = [
      'Field $fieldKey is required',
      for (final check in checks) check.error,
    ];
    throw ValidationError('${validationErrors.join('.\n')}.');
  }

  void _validateDependenciesThrow(Map<String, dynamic> value) {
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
    Map<String, dynamic> value,
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
          errors.addIssue(
            'dependency',
            'Dependency not met',
            path: [dependency.dependent],
            parameters: {'dependsOn': dependency.dependendsOn},
          );
        }
      } else {
        errors.addIssue(
          'dependency',
          'The dependency or dependFrom field does not exist in the map',
          path: [dependency.dependent],
          parameters: {'dependsOn': dependency.dependendsOn},
        );
      }
    }
  }

  dynamic _keyQuery(String key, Map<String, dynamic> value) {
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
      patch: _patch,
      rejectUnknownKeys: _rejectUnknownKeys,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: {..._optionalFields, ...fields},
      operations: operations,
      isAsync: isAsync,
      key: key,
      defaultValue: defaultValue,
    );
  }

  @override
  Map<String, V> parseInternal(dynamic value) {
    value ??= defaultValue;
    final plan = _objectTypePlan;
    if (plan != null && value is Map<String, dynamic> && plan.accepts(value)) {
      return _plannedOutput(value);
    }
    _checkUnknownKeys(value);
    final input = isPure && value is Map<String, V>
        ? value
        : Map<String, dynamic>.from(value as Map);
    if (isPure) {
      Map<String, dynamic>? changed;
      for (int i = 0; i < _length; i++) {
        final fieldKey = _keys[i];
        final fieldType = _types[i];
        dynamic passedValue = input.containsKey(fieldKey)
            ? input[fieldKey]
            : _missing;
        if (identical(passedValue, _missing) && _patch) continue;
        if (identical(passedValue, _missing) && fieldType.hasDefault) {
          passedValue = null;
        }
        if (identical(passedValue, _missing) && !_isOptional[i]) {
          _throwRequiredFieldError(fieldKey, fieldType);
        }
        if (identical(passedValue, _missing) && _isOptional[i]) {
          continue;
        }
        final parsedValue =
            (fieldType is LazyEntry ? fieldType.call(this) : fieldType)
                .parseInternal(
                  identical(passedValue, _missing) ? null : passedValue,
                );
        if (identical(passedValue, _missing) ||
            !identical(parsedValue, passedValue)) {
          (changed ??= Map<String, dynamic>.of(input))[fieldKey] = parsedValue;
        }
      }
      _validateDependenciesThrow(input);
      final output = changed ?? input;
      if (output.keys.any((fieldKey) => !_fields.containsKey(fieldKey))) {
        final stripped = <String, V>{};
        for (final fieldKey in _keys) {
          if (output.containsKey(fieldKey)) {
            stripped[fieldKey] = output[fieldKey] as V;
          }
        }
        return super.parseInternal(stripped);
      }
      return super.parseInternal(
        output is Map<String, V> ? output : output.cast<String, V>(),
      );
    }

    final parsed = <String, V>{};
    for (int i = 0; i < _length; i++) {
      final fieldKey = _keys[i];
      final fieldType = _types[i];
      dynamic passedValue = input.containsKey(fieldKey)
          ? input[fieldKey]
          : _missing;
      if (identical(passedValue, _missing) && _patch) continue;
      if (identical(passedValue, _missing) && fieldType.hasDefault) {
        passedValue = null;
      }
      if (identical(passedValue, _missing) && !_isOptional[i]) {
        _throwRequiredFieldError(fieldKey, fieldType);
      }
      if (identical(passedValue, _missing) && _isOptional[i]) {
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
    return super.parseInternal(_reuseUnchangedInput(value, parsed));
  }

  @override
  Map<String, V> valueOnFailure(dynamic value) => defaultValue ?? <String, V>{};

  Map<String, dynamic>? _tryInput(
    dynamic value,
    Map<String, dynamic> errors, {
    bool snapshot = false,
  }) {
    try {
      return !snapshot && isPure && value is Map<String, V>
          ? value
          : Map<String, dynamic>.from(value as Map);
    } on TypeError {
      errors.addIssue(
        inputErrorKey,
        'Invalid type: ${value.runtimeType}, expected Map with String keys',
      );
      return null;
    }
  }

  @override
  Map<String, V> tryParseInternal(
    dynamic value, {
    required Map<String, dynamic> errors,
  }) {
    value ??= defaultValue;
    final plan = _objectTypePlan;
    if (plan != null && value is Map<String, dynamic> && plan.accepts(value)) {
      return _plannedOutput(value);
    }
    _checkUnknownKeys(value, errors);
    final input = _tryInput(value, errors);
    if (input == null) return valueOnFailure(value);
    if (isPure) {
      Map<String, dynamic>? changed;
      final fieldErrors = IssueSink();
      for (int i = 0; i < _length; i++) {
        final fieldKey = _keys[i];
        final fieldType = _types[i];
        dynamic passedValue = input.containsKey(fieldKey)
            ? input[fieldKey]
            : _missing;
        if (identical(passedValue, _missing) && _patch) continue;
        if (identical(passedValue, _missing) && fieldType.hasDefault) {
          passedValue = null;
        }
        if (identical(passedValue, _missing) && !_isOptional[i]) {
          _requiredIssues(errors, fieldKey, fieldType);
          continue;
        }
        if (identical(passedValue, _missing) && _isOptional[i]) {
          continue;
        }
        final valueToParse = identical(passedValue, _missing)
            ? null
            : passedValue;
        final parsedValue =
            (fieldType is LazyEntry ? fieldType.call(this) : fieldType)
                .tryParseInternal(valueToParse, errors: fieldErrors);
        if (identical(passedValue, _missing) ||
            !identical(parsedValue, passedValue)) {
          (changed ??= Map<String, dynamic>.of(input))[fieldKey] = parsedValue;
        }
        if (fieldErrors.isNotEmpty) {
          errors.addChild(fieldKey, fieldErrors);
          fieldErrors.clear();
        }
      }
      _validateDependenciesTry(input, errors);
      final output = changed ?? input;
      if (output.keys.any((fieldKey) => !_fields.containsKey(fieldKey))) {
        final stripped = <String, V>{};
        for (final fieldKey in _keys) {
          if (output.containsKey(fieldKey)) {
            stripped[fieldKey] = output[fieldKey] as V;
          }
        }
        return super.tryParseInternal(stripped, errors: errors);
      }
      return super.tryParseInternal(
        output is Map<String, V> ? output : output.cast<String, V>(),
        errors: errors,
      );
    }

    final parsed = <String, V>{};
    final fieldErrors = IssueSink();
    for (int i = 0; i < _length; i++) {
      final fieldKey = _keys[i];
      final fieldType = _types[i];
      dynamic passedValue = input.containsKey(fieldKey)
          ? input[fieldKey]
          : _missing;
      if (identical(passedValue, _missing) && _patch) continue;
      if (identical(passedValue, _missing) && fieldType.hasDefault) {
        passedValue = null;
      }
      if (identical(passedValue, _missing) && !_isOptional[i]) {
        _requiredIssues(errors, fieldKey, fieldType);
        continue;
      }
      if (identical(passedValue, _missing) && _isOptional[i]) {
        continue;
      }
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
        errors.addChild(fieldKey, fieldErrors);
        fieldErrors.clear();
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
            final passthroughErrors = IssueSink();
            parsed[key] = _passthroughType.tryParseInternal(
              objValue,
              errors: passthroughErrors,
            );
            if (passthroughErrors.isNotEmpty) {
              errors.addChild(key, passthroughErrors);
            }
          } on TypeError catch (_) {
            errors.addIssue(
              'type',
              '$key expose a value of type ${objValue.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}',
              path: [key],
            );
          }
        } else {
          parsed[key] = objValue as V;
        }
      }
    }

    _validateDependenciesTry(input, errors);
    return super.tryParseInternal(
      _reuseUnchangedInput(value, parsed),
      errors: errors,
    );
  }

  @override
  Future<AcanthisParseResult<Map<String, V>>> parseAsync(dynamic value) async {
    value ??= defaultValue;
    if (!isAsync) return parse(value);
    _checkUnknownKeys(value);
    final input = Map<String, dynamic>.from(value as Map);
    final parsed = <String, V>{};
    // Parse each field
    for (var entry in _fields.entries) {
      final fieldType = entry.value;
      final isOptional = _optionalFields.contains(entry.key);
      if (_patch && !input.containsKey(entry.key)) continue;
      final hasValue = input.containsKey(entry.key) || fieldType.hasDefault;
      final passedValue = input[entry.key];
      if (!hasValue && !isOptional) {
        final checks = fieldType.operations.whereType<AcanthisCheck>();
        final validationErrors = [
          'Field ${entry.key} is required',
          for (final check in checks) check.error,
        ];
        throw ValidationError(validationErrors.join('.\n'));
      }
      if (!hasValue && isOptional) continue;
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
      final passthroughKeys = input.keys.toSet().difference(
        _fields.keys.toSet(),
      );
      for (final key in passthroughKeys) {
        final objValue = input[key];
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
          () => _keyQuery(dependency.dependendsOn, input),
        );
        queryCache.putIfAbsent(
          dependency.dependent,
          () => _keyQuery(dependency.dependent, input),
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
    final result = await super.parseAsync(parsed);
    return AcanthisParseResult(
      value: _reuseUnchangedInput(value, result.value),
      metadata: result.metadata,
    );
  }

  @override
  Future<AcanthisParseResult<Map<String, V>>> tryParseAsync(
    dynamic value,
  ) async {
    value ??= defaultValue;
    if (!isAsync) return tryParse(value);
    final errors = IssueSink();
    _checkUnknownKeys(value, errors);
    final input = _tryInput(value, errors, snapshot: true);
    if (input == null) {
      return AcanthisParseResult(
        value: valueOnFailure(value),
        errors: errors,
        success: false,
        metadata: metadataEntry,
      );
    }
    final parsed = <String, V>{};
    for (final entry in _fields.entries) {
      final fieldType = entry.value;
      final isOptional = _optionalFields.contains(entry.key);
      if (_patch && !input.containsKey(entry.key)) continue;
      final hasValue = input.containsKey(entry.key) || fieldType.hasDefault;
      final passedValue = input[entry.key];
      if (!hasValue && !isOptional) {
        _requiredIssues(errors, entry.key, fieldType);
        continue;
      }
      if (!hasValue && isOptional) continue;
      final AcanthisParseResult parsedValue;
      if (fieldType is LazyEntry) {
        parsedValue = await fieldType.tryParseAsync(passedValue, this);
      } else {
        parsedValue = await fieldType.tryParseAsync(passedValue);
      }
      parsed[entry.key] = parsedValue.value;
      if (parsedValue.errors.isNotEmpty) {
        errors.addChild(entry.key, parsedValue.errors);
      }
    }
    // Batch passthrough logic
    if (_passthrough) {
      final passthroughKeys = input.keys.toSet().difference(
        _fields.keys.toSet(),
      );
      for (final key in passthroughKeys) {
        final objValue = input[key];
        if (_passthroughType != null) {
          try {
            final parsedValue = await _passthroughType.tryParseAsync(objValue);
            parsed[key] = parsedValue.value;
            if (parsedValue.errors.isNotEmpty) {
              errors.addChild(key, parsedValue.errors);
            }
          } on TypeError catch (_) {
            errors.addIssue(
              'type',
              '$key expose a value of type ${objValue.runtimeType}, but the passthrough type is ${_passthroughType.runtimeType}',
              path: [key],
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
          () => _keyQuery(dependency.dependendsOn, input),
        );
        queryCache.putIfAbsent(
          dependency.dependent,
          () => _keyQuery(dependency.dependent, input),
        );
        final dependFrom = queryCache[dependency.dependendsOn];
        final dependTo = queryCache[dependency.dependent];
        if (dependFrom != null && dependTo != null) {
          if (!dependency.dependency(dependFrom, dependTo)) {
            errors.addIssue(
              'dependency',
              'Dependency not met',
              path: [dependency.dependent],
              parameters: {'dependsOn': dependency.dependendsOn},
            );
          }
        } else {
          errors.addIssue(
            'dependency',
            'The dependency or dependFrom field does not exist in the map',
            path: [dependency.dependent],
            parameters: {'dependsOn': dependency.dependendsOn},
          );
        }
      }
    }
    final result = await super.tryParseAsyncOperations(parsed);
    if (result.errors.isNotEmpty) {
      errors.addAll(result.errors);
    }
    final success = errors.isEmpty;
    return AcanthisParseResult(
      value: success
          ? _reuseUnchangedInput(value, result.value)
          : defaultValue ?? _reuseUnchangedInput(value, result.value),
      errors: errors,
      success: success,
      metadata: result.metadata,
    );
  }

  /// Override of [tryParse] from [AcanthisType]
  @override
  AcanthisParseResult<Map<String, V>> tryParse(dynamic value) {
    value ??= defaultValue;
    if (isAsync) {
      throw AsyncValidationException(
        'Cannot use tryParse with async operations',
      );
    }
    if (value is! Map) {
      return AcanthisParseResult(
        value: valueOnFailure(value),
        errors: IssueSink.single(
          inputErrorKey,
          'Invalid type: ${value.runtimeType}, expected Map with String keys',
        ),
        success: false,
        metadata: metadataEntry,
      );
    }
    return super.tryParse(value);
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
      patch: _patch,
      rejectUnknownKeys: _rejectUnknownKeys,
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
      defaultValue: defaultValue,
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
      patch: _patch,
      rejectUnknownKeys: _rejectUnknownKeys,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  /// Merge field(s) to the map
  /// if a field already exists, it will be overwritten
  AcanthisMap<V> merge(Map<String, AcanthisType> fields) {
    return AcanthisMap<V>._(
      fields: {..._fields, ...fields},
      passthrough: _passthrough,
      patch: _patch,
      rejectUnknownKeys: _rejectUnknownKeys,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
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
      patch: _patch,
      rejectUnknownKeys: _rejectUnknownKeys,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
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
      patch: _patch,
      rejectUnknownKeys: _rejectUnknownKeys,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  /// Allow unknown keys in the map
  AcanthisMap<V> passthrough({AcanthisType? type}) {
    return AcanthisMap<V>._(
      fields: _fields,
      passthrough: true,
      patch: _patch,
      rejectUnknownKeys: false,
      passthroughType: type,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  /// Makes fields optional while preserving their value and unknown-key policies.
  /// Missing fields stay missing, including fields with defaults.
  AcanthisMap<V> partial({bool deep = false}) {
    return AcanthisMap<V>._(
      fields: _fields.map(
        (key, value) => MapEntry(
          key,
          deep && value is AcanthisMap ? value.partial(deep: true) : value,
        ),
      ),
      passthrough: _passthrough,
      passthroughType: _passthroughType,
      patch: true,
      rejectUnknownKeys: _rejectUnknownKeys,
      dependencies: _dependencies,
      optionalFields: _fields.keys.toSet(),
      isPure: _localPure,
      operations: operations,
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  /// Creates an omission-preserving PATCH schema.
  AcanthisMap<V> patch({bool deep = false}) => partial(deep: deep);

  /// Selects how undeclared keys are handled.
  AcanthisMap<V> unknownKeys(AcanthisUnknownKeys policy) => AcanthisMap<V>._(
    fields: _fields,
    passthrough: policy == AcanthisUnknownKeys.preserve,
    passthroughType: policy == AcanthisUnknownKeys.preserve
        ? _passthroughType
        : null,
    patch: _patch,
    rejectUnknownKeys: policy == AcanthisUnknownKeys.reject,
    dependencies: _dependencies,
    optionalFields: _optionalFields,
    isPure: _localPure,
    operations: operations,
    isAsync: isAsync,
    key: key,
    metadataEntry: metadataEntry,
    defaultValue: defaultValue,
  );

  void _checkUnknownKeys(dynamic value, [Map<String, dynamic>? errors]) {
    if (!_rejectUnknownKeys || value is! Map) return;
    for (final key in value.keys) {
      if (key is String && !_fields.containsKey(key)) {
        if (errors == null) {
          throw ValidationError('Unknown field $key', key: 'unknownKey');
        }
        errors.addIssue('unknownKey', 'Unknown field $key', path: [key]);
      }
    }
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
      patch: _patch,
      rejectUnknownKeys: _rejectUnknownKeys,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: [...operations, check],
      isAsync: true,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisMap<V> withCheck(AcanthisCheck<Map<String, V>> check) {
    return AcanthisMap<V>._(
      fields: _fields,
      passthrough: _passthrough,
      patch: _patch,
      rejectUnknownKeys: _rejectUnknownKeys,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: [...operations, check],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
    );
  }

  @override
  AcanthisMap<V> withTransformation(
    AcanthisTransformation<Map<String, V>> transformation,
  ) {
    return AcanthisMap<V>._(
      fields: _fields,
      passthrough: _passthrough,
      patch: _patch,
      rejectUnknownKeys: _rejectUnknownKeys,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: false,
      operations: [...operations, transformation],
      isAsync: isAsync,
      key: key,
      metadataEntry: metadataEntry,
      defaultValue: defaultValue,
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
      patch: _patch,
      rejectUnknownKeys: _rejectUnknownKeys,
      passthroughType: _passthroughType,
      dependencies: _dependencies,
      optionalFields: _optionalFields,
      isPure: isPure,
      operations: operations,
      isAsync: isAsync,
      key: objectKey,
      metadataEntry: metadata,
      defaultValue: defaultValue,
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
      patch: _patch,
      rejectUnknownKeys: _rejectUnknownKeys,
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

// A whole-object type-check program. All state used while executing the
// program is local to the call; the cached plan contains only schema data.
class _ObjectTypePlan {
  final List<String> keys;
  final List<int> kinds;
  final List<int> parents;
  final List<int> slots;
  final int mapCount;
  final List<int> mapLengths;

  _ObjectTypePlan(
    this.keys,
    this.kinds,
    this.parents,
    this.slots,
    this.mapCount,
    this.mapLengths,
  );

  bool accepts(Map<String, dynamic> input) {
    if (mapCount == 1) {
      for (var i = 0; i < keys.length; i++) {
        if (!_acceptsLeaf(kinds[i], input[keys[i]])) return false;
      }
      return true;
    }
    final maps = List<Map<String, dynamic>?>.filled(mapCount, null);
    maps[0] = input;
    for (var i = 0; i < keys.length; i++) {
      final value = maps[parents[i]]![keys[i]];
      if (kinds[i] == 0) {
        if (value is! Map<String, dynamic>) return false;
        if (value.length != mapLengths[slots[i]]) return false;
        maps[slots[i]] = value;
      } else if (!_acceptsLeaf(kinds[i], value)) {
        return false;
      }
    }
    return true;
  }

  static bool _acceptsLeaf(int kind, dynamic value) => switch (kind) {
    1 => value is String,
    2 => value is bool,
    3 => value is int,
    4 => value is double,
    5 => value is num,
    _ => false,
  };
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
  AcanthisNullable<O> nullable({O? defaultValue}) {
    throw UnimplementedError('The implementation must be done from the parent');
  }

  @override
  AcanthisParseResult<O> parse(dynamic value, [AcanthisMap? parent]) {
    final type = _type(parent!);
    if (value is List) {
      value = List<Map<String, dynamic>>.from(value) as O;
    }
    return type.parse(value);
  }

  @override
  AcanthisParseResult<O> tryParse(dynamic value, [AcanthisMap? parent]) {
    final type = _type(parent!);
    if (value is List) {
      value = List<Map<String, dynamic>>.from(value) as O;
    }
    return type.tryParse(value);
  }

  @override
  Future<AcanthisParseResult<O>> parseAsync(
    dynamic value, [
    AcanthisMap? parent,
  ]) {
    final type = _type(parent!);
    if (value is List) {
      value = List<Map<String, dynamic>>.from(value) as O;
    }
    return type.parseAsync(value);
  }

  @override
  Future<AcanthisParseResult<O>> tryParseAsync(
    dynamic value, [
    AcanthisMap? parent,
  ]) {
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
